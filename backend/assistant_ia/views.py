from datetime import datetime

from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action, api_view
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response

from consultations.models import Consultation
from journaux.utils import journaliser
from patients.models import DossierPatient, PageCarnet
from rendez_vous.models import RendezVous

from .models import CompteRenduIA, MessageAssistantIA, OCRImportCarnet, RecommandationIA
from .serializers import (
    CompteRenduIASerializer,
    MessageAssistantIASerializer,
    OCRImportCarnetSerializer,
    RecommandationIASerializer,
)
from .services_llm import reponse_ia
from .services_recherche import FiltresRecherche, recherche_globale, suggestions


def _parse_date(value: str | None):
    if not value:
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


@api_view(["GET"])
def recherche(request):
    q = request.query_params.get("q", "")
    filtres = FiltresRecherche(
        date_debut=_parse_date(request.query_params.get("date_debut")),
        date_fin=_parse_date(request.query_params.get("date_fin")),
        statut=request.query_params.get("statut") or None,
        praticien_id=int(request.query_params["praticien_id"])
        if request.query_params.get("praticien_id")
        else None,
        type_acte=request.query_params.get("type_acte") or None,
    )
    return Response(recherche_globale(q, filtres))


@api_view(["GET"])
def suggestions_recherche(request):
    q = request.query_params.get("q", "")
    return Response({"query": q, "suggestions": suggestions(q)})


def _generer_reponse_contextuelle(question: str, dossier: DossierPatient) -> str:
    """
    Réponse simple basée sur le contexte dossier.
    Un moteur LLM peut remplacer cette logique plus tard.
    """
    contexte = (
        f"Dossier: {dossier.numero_dossier}\n"
        f"Notes médicales: {dossier.notes_medicales or 'N/A'}\n"
        f"Antécédents: {dossier.antecedents or 'N/A'}\n"
        f"Allergies: {dossier.allergies or 'N/A'}\n"
    )
    reponse = reponse_ia(question=question, contexte=contexte)
    if "fallback" not in reponse.lower():
        return reponse

    # Fallback local si provider IA indisponible
    q = (question or "").lower()
    base = f"Dossier {dossier.numero_dossier}. "
    if "allerg" in q:
        return base + (dossier.allergies or "Aucune allergie renseignée pour le moment.")
    if "anteced" in q:
        return base + (dossier.antecedents or "Aucun antécédent renseigné pour le moment.")
    if "note" in q or "resume" in q:
        return base + (dossier.notes_medicales or "Aucune note clinique renseignée.")
    return base + "Question reçue. Réponse générée sur les informations actuellement disponibles."


def _generer_compte_rendu(consultation: Consultation) -> str:
    actes = list(consultation.actes.values_list("libelle", flat=True))
    actes_str = ", ".join(actes) if actes else "Aucun acte saisi"
    return (
        f"Compte-rendu automatique de la consultation du {consultation.date:%d/%m/%Y %H:%M}\n\n"
        f"Patient: {consultation.patient.prenom} {consultation.patient.nom}\n"
        f"Motif: {consultation.motif or 'Non renseigné'}\n"
        f"Observations: {consultation.observations or 'Non renseignées'}\n"
        f"Diagnostic: {consultation.diagnostic or 'Non renseigné'}\n"
        f"Actes réalisés: {actes_str}\n"
        f"Notes praticien: {consultation.notes or 'Non renseignées'}\n\n"
        "Synthèse IA: suivi recommandé selon évolution clinique et protocole du cabinet."
    )


class OCRImportCarnetViewSet(viewsets.ModelViewSet):
    queryset = OCRImportCarnet.objects.select_related("patient", "dossier").all()
    serializer_class = OCRImportCarnetSerializer
    parser_classes = [MultiPartParser, FormParser]

    def perform_create(self, serializer):
        instance = serializer.save(cree_par=self.request.user)
        journaliser(
            acteur=self.request.user,
            action="ocr.imported",
            objet_type="OCRImportCarnet",
            objet_id=instance.id,
            message="Import OCR carnet enregistré.",
        )


class MessageAssistantIAViewSet(viewsets.ModelViewSet):
    queryset = MessageAssistantIA.objects.select_related("dossier").all()
    serializer_class = MessageAssistantIASerializer

    def create(self, request, *args, **kwargs):
        dossier_id = request.data.get("dossier")
        question = request.data.get("question", "")
        dossier = DossierPatient.objects.filter(id=dossier_id).first()
        if not dossier:
            return Response({"detail": "Dossier introuvable."}, status=status.HTTP_404_NOT_FOUND)
        reponse = _generer_reponse_contextuelle(question, dossier)
        instance = MessageAssistantIA.objects.create(
            dossier=dossier, auteur=request.user, question=question, reponse=reponse
        )
        return Response(MessageAssistantIASerializer(instance).data, status=status.HTTP_201_CREATED)


class RecommandationIAViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = RecommandationIA.objects.select_related("patient").all()
    serializer_class = RecommandationIASerializer

    @action(detail=False, methods=["post"])
    def generer(self, request):
        """
        Génère des recommandations simples à partir d'heuristiques.
        """
        created = 0
        rdvs_absents = RendezVous.objects.filter(statut=RendezVous.Statut.ABSENT)[:200]
        for rdv in rdvs_absents:
            _, was_created = RecommandationIA.objects.get_or_create(
                patient=rdv.patient,
                type_recommandation=RecommandationIA.TypeRecommandation.RAPPEL,
                message="Relancer le patient suite à une absence au rendez-vous.",
                defaults={"score_confiance": 0.82},
            )
            if was_created:
                created += 1

        sans_consult_6m = Consultation.objects.values("patient_id").distinct()
        patient_ids_avec_consult = {row["patient_id"] for row in sans_consult_6m}
        patients_a_controler = DossierPatient.objects.exclude(
            patient_id__in=patient_ids_avec_consult
        )[:200]
        for dossier in patients_a_controler:
            _, was_created = RecommandationIA.objects.get_or_create(
                patient_id=dossier.patient_id,
                type_recommandation=RecommandationIA.TypeRecommandation.CONTROLE,
                message="Programmer un contrôle périodique (pas de consultation enregistrée).",
                defaults={"score_confiance": 0.71},
            )
            if was_created:
                created += 1

        return Response({"created": created})


class CompteRenduIAViewSet(
    mixins.RetrieveModelMixin, mixins.ListModelMixin, viewsets.GenericViewSet
):
    queryset = CompteRenduIA.objects.select_related("consultation").all()
    serializer_class = CompteRenduIASerializer

    @action(detail=False, methods=["post"])
    def generer(self, request):
        consultation_id = request.data.get("consultation_id")
        consultation = Consultation.objects.filter(id=consultation_id).first()
        if not consultation:
            return Response({"detail": "Consultation introuvable."}, status=status.HTTP_404_NOT_FOUND)
        contenu = _generer_compte_rendu(consultation)
        compte_rendu, _created = CompteRenduIA.objects.update_or_create(
            consultation=consultation,
            defaults={"contenu": contenu, "genere_par": request.user},
        )
        journaliser(
            acteur=request.user,
            action="consultation.report_generated",
            objet_type="Consultation",
            objet_id=consultation.id,
            message="Compte-rendu de consultation généré automatiquement.",
        )
        return Response(CompteRenduIASerializer(compte_rendu).data, status=status.HTTP_201_CREATED)


@api_view(["GET"])
def sync_offline(request):
    """
    Endpoint de sync pour mode hors-ligne:
    renvoie un snapshot léger des dossiers/rdv/consultations récents.
    """
    dossier_ids = request.query_params.getlist("dossier_id")
    qs_dossiers = DossierPatient.objects.select_related("patient").all()
    if dossier_ids:
        qs_dossiers = qs_dossiers.filter(id__in=dossier_ids)
    qs_dossiers = qs_dossiers.order_by("-modifie_le")[:30]

    payload = []
    for d in qs_dossiers:
        consultations = Consultation.objects.filter(dossier=d).order_by("-date")[:8]
        rdvs = RendezVous.objects.filter(patient=d.patient).order_by("-debut")[:8]
        pages = PageCarnet.objects.filter(dossier=d).order_by("-numero_page")[:8]
        payload.append(
            {
                "dossier": {"id": str(d.id), "numero_dossier": d.numero_dossier},
                "patient": {"id": d.patient_id, "prenom": d.patient.prenom, "nom": d.patient.nom},
                "consultations": [
                    {"id": c.id, "date": c.date, "diagnostic": c.diagnostic, "notes": c.notes}
                    for c in consultations
                ],
                "rendez_vous": [
                    {"id": r.id, "debut": r.debut, "statut": r.statut, "motif": r.motif}
                    for r in rdvs
                ],
                "pages_carnet": [
                    {"id": p.id, "numero_page": p.numero_page, "contenu": p.contenu}
                    for p in pages
                ],
            }
        )
    return Response({"count": len(payload), "items": payload})


#EbaJioloLewis
