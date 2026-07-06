import io
import os

from django.http import FileResponse
from reportlab.lib.pagesizes import A4
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas as rl_canvas
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from personnel.permissions import EstPersonnelCabinet
from .models import CompteRendu
from .serializers import CompteRenduSerializer

# ── Palette PDF (cohérente avec prescriptions) ───────────────────────────────
_NAVY  = (0.102, 0.176, 0.42)
_BLEU  = (0.118, 0.302, 0.718)
_GRIS  = (0.28,  0.33,  0.41)
_BLANC = (1, 1, 1)
_LEGER = (0.937, 0.953, 1.0)


def _ia_generer(contexte: dict) -> str:
    """
    Génère un compte-rendu structuré via Claude claude-sonnet-4-6.
    Si ANTHROPIC_API_KEY est absent, renvoie un modèle vide prérempli.
    """
    api_key = os.environ.get("ANTHROPIC_API_KEY", "").strip()
    if not api_key:
        return _template_fallback(contexte)

    try:
        import anthropic
        client = anthropic.Anthropic(api_key=api_key)

        type_labels = {
            "consultation":     "Consultation dentaire",
            "rendez_vous":      "Rendez-vous",
            "operation":        "Opération chirurgicale",
            "schema_dentaire":  "Mise à jour du schéma dentaire",
            "autre":            "Acte médical",
        }
        type_label = type_labels.get(contexte.get("type_action", "autre"), "Acte médical")
        patient = f"{contexte.get('patient_prenom', '')} {contexte.get('patient_nom', '')}".strip()

        lignes_contexte = [f"- Type d'action : {type_label}"]
        if patient:
            lignes_contexte.append(f"- Patient : {patient}")
        if contexte.get("praticien_nom"):
            lignes_contexte.append(f"- Praticien : {contexte['praticien_nom']}")
        if contexte.get("date"):
            lignes_contexte.append(f"- Date : {contexte['date']}")
        if contexte.get("motif"):
            lignes_contexte.append(f"- Motif : {contexte['motif']}")
        if contexte.get("observations"):
            lignes_contexte.append(f"- Observations cliniques : {contexte['observations']}")
        if contexte.get("diagnostic"):
            lignes_contexte.append(f"- Diagnostic : {contexte['diagnostic']}")
        if contexte.get("actes"):
            lignes_contexte.append(f"- Actes réalisés : {', '.join(contexte['actes'])}")
        if contexte.get("notes"):
            lignes_contexte.append(f"- Notes du praticien : {contexte['notes']}")

        prompt = (
            "Tu es l'assistant médical de Wam's Cabinet Dentaire. "
            "Génère un compte-rendu clinique professionnel, concis et structuré en français "
            "à partir des informations suivantes :\n\n"
            + "\n".join(lignes_contexte)
            + "\n\nFormat attendu :\n"
            "**COMPTE-RENDU CLINIQUE**\n\n"
            "**Contexte**\n[description courte]\n\n"
            "**Constatations / Observations**\n[détail]\n\n"
            "**Actes réalisés**\n[liste]\n\n"
            "**Diagnostic / Conclusion**\n[conclusion]\n\n"
            "**Recommandations / Suite**\n[prochaines étapes]\n\n"
            "Sois précis, professionnel et utilise le vocabulaire médical dentaire adapté."
        )

        message = client.messages.create(
            model=os.environ.get("ANTHROPIC_MODEL", "claude-sonnet-4-6"),
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}],
        )
        return message.content[0].text.strip()

    except Exception:
        return _template_fallback(contexte)


def _template_fallback(ctx: dict) -> str:
    patient = f"{ctx.get('patient_prenom', '')} {ctx.get('patient_nom', '')}".strip() or "—"
    date    = ctx.get("date", "—")
    motif   = ctx.get("motif", "—")
    obs     = ctx.get("observations", "—")
    diag    = ctx.get("diagnostic", "—")
    actes   = ", ".join(ctx.get("actes", [])) or "—"
    notes   = ctx.get("notes", "—")

    return (
        f"**COMPTE-RENDU CLINIQUE**\n\n"
        f"**Contexte**\n"
        f"Patient : {patient} — Date : {date} — Motif : {motif}\n\n"
        f"**Constatations / Observations**\n{obs}\n\n"
        f"**Actes réalisés**\n{actes}\n\n"
        f"**Diagnostic / Conclusion**\n{diag}\n\n"
        f"**Recommandations / Suite**\n{notes}\n\n"
        f"_(Compte-rendu généré automatiquement — veuillez compléter si nécessaire)_"
    )


