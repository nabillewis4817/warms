import base64
import io

from django.http import FileResponse
from reportlab.lib.pagesizes import A4
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from patients.models import Patient
from personnel.permissions import EstChirurgienDentiste, EstPersonnelCabinet, EstPatient
from personnel.models import Utilisateur
from .models import LignePrescription, Prescription
from .serializers import (
    LignePrescriptionSerializer,
    PrescriptionCreateSerializer,
    PrescriptionSerializer,
)

# ── Palette PDF ──────────────────────────────────────────────────────────────
_NAVY  = (0.102, 0.176, 0.42)
_BLEU  = (0.118, 0.302, 0.718)
_GRIS  = (0.28, 0.33, 0.41)
_BLANC = (1, 1, 1)
_LEGER = (0.937, 0.953, 1.0)


def _generer_pdf(prescription, sig_img=None) -> io.BytesIO:
    """Génère l'ordonnance PDF et renvoie le buffer.

    sig_img : ImageReader optionnel — signature dessinée à la volée.  Si None
    et que le praticien a une signature_image enregistrée, cette dernière est
    utilisée à la place.
    """
    buffer = io.BytesIO()
    c = canvas.Canvas(buffer, pagesize=A4)
    width, height = A4
    MARGE = 50

    def fc(rgb): c.setFillColorRGB(*rgb)
    def sc(rgb): c.setStrokeColorRGB(*rgb)

    # ── En-tête ──────────────────────────────────────────────────────────────
    sc(_NAVY); fc(_NAVY)
    c.rect(0, height - 90, width, 90, fill=1, stroke=0)

    fc(_BLANC)
    c.setFont("Helvetica-Bold", 22)
    c.drawString(MARGE, height - 42, "Wam's — Cabinet Dentaire")
    c.setFont("Helvetica", 10)
    c.drawString(MARGE, height - 62, "Ordonnance médicale")
    c.setFont("Helvetica-Oblique", 9)
    c.drawRightString(width - MARGE, height - 42, f"N° {prescription.id:05d}")
    c.drawRightString(width - MARGE, height - 62, f"Date : {prescription.cree_le:%d/%m/%Y}")

    y = height - 110

    # ── Infos patient + praticien ────────────────────────────────────────────
    patient   = prescription.patient
    praticien = prescription.praticien

    fc(_LEGER); sc(_LEGER)
    c.rect(MARGE - 8, y - 56, width - 2 * MARGE + 16, 66, fill=1, stroke=0)

    fc(_NAVY); c.setFont("Helvetica-Bold", 10)
    c.drawString(MARGE, y, "PATIENT")
    fc((0, 0, 0)); c.setFont("Helvetica", 11)
    c.drawString(MARGE, y - 16, f"{patient.prenom} {patient.nom}")
    if getattr(patient, "date_naissance", None):
        c.setFont("Helvetica", 9); fc(_GRIS)
        c.drawString(MARGE, y - 30, f"Né(e) le : {patient.date_naissance:%d/%m/%Y}")
    if patient.telephone:
        c.drawString(MARGE, y - 42, f"Tél : {patient.telephone}")

    if praticien:
        fc(_NAVY); c.setFont("Helvetica-Bold", 10)
        c.drawRightString(width - MARGE, y, "PRESCRIPTEUR")
        fc((0, 0, 0)); c.setFont("Helvetica", 11)
        c.drawRightString(width - MARGE, y - 16, f"Dr. {praticien.first_name} {praticien.last_name}")
        if getattr(praticien, "specialite", ""):
            c.setFont("Helvetica", 9); fc(_GRIS)
            c.drawRightString(width - MARGE, y - 30, praticien.specialite)
        if praticien.telephone:
            c.drawRightString(width - MARGE, y - 42, f"Tél : {praticien.telephone}")

    y -= 72

    # ── Titre ────────────────────────────────────────────────────────────────
    if prescription.titre:
        fc(_BLEU); c.setFont("Helvetica-Bold", 12)
        c.drawString(MARGE, y, prescription.titre.upper())
        y -= 20

    sc(_BLEU); fc(_BLEU); c.setLineWidth(1.2)
    c.line(MARGE, y, width - MARGE, y)
    y -= 18

    # ── Médicaments ──────────────────────────────────────────────────────────
    fc(_NAVY); c.setFont("Helvetica-Bold", 12)
    c.drawString(MARGE, y, "Traitement prescrit")
    y -= 20

    for idx, ligne in enumerate(prescription.lignes.all(), start=1):
        if y < 200:
            c.showPage(); y = height - 60
        fc(_BLEU); c.setFont("Helvetica-Bold", 10)
        c.drawString(MARGE, y, f"{idx}.")
        fc((0, 0, 0)); c.setFont("Helvetica-Bold", 10)
        c.drawString(MARGE + 18, y, ligne.medicament[:80])
        y -= 14
        if ligne.posologie or ligne.duree:
            fc(_GRIS); c.setFont("Helvetica", 9)
            detail = ""
            if ligne.posologie:
                detail += f"Posologie : {ligne.posologie}"
            if ligne.duree:
                detail += f"  —  Durée : {ligne.duree}" if detail else f"Durée : {ligne.duree}"
            c.drawString(MARGE + 18, y, detail[:110])
            y -= 12
        if ligne.remarques:
            fc(_GRIS); c.setFont("Helvetica-Oblique", 9)
            c.drawString(MARGE + 18, y, f"Note : {ligne.remarques[:100]}")
            y -= 12
        y -= 6

    # ── Blocs optionnels ─────────────────────────────────────────────────────
    def _bloc(titre_bloc, contenu, couleur=_NAVY):
        nonlocal y
        if not contenu:
            return
        if y < 200:
            c.showPage(); y = height - 60
        y -= 10
        fc(couleur); c.setFont("Helvetica-Bold", 11)
        c.drawString(MARGE, y, titre_bloc)
        y -= 14
        fc((0.2, 0.2, 0.2)); c.setFont("Helvetica", 10)
        for line in contenu.splitlines():
            c.drawString(MARGE + 10, y, line[:115])
            y -= 13
            if y < 200:
                c.showPage(); y = height - 60; c.setFont("Helvetica", 10)

    _bloc("Notes du praticien :", prescription.note_praticien)
    _bloc("Conseils :", prescription.conseils)
    _bloc("Recommandations :", prescription.recommandations)

    # ── Zone de signature ────────────────────────────────────────────────────
    HAUTEUR_SIGNATURE = 140
    if y < HAUTEUR_SIGNATURE + 20:
        c.showPage(); y = height - 60

    y_sig  = HAUTEUR_SIGNATURE - 10
    BOX_W, BOX_H = 210, 110
    box_x  = width - MARGE - BOX_W
    box_y  = y_sig

    sc((0.8, 0.8, 0.8)); fc(_LEGER); c.setLineWidth(0.8)
    c.roundRect(box_x, box_y, BOX_W, BOX_H, 6, fill=1, stroke=1)

    fc(_NAVY); c.setFont("Helvetica-Bold", 9)
    c.drawCentredString(box_x + BOX_W / 2, box_y + BOX_H - 14, "Le Chirurgien-Dentiste")

    sc((0.6, 0.6, 0.6)); c.setLineWidth(0.5); c.setDash(3, 3)
    sig_line_y = box_y + 38
    c.line(box_x + 14, sig_line_y, box_x + BOX_W - 14, sig_line_y)
    c.setDash()

    # Priorité : signature dessinée > signature enregistrée du praticien
    effective_sig = sig_img
    if effective_sig is None and praticien and getattr(praticien, "signature_image", None):
        try:
            effective_sig = ImageReader(praticien.signature_image.path)
        except Exception:
            effective_sig = None

    if effective_sig is not None:
        try:
            sig_w, sig_h = 160, 50
            sig_x = box_x + (BOX_W - sig_w) / 2
            c.drawImage(effective_sig, sig_x, sig_line_y + 4, width=sig_w, height=sig_h,
                        preserveAspectRatio=True, mask="auto")
        except Exception:
            effective_sig = None  # fallback au placeholder

    if effective_sig is None:
        fc((0.75, 0.75, 0.75)); c.setFont("Helvetica-Oblique", 8)
        c.drawCentredString(box_x + BOX_W / 2, sig_line_y + 14, "Signature")

    fc(_NAVY); c.setFont("Helvetica-Bold", 9)
    praticien_label = (
        f"Dr. {praticien.first_name} {praticien.last_name}" if praticien else "Praticien"
    )
    c.drawCentredString(box_x + BOX_W / 2, box_y + 20, praticien_label)
    if praticien and getattr(praticien, "specialite", ""):
        fc(_GRIS); c.setFont("Helvetica", 8)
        c.drawCentredString(box_x + BOX_W / 2, box_y + 9, praticien.specialite)

    # ── Pied de page ─────────────────────────────────────────────────────────
    sc((0.8, 0.8, 0.8)); c.setLineWidth(0.5)
    c.line(MARGE, y_sig - 2, box_x - 14, y_sig - 2)

    fc(_GRIS); c.setFont("Helvetica-Oblique", 8)
    c.drawString(MARGE, y_sig + 40, "Document généré par Wam's — Cabinet Dentaire")
    c.drawString(MARGE, y_sig + 26, f"Ordonnance N° {prescription.id:05d}  ·  {prescription.cree_le:%d/%m/%Y %H:%M}")
    c.drawString(MARGE, y_sig + 12, "Ce document est valable 3 mois à compter de la date d'émission.")

    c.showPage()
    c.save()
    buffer.seek(0)
    return buffer


class PrescriptionViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    queryset = Prescription.objects.select_related(
        "patient", "dossier", "consultation", "praticien"
    ).prefetch_related("lignes")

    ACTIONS_ECRITURE = {"create", "update", "partial_update", "destroy"}

    def get_permissions(self):
        if self.action == "me":
            return [EstPatient()]
        if self.action in self.ACTIONS_ECRITURE:
            return [EstChirurgienDentiste()]
        return [EstPersonnelCabinet()]

    def get_queryset(self):
        qs = super().get_queryset()
        user = self.request.user
        if getattr(user, "role", None) == Utilisateur.Role.INFIRMIERE:
            qs = qs.filter(patient__infirmiere_referente=user)
        return qs

    def get_serializer_class(self):
        if self.action in ("create", "update", "partial_update"):
            return PrescriptionCreateSerializer
        return PrescriptionSerializer

    def perform_create(self, serializer):
        if not serializer.validated_data.get("dossier"):
            patient = serializer.validated_data.get("patient")
            dossier = getattr(patient, "dossier", None)
            if dossier:
                serializer.save(dossier=dossier)
                return
        serializer.save()

    @action(detail=False, methods=["get"], url_path=r"patient/(?P<patient_id>\d+)/historique")
    def historique_patient(self, request, patient_id=None):
        qs = self.get_queryset().filter(patient_id=patient_id)
        page = self.paginate_queryset(qs)
        if page is not None:
            serializer = PrescriptionSerializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = PrescriptionSerializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=["get"], url_path="me")
    def me(self, request):
        try:
            if not request.user.is_authenticated:
                return Response({"detail": "Utilisateur non authentifié."}, status=401)

            user_role = getattr(request.user, "role", None)
            if not request.user.is_superuser and (not user_role or user_role.lower() != "patient"):
                return Response({"detail": "L'utilisateur n'est pas un patient."}, status=403)

            patient = Patient.objects.filter(user=request.user).first()
            if not patient:
                return Response({
                    "detail": "Profil patient introuvable.",
                    "user_id": request.user.id,
                    "username": request.user.username,
                }, status=404)

            qs = self.get_queryset().filter(patient=patient)
            serializer = PrescriptionSerializer(qs, many=True)
            data = serializer.data
            for item in data:
                try:
                    item["pdf_url"] = f"/api/v1/prescriptions/{item['id']}/pdf/"
                except KeyError:
                    item["pdf_url"] = None
            return Response(data)

        except Exception as e:
            return Response({
                "detail": "Erreur lors de la récupération des prescriptions",
                "error": str(e),
            }, status=500)

    @action(detail=True, methods=["get"])
    def pdf(self, request, pk=None):
        """Génère l'ordonnance PDF sans signature dessinée (utilise la signature enregistrée si présente)."""
        prescription = self.get_object()
        buffer = _generer_pdf(prescription)
        return FileResponse(buffer, as_attachment=False, filename=f"ordonnance_{prescription.id}.pdf")

    @action(detail=True, methods=["post"], url_path="signer-pdf")
    def signer_pdf(self, request, pk=None):
        """Génère le PDF avec la signature dessinée fournie en base64 et le renvoie pour impression."""
        prescription = self.get_object()

        sig_b64 = request.data.get("signature_base64", "")
        sig_img = None
        if sig_b64:
            try:
                # Retirer le préfixe data URL si présent
                if sig_b64.startswith("data:"):
                    sig_b64 = sig_b64.split(",", 1)[1]
                sig_bytes = base64.b64decode(sig_b64)
                sig_img = ImageReader(io.BytesIO(sig_bytes))
            except Exception:
                sig_img = None

        buffer = _generer_pdf(prescription, sig_img=sig_img)
        filename = f"ordonnance_{prescription.id}_signee.pdf"
        return FileResponse(buffer, as_attachment=False, filename=filename)


class LignePrescriptionViewSet(viewsets.ModelViewSet):
    queryset = LignePrescription.objects.select_related("prescription").all()
    serializer_class = LignePrescriptionSerializer


#EbaJioloLewis
