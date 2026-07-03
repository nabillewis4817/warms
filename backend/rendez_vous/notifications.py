"""
Notifications automatiques patients — RDV et consultations.

Chaque événement déclenche :
  1. Un message dans la conversation patient existante (messagerie interne)
  2. Une NotificationInterne (badge + push mobile)
  3. Un email personnalisé (si le patient a un email)
"""

import logging

from django.conf import settings
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from django.utils import timezone

from messagerie.models import (
    Conversation,
    Message,
    NotificationInterne,
    ParticipantConversation,
)

logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────────────────────
# Helpers internes
# ──────────────────────────────────────────────────────────────

def _conversation_patient(patient, cree_par=None):
    """Retourne la conversation de suivi du patient (crée si absente)."""
    conv = Conversation.objects.filter(
        type_conversation=Conversation.TypeConversation.PATIENT,
        patient=patient,
    ).first()
    if conv:
        return conv
    conv = Conversation.objects.create(
        titre=f"Suivi patient {patient.prenom} {patient.nom}",
        type_conversation=Conversation.TypeConversation.PATIENT,
        patient=patient,
        cree_par=cree_par,
    )
    if patient.user_id:
        ParticipantConversation.objects.get_or_create(
            conversation=conv, utilisateur_id=patient.user_id
        )
    return conv


def _poster_message(patient, texte, auteur=None):
    """Poste un message système dans la conversation patient."""
    if not patient.user_id:
        return
    conv = _conversation_patient(patient, cree_par=auteur)
    Message.objects.create(
        conversation=conv,
        auteur=auteur,
        contenu=texte,
    )


def _notif(patient, titre, contenu, niveau=NotificationInterne.Niveau.RAPPEL):
    """Crée une NotificationInterne pour le patient."""
    if not patient.user_id:
        return
    NotificationInterne.objects.create(
        destinataire_id=patient.user_id,
        titre=titre,
        contenu=contenu,
        niveau=niveau,
    )


def _email(destinataire_email, sujet, template_base, contexte):
    """Envoie un email transactionnel sans jamais propager d'exception."""
    if not destinataire_email:
        return
    ctx = {
        "site_name": settings.SITE_NAME,
        "frontend_url": settings.FRONTEND_URL,
        "annee": timezone.now().year,
        **contexte,
    }
    try:
        texte = render_to_string(f"emails/{template_base}.txt", ctx)
        html = render_to_string(f"emails/{template_base}.html", ctx)
        msg = EmailMultiAlternatives(
            subject=sujet,
            body=texte,
            from_email=settings.DEFAULT_FROM_EMAIL,
            to=[destinataire_email],
        )
        msg.attach_alternative(html, "text/html")
        msg.send(fail_silently=False)
    except Exception:
        logger.exception("Échec envoi email '%s' à %s", template_base, destinataire_email)


# ──────────────────────────────────────────────────────────────
# API publique
# ──────────────────────────────────────────────────────────────

def notifier_rdv_programme(rdv, acteur=None):
    """Appelé lors de la création d'un nouveau rendez-vous."""
    patient = rdv.patient
    date_str = rdv.debut.strftime("%d/%m/%Y")
    heure_str = rdv.debut.strftime("%H:%M")
    praticien_nom = (
        f"Dr. {rdv.praticien.first_name} {rdv.praticien.last_name}".strip()
        if rdv.praticien else "votre praticien"
    )
    motif = rdv.motif or "Consultation dentaire"

    texte_msg = (
        f"📅 Votre rendez-vous du {date_str} à {heure_str} avec {praticien_nom} "
        f"a bien été programmé. Motif : {motif}."
    )
    _poster_message(patient, texte_msg, auteur=acteur)
    _notif(
        patient,
        titre="Rendez-vous programmé",
        contenu=f"{date_str} à {heure_str} — {motif}",
        niveau=NotificationInterne.Niveau.RAPPEL,
    )
    email_patient = getattr(patient, "email", "") or (
        patient.user.email if patient.user_id and patient.user else ""
    )
    _email(
        email_patient,
        sujet=f"Votre rendez-vous du {date_str} — {settings.SITE_NAME}",
        template_base="rdv_programme",
        contexte={
            "prenom": patient.prenom,
            "date_str": date_str,
            "heure_str": heure_str,
            "praticien_nom": praticien_nom,
            "motif": motif,
        },
    )


