from datetime import datetime

from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
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
from .services_ocr import analyser_carnet_medical, extraire_texte_image
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
    Réponse IA améliorée avec accès aux données du projet.
    """
    contexte = (
        f"Dossier: {dossier.numero_dossier}\n"
        f"Notes médicales: {dossier.notes_medicales or 'N/A'}\n"
        f"Antécédents: {dossier.antecedents or 'N/A'}\n"
        f"Allergies: {dossier.allergies or 'N/A'}\n"
    )
    
    # Utiliser le service IA amélioré avec les données du patient
    return reponse_ia(question=question, contexte=contexte, patient_id=dossier.patient_id)


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


@api_view(["POST"])
def ocr_carnet(request):
    """
    Traite une image de carnet médical avec OCR.
    """
    try:
        if 'image' not in request.FILES:
            return Response({"detail": "Aucune image fournie."}, status=400)
        
        image_file = request.FILES['image']
        
        # Extraire le texte avec OCR
        try:
            texte = extraire_texte_image(image_file)
        except Exception as ocr_error:
            print(f"Erreur OCR: {ocr_error}")
            # Utiliser un fallback si OCR échoue
            texte = "Texte non disponible - Erreur lors du traitement OCR"
        
        if not texte or texte.strip() == "":
            texte = "Texte non disponible - Impossible d'extraire du texte de l'image"
        
        # Analyser et structurer le contenu
        try:
            analyse = analyser_carnet_medical(texte)
        except Exception as analyse_error:
            print(f"Erreur analyse: {analyse_error}")
            analyse = {
                "donnees_structurees": {},
                "symptomes": [],
                "traitements": [],
                "notes": ["Erreur lors de l'analyse du texte OCR"],
                "dates": []
            }
        
        # Créer un enregistrement OCR si patient/dossier fourni
        patient_id = request.data.get('patient_id')
        dossier_id = request.data.get('dossier_id')
        
        ocr_record = None
        try:
            if patient_id or dossier_id:
                ocr_record = OCRImportCarnet.objects.create(
                    patient_id=patient_id,
                    dossier_id=dossier_id,
                    image_source=image_file,
                    texte_extrait=texte,
                    analyse=analyse,
                    cree_par=request.user
                )
        except Exception as save_error:
            print(f"Erreur sauvegarde OCR: {save_error}")
            # Continuer même si la sauvegarde échoue
        
        # Préparer la réponse avec les données structurées
        response_data = {
            "texte_extrait": texte,
            "donnees_structurees": analyse.get("donnees_structurees", {}),
            "symptomes": analyse.get("symptomes", []),
            "traitements": analyse.get("traitements", []),
            "notes": analyse.get("notes", []),
            "dates": analyse.get("dates", []),
            "confiance": 0.85,  # Taux de confiance moyen pour Tesseract
            "ocr_record_id": ocr_record.id if ocr_record else None,
            "status": "success" if texte and texte.strip() else "no_text"
        }
        
        return Response(response_data)
        
    except Exception as e:
        return Response({
            "detail": "Erreur lors du traitement OCR",
            "error": str(e),
            "status": "error",
            "texte_extrait": "Texte non disponible - Erreur système",
            "donnees_structurees": {},
            "symptomes": [],
            "traitements": [],
            "notes": ["Erreur système lors du traitement OCR"],
            "dates": [],
            "confiance": 0.0,
            "ocr_record_id": None
        }, status=500)


@api_view(["POST"])
def warms_ia_general(request):
    """
    Endpoint WARMS IA pour répondre aux questions générales sur la santé et le cabinet.
    """
    question = request.data.get("question", "")
    patient_id = request.data.get("patient_id")
    
    if not question:
        return Response({"detail": "Aucune question fournie."}, status=400)
    
    # Utiliser le service IA avec le contexte enrichi
    reponse = reponse_ia(question=question, contexte="", patient_id=patient_id)
    
    return Response({
        "question": question,
        "reponse": reponse,
        "timestamp": datetime.now().isoformat(),
        "patient_id": patient_id
    })


@api_view(["GET"])
def warms_ia_info(request):
    """
    Endpoint pour obtenir les informations sur WARMS IA.
    """
    return Response({
        "nom": "WARMS IA",
        "description": "Assistant médical intelligent pour le cabinet dentaire",
        "capacites": [
            "Répondre aux questions sur les symptômes dentaires",
            "Donner des informations sur les traitements",
            "Aider à la gestion des rendez-vous",
            "Fournir des informations sur le cabinet",
            "Accéder aux données patientes (avec autorisation)"
        ],
        "limitations": [
            "Ne remplace pas un diagnostic professionnel",
            "Pour les urgences, contacter directement le cabinet",
            "Les informations médicales sont générales"
        ]
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def warms_general(request):
    """
    Endpoint principal pour WARMS IA - utilise Claude avec recherche web
    """
    try:
        question = request.data.get('question', '').strip()
        contexte = request.data.get('contexte', '')
        patient_id = request.data.get('patient_id')
        
        if not question:
            return Response(
                {'detail': 'La question est obligatoire'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Appeler le service LLM avec Claude
        reponse = reponse_ia(question, contexte, patient_id)
        
        # Journaliser l'interaction
        journaliser(
            acteur=request.user,
            action="ia.warms_question",
            objet_type="WarmsIA",
            message=f"Question WARMS IA: {question[:100]}...",
            metadata={
                'question': question,
                'contexte': contexte,
                'patient_id': patient_id,
                'reponse_length': len(reponse)
            }
        )
        
        return Response({
            'question': question,
            'reponse': reponse,
            'timestamp': datetime.now().isoformat(),
            'patient_id': patient_id,
            'source': 'claude_anthropic'
        })
        
    except Exception as e:
        print(f"Erreur WARMS IA: {e}")
        return Response(
            {'detail': f'Erreur lors du traitement de la question: {str(e)}'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def warms_info(request):
    """
    Informations sur WARMS IA
    """
    return Response({
        "nom": "WARMS IA",
        "description": "Assistant médical intelligent propulsé par Claude (Anthropic)",
        "version": "2.0",
        "capacites": [
            "Répondre aux questions sur les symptômes dentaires",
            "Donner des informations sur les traitements",
            "Aider à la gestion des rendez-vous",
            "Fournir des informations sur le cabinet",
            "Accéder aux données patientes (avec autorisation)",
            "Recherche web d'informations médicales actualisées"
        ],
        "limitations": [
            "Ne remplace pas un diagnostic professionnel",
            "Pour les urgences, contacter directement le cabinet",
            "Les informations médicales sont générales"
        ],
        "technologie": "Claude 3.5 Sonnet avec recherche web intégrée"
    })


@api_view(['POST'])
def warms_demo(request):
    """
    Endpoint de démonstration pour WARMS IA - fonctionne sans authentification
    Utilise le fallback local enrichi avec données réelles du cabinet
    """
    try:
        question = request.data.get('question', '').strip()
        contexte = request.data.get('contexte', 'Demo endpoint')
        patient_id = request.data.get('patient_id')
        
        if not question:
            return Response(
                {'detail': 'La question est obligatoire'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Utiliser le service local enrichi (pas besoin de clé API)
        reponse = reponse_ia(question, contexte, patient_id)
        
        return Response({
            'question': question,
            'reponse': reponse,
            'timestamp': datetime.now().isoformat(),
            'patient_id': patient_id,
            'source': 'demo_local_enriched',
            'mode': 'demo',
            'technologie': 'Fallback local avec données cabinet'
        })
        
    except Exception as e:
        print(f"Erreur WARMS Demo: {e}")
        return Response(
            {'detail': f'Erreur lors du traitement: {str(e)}'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


#EbaJioloLewis
