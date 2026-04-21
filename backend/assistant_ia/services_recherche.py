from __future__ import annotations

import difflib
from dataclasses import dataclass
from datetime import datetime
from typing import Any

from consultations.models import ActeRealise, Consultation
from patients.models import DossierPatient, Patient
from prescriptions.models import Prescription
from rendez_vous.models import RendezVous


@dataclass
class FiltresRecherche:
    date_debut: datetime | None = None
    date_fin: datetime | None = None
    statut: str | None = None
    praticien_id: int | None = None
    type_acte: str | None = None


def _score_approx(needle: str, haystack: str) -> float:
    if not needle or not haystack:
        return 0.0
    return difflib.SequenceMatcher(None, needle.lower(), haystack.lower()).ratio()


def _match_texte(needle: str, *fields: str) -> bool:
    q = (needle or "").strip().lower()
    if not q:
        return True
    return any(q in (field or "").lower() for field in fields)


def recherche_globale(query: str, filtres: FiltresRecherche) -> dict[str, Any]:
    """
    Recherche contextuelle multi-modules.
    """
    q = (query or "").strip()

    patients = Patient.objects.all()
    dossiers = DossierPatient.objects.select_related("patient").all()
    rendez_vous = RendezVous.objects.select_related("patient", "praticien").all()
    consultations = Consultation.objects.select_related("patient", "praticien").all()
    prescriptions = Prescription.objects.select_related("patient", "consultation").all()
    actes = ActeRealise.objects.select_related("consultation", "consultation__patient").all()

    if filtres.date_debut:
        rendez_vous = rendez_vous.filter(debut__gte=filtres.date_debut)
        consultations = consultations.filter(date__gte=filtres.date_debut)
        prescriptions = prescriptions.filter(cree_le__gte=filtres.date_debut)
    if filtres.date_fin:
        rendez_vous = rendez_vous.filter(debut__lte=filtres.date_fin)
        consultations = consultations.filter(date__lte=filtres.date_fin)
        prescriptions = prescriptions.filter(cree_le__lte=filtres.date_fin)
    if filtres.statut:
        rendez_vous = rendez_vous.filter(statut=filtres.statut)
    if filtres.praticien_id:
        rendez_vous = rendez_vous.filter(praticien_id=filtres.praticien_id)
        consultations = consultations.filter(praticien_id=filtres.praticien_id)
        prescriptions = prescriptions.filter(praticien_id=filtres.praticien_id)
    if filtres.type_acte:
        actes = actes.filter(libelle__icontains=filtres.type_acte)

    patients_data = []
    for p in patients:
        if _match_texte(q, p.prenom, p.nom, p.telephone, p.email):
            score = max(
                _score_approx(q, p.prenom),
                _score_approx(q, p.nom),
                _score_approx(q, f"{p.prenom} {p.nom}"),
            )
            patients_data.append(
                {
                    "type": "patient",
                    "id": p.id,
                    "label": f"{p.prenom} {p.nom}",
                    "score": round(score, 3),
                    "data": {"telephone": p.telephone, "email": p.email},
                }
            )

    dossiers_data = []
    for d in dossiers:
        if _match_texte(q, d.numero_dossier, d.notes_medicales, d.antecedents, d.allergies):
            dossiers_data.append(
                {
                    "type": "dossier",
                    "id": str(d.id),
                    "label": d.numero_dossier,
                    "score": round(_score_approx(q, d.numero_dossier), 3),
                    "data": {"patient_id": d.patient_id},
                }
            )

    rdv_data = []
    for rdv in rendez_vous:
        if _match_texte(q, rdv.motif, rdv.notes, rdv.patient.nom, rdv.patient.prenom):
            rdv_data.append(
                {
                    "type": "rendez_vous",
                    "id": rdv.id,
                    "label": f"RDV {rdv.patient.prenom} {rdv.patient.nom}",
                    "score": round(
                        max(_score_approx(q, rdv.motif), _score_approx(q, rdv.patient.nom)),
                        3,
                    ),
                    "data": {"debut": rdv.debut, "statut": rdv.statut, "praticien_id": rdv.praticien_id},
                }
            )

    consultations_data = []
    for c in consultations:
        if _match_texte(q, c.motif, c.observations, c.diagnostic, c.notes, c.patient.nom):
            consultations_data.append(
                {
                    "type": "consultation",
                    "id": c.id,
                    "label": f"Consultation {c.patient.prenom} {c.patient.nom}",
                    "score": round(max(_score_approx(q, c.motif), _score_approx(q, c.diagnostic)), 3),
                    "data": {"date": c.date, "praticien_id": c.praticien_id},
                }
            )

    prescriptions_data = []
    for p in prescriptions:
        if _match_texte(q, p.titre, p.note_praticien, p.patient.nom, p.patient.prenom):
            prescriptions_data.append(
                {
                    "type": "prescription",
                    "id": p.id,
                    "label": p.titre or f"Prescription {p.patient.prenom} {p.patient.nom}",
                    "score": round(max(_score_approx(q, p.titre), _score_approx(q, p.patient.nom)), 3),
                    "data": {"patient_id": p.patient_id, "consultation_id": p.consultation_id},
                }
            )

    actes_data = []
    for a in actes:
        patient = a.consultation.patient
        if _match_texte(q, a.libelle, a.description, a.dent, patient.nom, patient.prenom):
            actes_data.append(
                {
                    "type": "acte",
                    "id": a.id,
                    "label": a.libelle,
                    "score": round(_score_approx(q, a.libelle), 3),
                    "data": {"consultation_id": a.consultation_id, "patient_id": patient.id},
                }
            )

    resultats = (
        patients_data
        + dossiers_data
        + rdv_data
        + consultations_data
        + prescriptions_data
        + actes_data
    )
    resultats.sort(key=lambda x: x["score"], reverse=True)

    return {
        "query": q,
        "total": len(resultats),
        "resultats": resultats,
        "groupes": {
            "patients": len(patients_data),
            "dossiers": len(dossiers_data),
            "rendez_vous": len(rdv_data),
            "consultations": len(consultations_data),
            "prescriptions": len(prescriptions_data),
            "actes": len(actes_data),
        },
    }


def suggestions(query: str) -> list[str]:
    q = (query or "").strip().lower()
    if not q:
        return []

    pool: list[str] = []
    pool.extend(list(Patient.objects.values_list("nom", flat=True)[:300]))
    pool.extend(list(Patient.objects.values_list("prenom", flat=True)[:300]))
    pool.extend(list(DossierPatient.objects.values_list("numero_dossier", flat=True)[:300]))
    pool.extend(list(RendezVous.objects.values_list("motif", flat=True)[:300]))
    pool.extend(list(ActeRealise.objects.values_list("libelle", flat=True)[:300]))
    pool.extend(list(Prescription.objects.values_list("titre", flat=True)[:300]))

    uniques = [p for p in {item.strip() for item in pool if item and item.strip()}]
    starts = [u for u in uniques if u.lower().startswith(q)]
    fuzzy = difflib.get_close_matches(query, uniques, n=8, cutoff=0.45)

    ordered = starts[:8]
    for item in fuzzy:
        if item not in ordered:
            ordered.append(item)
        if len(ordered) >= 10:
            break
    return ordered[:10]


#EbaJioloLewis