def notifier_rdv_confirme(rdv, acteur=None):
    """Appelé quand le statut passe à 'confirme'."""
    patient = rdv.patient
    date_str = rdv.debut.strftime("%d/%m/%Y")
    heure_str = rdv.debut.strftime("%H:%M")
    texte_msg = f"✅ Votre rendez-vous du {date_str} à {heure_str} est maintenant confirmé."
    _poster_message(patient, texte_msg, auteur=acteur)
    _notif(patient, "Rendez-vous confirmé", f"{date_str} à {heure_str}", NotificationInterne.Niveau.RAPPEL)


def notifier_rdv_annule(rdv, raison="", acteur=None):
    """Appelé lors de l'annulation d'un rendez-vous."""
    patient = rdv.patient
    date_str = rdv.debut.strftime("%d/%m/%Y")
    heure_str = rdv.debut.strftime("%H:%M")
    raison_txt = f" Raison : {raison}." if raison else ""
    texte_msg = f"❌ Votre rendez-vous du {date_str} à {heure_str} a été annulé.{raison_txt} Veuillez nous contacter pour reprogrammer."
    _poster_message(patient, texte_msg, auteur=acteur)
    _notif(patient, "Rendez-vous annulé", f"{date_str} à {heure_str}", NotificationInterne.Niveau.CRITIQUE)
    email_patient = getattr(patient, "email", "") or (
        patient.user.email if patient.user_id and patient.user else ""
    )
    _email(
        email_patient,
        sujet=f"Annulation de votre rendez-vous du {date_str} — {settings.SITE_NAME}",
        template_base="rdv_annule",
        contexte={
            "prenom": patient.prenom,
            "date_str": date_str,
            "heure_str": heure_str,
            "raison": raison,
        },
    )


def notifier_rdv_reporte(rdv, ancienne_date=None, acteur=None):
    """Appelé lors du report d'un rendez-vous."""
    patient = rdv.patient
    nouvelle_date_str = rdv.debut.strftime("%d/%m/%Y")
    nouvelle_heure_str = rdv.debut.strftime("%H:%M")
    ancienne_str = ancienne_date.strftime("%d/%m/%Y à %H:%M") if ancienne_date else "votre précédent créneau"
    texte_msg = (
        f"🔄 Votre rendez-vous prévu le {ancienne_str} a été reporté au "
        f"{nouvelle_date_str} à {nouvelle_heure_str}."
    )
    _poster_message(patient, texte_msg, auteur=acteur)
    _notif(patient, "Rendez-vous reporté", f"Nouveau créneau : {nouvelle_date_str} à {nouvelle_heure_str}", NotificationInterne.Niveau.RAPPEL)
    email_patient = getattr(patient, "email", "") or (
        patient.user.email if patient.user_id and patient.user else ""
    )
    _email(
        email_patient,
        sujet=f"Votre rendez-vous a été reporté — {settings.SITE_NAME}",
        template_base="rdv_reporte",
        contexte={
            "prenom": patient.prenom,
            "ancienne_str": ancienne_str,
            "nouvelle_date_str": nouvelle_date_str,
            "nouvelle_heure_str": nouvelle_heure_str,
        },
    )


def notifier_consultation_programmee(consultation, acteur=None):
    """Appelé lors de la création d'une consultation."""
    patient = consultation.patient
    date_str = consultation.date.strftime("%d/%m/%Y")
    heure_str = consultation.date.strftime("%H:%M")
    praticien_nom = (
        f"Dr. {consultation.praticien.first_name} {consultation.praticien.last_name}".strip()
        if consultation.praticien else "votre praticien"
    )
    motif = consultation.motif or "Consultation dentaire"
    texte_msg = (
        f"🦷 Votre consultation du {date_str} à {heure_str} avec {praticien_nom} "
        f"a bien été enregistrée. Motif : {motif}."
    )
    _poster_message(patient, texte_msg, auteur=acteur)
    _notif(
        patient,
        titre="Consultation enregistrée",
        contenu=f"{date_str} à {heure_str} — {motif}",
        niveau=NotificationInterne.Niveau.INFO,
    )
    email_patient = getattr(patient, "email", "") or (
        patient.user.email if patient.user_id and patient.user else ""
    )
    _email(
        email_patient,
        sujet=f"Votre consultation du {date_str} — {settings.SITE_NAME}",
        template_base="consultation_programmee",
        contexte={
            "prenom": patient.prenom,
            "date_str": date_str,
            "heure_str": heure_str,
            "praticien_nom": praticien_nom,
            "motif": motif,
        },
    )