def _generer_pdf_cr(cr: CompteRendu) -> io.BytesIO:
    buffer = io.BytesIO()
    c = rl_canvas.Canvas(buffer, pagesize=A4)
    width, height = A4
    MARGE = 50

    def fc(rgb): c.setFillColorRGB(*rgb)
    def sc(rgb): c.setStrokeColorRGB(*rgb)

    # ── En-tête ───────────────────────────────────────────────────────────────
    sc(_NAVY); fc(_NAVY)
    c.rect(0, height - 90, width, 90, fill=1, stroke=0)
    fc(_BLANC)
    c.setFont("Helvetica-Bold", 20)
    c.drawString(MARGE, height - 40, "Wam's — Cabinet Dentaire")
    c.setFont("Helvetica", 10)
    c.drawString(MARGE, height - 60, "Compte-rendu clinique")
    c.setFont("Helvetica-Oblique", 9)
    c.drawRightString(width - MARGE, height - 40, f"N° {cr.id:05d}")
    c.drawRightString(width - MARGE, height - 60, f"Date : {cr.cree_le:%d/%m/%Y}")

    y = height - 110

    # ── Bande infos ───────────────────────────────────────────────────────────
    fc(_LEGER); sc(_LEGER)
    c.rect(MARGE - 8, y - 48, width - 2 * MARGE + 16, 58, fill=1, stroke=0)

    fc(_NAVY); c.setFont("Helvetica-Bold", 10)
    c.drawString(MARGE, y, "PATIENT")
    fc((0, 0, 0)); c.setFont("Helvetica", 11)
    c.drawString(MARGE, y - 16, f"{cr.patient.prenom} {cr.patient.nom}")
    if cr.patient.telephone:
        fc(_GRIS); c.setFont("Helvetica", 9)
        c.drawString(MARGE, y - 30, f"Tél : {cr.patient.telephone}")

    if cr.praticien:
        fc(_NAVY); c.setFont("Helvetica-Bold", 10)
        c.drawRightString(width - MARGE, y, "PRATICIEN")
        fc((0, 0, 0)); c.setFont("Helvetica", 11)
        c.drawRightString(width - MARGE, y - 16,
                          f"Dr. {cr.praticien.first_name} {cr.praticien.last_name}")
        if getattr(cr.praticien, "specialite", ""):
            fc(_GRIS); c.setFont("Helvetica", 9)
            c.drawRightString(width - MARGE, y - 30, cr.praticien.specialite)

    y -= 66

    # ── Titre ─────────────────────────────────────────────────────────────────
    fc(_BLEU); c.setFont("Helvetica-Bold", 12)
    c.drawString(MARGE, y, cr.titre.upper())
    y -= 14

    fc(_GRIS); c.setFont("Times-Roman", 9)
    ia_tag = "  ·  Généré par IA" if cr.genere_par_ia else ""
    c.drawString(MARGE, y, f"Type : {cr.get_type_action_display()}{ia_tag}")
    y -= 6

    sc(_BLEU); c.setLineWidth(1.2)
    c.line(MARGE, y, width - MARGE, y)
    y -= 18

    # ── Contenu ───────────────────────────────────────────────────────────────
    fc((0.1, 0.1, 0.15)); c.setFont("Times-Roman", 10)
    for ligne in cr.contenu.splitlines():
        if y < 80:
            c.showPage(); y = height - 60; c.setFont("Times-Roman", 10)

        # Titres en gras si ligne commence par ** (markdown simplifié)
        if ligne.startswith("**") and ligne.endswith("**"):
            fc(_NAVY); c.setFont("Helvetica-Bold", 11)
            c.drawString(MARGE, y, ligne.replace("**", "").strip())
            fc((0.1, 0.1, 0.15)); c.setFont("Times-Roman", 10)
            y -= 17
        elif ligne.startswith("- ") or ligne.startswith("* "):
            texte = ligne[2:].replace("**", "").replace("  ", " ").strip()
            if texte:
                c.drawString(MARGE + 10, y, f"•  {texte[:112]}")
            y -= 14
        else:
            texte = ligne.replace("**", "").replace("  ", " ").strip()
            if texte:
                c.drawString(MARGE, y, texte[:115])
            y -= 14

    # ── Pied ──────────────────────────────────────────────────────────────────
    fc(_GRIS); c.setFont("Helvetica-Oblique", 8)
    c.drawString(MARGE, 30, f"Wam's — Compte-rendu N° {cr.id:05d}  ·  {cr.cree_le:%d/%m/%Y %H:%M}")

    c.showPage()
    c.save()
    buffer.seek(0)
    return buffer


class CompteRenduViewSet(viewsets.ModelViewSet):
    queryset           = CompteRendu.objects.select_related("patient", "praticien")
    serializer_class   = CompteRenduSerializer
    permission_classes = [IsAuthenticated, EstPersonnelCabinet]

    def get_queryset(self):
        qs = super().get_queryset()
        patient_id = self.request.query_params.get("patient")
        if patient_id:
            qs = qs.filter(patient_id=patient_id)
        type_action = self.request.query_params.get("type_action")
        if type_action:
            qs = qs.filter(type_action=type_action)
        return qs

    def perform_create(self, serializer):
        serializer.save(praticien=self.request.user)

    @action(detail=False, methods=["post"], url_path="generer")
    def generer(self, request):
        """
        Reçoit le contexte clinique et renvoie un compte-rendu généré par IA.
        Ne sauvegarde rien — le frontend choisit s'il enregistre ou non.
        """
        contexte = request.data
        texte = _ia_generer(contexte)
        return Response({"contenu": texte, "genere_par_ia": True})

    @action(detail=True, methods=["get"])
    def pdf(self, request, pk=None):
        """Génère le PDF du compte-rendu et le renvoie en FileResponse."""
        cr     = self.get_object()
        buffer = _generer_pdf_cr(cr)
        return FileResponse(buffer, as_attachment=False,
                            filename=f"compte_rendu_{cr.id}.pdf")


#EbaJioloLewis
