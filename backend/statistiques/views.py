from datetime import timedelta

from django.db.models import Count
from django.db.models.functions import TruncDate
from django.utils import timezone
from rest_framework.decorators import api_view
from rest_framework.response import Response

from consultations.models import ActeRealise, Consultation
from patients.models import Patient
from rendez_vous.models import RendezVous


@api_view(["GET"])
def vue_generale(request):
    """
    Tableau de bord global du cabinet.
    """
    now = timezone.now()
    start_30 = now - timedelta(days=30)

    consultations_30j = Consultation.objects.filter(date__gte=start_30).count()
    rdv_30j = RendezVous.objects.filter(debut__gte=start_30).count()
    absents_30j = RendezVous.objects.filter(
        debut__gte=start_30, statut=RendezVous.Statut.ABSENT
    ).count()

    taux_absenteisme = round((absents_30j / rdv_30j) * 100, 2) if rdv_30j else 0.0

    consultations_par_jour = (
        Consultation.objects.filter(date__gte=start_30)
        .annotate(jour=TruncDate("date"))
        .values("jour")
        .annotate(total=Count("id"))
        .order_by("jour")
    )

    consultations_par_praticien = (
        Consultation.objects.filter(date__gte=start_30)
        .values("praticien_id", "praticien__first_name", "praticien__last_name")
        .annotate(total=Count("id"))
        .order_by("-total")
    )

    pathologies_tendance = (
        Consultation.objects.filter(date__gte=start_30)
        .exclude(diagnostic="")
        .values("diagnostic")
        .annotate(total=Count("id"))
        .order_by("-total")[:10]
    )

    actes_frequents = (
        ActeRealise.objects.filter(consultation__date__gte=start_30)
        .values("libelle")
        .annotate(total=Count("id"))
        .order_by("-total")[:10]
    )

    return Response(
        {
            "periode": {"debut": start_30, "fin": now},
            "kpis": {
                "consultations_30j": consultations_30j,
                "rendez_vous_30j": rdv_30j,
                "absents_30j": absents_30j,
                "taux_absenteisme_30j": taux_absenteisme,
            },
            "series": {
                "consultations_par_jour": list(consultations_par_jour),
                "consultations_par_praticien": list(consultations_par_praticien),
                "pathologies_tendance": list(pathologies_tendance),
                "actes_frequents": list(actes_frequents),
            },
        }
    )


@api_view(["GET"])
def absentéisme(request):
    """
    Détails absentéisme et base pour relance auto.
    """
    now = timezone.now()
    start_90 = now - timedelta(days=90)

    absences = RendezVous.objects.filter(
        debut__gte=start_90, statut=RendezVous.Statut.ABSENT
    ).select_related("patient")

    par_patient = (
        absences.values("patient_id", "patient__prenom", "patient__nom")
        .annotate(total=Count("id"))
        .order_by("-total")
    )

    return Response(
        {
            "periode": {"debut": start_90, "fin": now},
            "total_absences": absences.count(),
            "par_patient": list(par_patient),
        }
    )


@api_view(["GET"])
def parcours_patient(request):
    patient = Patient.objects.filter(user=request.user).first()
    if not patient:
        return Response({"detail": "Profil patient introuvable."}, status=404)
    now = timezone.now()
    avant = RendezVous.objects.filter(patient=patient, debut__lt=now).count()
    apres = RendezVous.objects.filter(patient=patient, debut__gte=now).count()
    return Response({"avant": avant, "apres": apres})


#EbaJioloLewis
