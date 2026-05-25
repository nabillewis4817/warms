from datetime import timedelta
from django.db.models import Count
from django.db.models.functions import TruncDate, TruncMonth
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response

from consultations.models import ActeRealise, Consultation
from patients.models import Patient
from rendez_vous.models import RendezVous


@api_view(["GET"])
@permission_classes([IsAuthenticated])
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

    patients_total = Patient.objects.filter(actif=True).count()
    patients_30j = Patient.objects.filter(cree_le__gte=start_30, actif=True).count()
    start_60 = now - timedelta(days=60)
    patients_prev = Patient.objects.filter(cree_le__gte=start_60, cree_le__lt=start_30, actif=True).count()
    patients_tendance = round(((patients_30j - patients_prev) / patients_prev) * 100, 1) if patients_prev else 0.0

    try:
        from prescriptions.models import Prescription
        ordonnances_30j = Prescription.objects.filter(cree_le__gte=start_30).count()
        ordonnances_prev = Prescription.objects.filter(cree_le__gte=start_60, cree_le__lt=start_30).count()
    except Exception:
        ordonnances_30j = 0
        ordonnances_prev = 0
    ordonnances_tendance = round(((ordonnances_30j - ordonnances_prev) / ordonnances_prev) * 100, 1) if ordonnances_prev else 0.0

    rdv_prev = RendezVous.objects.filter(debut__gte=start_60, debut__lt=start_30).count()
    rendez_vous_tendance = round(((rdv_30j - rdv_prev) / rdv_prev) * 100, 1) if rdv_prev else 0.0

    consultations_prev = Consultation.objects.filter(date__gte=start_60, date__lt=start_30).count()
    consultations_tendance = round(((consultations_30j - consultations_prev) / consultations_prev) * 100, 1) if consultations_prev else 0.0

    # Chiffre d'affaires estimé : 45 € par acte sur la période (ajustable)
    ca_mois = (ActeRealise.objects.filter(consultation__date__gte=start_30).count() * 45)
    ca_prev = (ActeRealise.objects.filter(consultation__date__gte=start_60, consultation__date__lt=start_30).count() * 45)
    ca_tendance = round(((ca_mois - ca_prev) / ca_prev) * 100, 1) if ca_prev else 0.0

    rdv_par_mois = (
        RendezVous.objects.filter(debut__gte=now - timedelta(days=180))
        .annotate(mois=TruncMonth("debut"))
        .values("mois")
        .annotate(nombre=Count("id"))
        .order_by("mois")
    )
    rendez_vois_mois = [
        {
            "mois": (entry["mois"].strftime("%b") if entry["mois"] else "?"),
            "nombre": entry["nombre"],
        }
        for entry in rdv_par_mois
    ]
    max_rendez_vois = max((m["nombre"] for m in rendez_vois_mois), default=1)

    couleurs = ["#1E4DB7", "#3B82F6", "#22C55E", "#F59E0B", "#EF4444"]
    repartition_sexe = (
        Patient.objects.filter(actif=True)
        .values("sexe")
        .annotate(nombre=Count("id"))
        .order_by("-nombre")
    )
    patient_categories = [
        {
            "nom": (row["sexe"] or "Non renseigné").capitalize(),
            "nombre": row["nombre"],
            "couleur": couleurs[i % len(couleurs)],
        }
        for i, row in enumerate(repartition_sexe)
    ]

    metriques_detaillees = [
        {"nom": "Consultations (30j)", "valeur": consultations_30j, "periode": "30 jours", "tendance": consultations_tendance},
        {"nom": "Rendez-vous (30j)", "valeur": rdv_30j, "periode": "30 jours", "tendance": rendez_vous_tendance},
        {"nom": "Patients actifs", "valeur": patients_total, "periode": "Total", "tendance": patients_tendance},
        {"nom": "Taux d'absentéisme", "valeur": f"{taux_absenteisme}%", "periode": "30 jours", "tendance": 0},
        {"nom": "Ordonnances (30j)", "valeur": ordonnances_30j, "periode": "30 jours", "tendance": ordonnances_tendance},
    ]

    return Response(
        {
            "periode": {"debut": start_30.isoformat(), "fin": now.isoformat()},
            "derniere_mise_a_jour": now.strftime("%d/%m/%Y %H:%M"),
            "kpis": {
                "consultations_30j": consultations_30j,
                "rendez_vous_30j": rdv_30j,
                "absents_30j": absents_30j,
                "taux_absenteisme_30j": taux_absenteisme,
            },
            "patients_total": patients_total,
            "patients_tendance": patients_tendance,
            "rendez_vous_30j": rdv_30j,
            "rendez_vous_tendance": rendez_vous_tendance,
            "ordonnances_30j": ordonnances_30j,
            "ordonnances_tendance": ordonnances_tendance,
            "chiffre_affaires_mois": ca_mois,
            "ca_tendance": ca_tendance,
            "rendez_vois_mois": rendez_vois_mois,
            "max_rendez_vois": max_rendez_vois,
            "patient_categories": patient_categories,
            "metriques_detaillees": metriques_detaillees,
            "series": {
                "consultations_par_jour": list(consultations_par_jour),
                "consultations_par_praticien": list(consultations_par_praticien),
                "pathologies_tendance": list(pathologies_tendance),
                "actes_frequents": list(actes_frequents),
            },
        }
    )


@api_view(["GET"])
@permission_classes([IsAuthenticated])
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
@permission_classes([IsAuthenticated])
def parcours_patient(request):
    patient = Patient.objects.filter(user=request.user).first()
    if not patient:
        return Response({"detail": "Profil patient introuvable."}, status=404)
    now = timezone.now()
    avant = RendezVous.objects.filter(patient=patient, debut__lt=now).count()
    apres = RendezVous.objects.filter(patient=patient, debut__gte=now).count()
    return Response({"avant": avant, "apres": apres})


#EbaJioloLewis
