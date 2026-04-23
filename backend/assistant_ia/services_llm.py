from __future__ import annotations

import json
import urllib.error
import urllib.request
import urllib.parse
from datetime import datetime, timedelta

from django.conf import settings
from django.db.models import Q

from consultations.models import Consultation
from patients.models import DossierPatient, Patient
from rendez_vous.models import RendezVous


def reponse_ia(question: str, contexte: str = "", patient_id: int = None) -> str:
    """
    Réponse IA provider-aware avec accès aux données du projet et recherche web.

    Priorité actuelle:
    1) Anthropic Claude (si clé dispo) avec recherche web
    2) fallback local heuristique avec données réelles
    """
    api_key = getattr(settings, "ANTHROPIC_API_KEY", "")
    model = getattr(settings, "ANTHROPIC_MODEL", "claude-3-5-sonnet-latest")

    # Enrichir le contexte avec les données du projet
    contexte_enrichi = enrichir_contexte(question, contexte, patient_id)

    if api_key and api_key.strip():
        # Tenter d'abord une recherche web si la question le nécessite
        info_web = ""
        if est_question_medical(question):
            info_web = rechercher_information_medicale_web(question)
        
        prompt = (
            "Tu es WARMS, un assistant médical intelligent pour un cabinet dentaire.\n"
            "Tu as accès aux données réelles du cabinet et à des connaissances médicales actualisées.\n"
            "Réponds en français, de manière professionnelle, précise et utile.\n"
            "Pour les questions médicales, donne des informations basées sur les sources médicales fiables mais recommande toujours de consulter un professionnel.\n"
            "Pour les questions sur les rendez-vous, utilise les données réelles disponibles.\n"
            "N'invente pas de données médicales spécifiques si elles ne sont pas dans le contexte.\n"
            "Si tu utilises des informations web, cite tes sources de manière générale.\n\n"
            f"Contexte complet:\n{contexte_enrichi}\n\n"
            f"Information médicale pertinente:\n{info_web}\n\n"
            f"Question:\n{question}\n"
        )
        payload = {
            "model": model,
            "max_tokens": 1200,
            "messages": [{"role": "user", "content": prompt}],
        }
        req = urllib.request.Request(
            "https://api.anthropic.com/v1/messages",
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "x-api-key": api_key,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                body = json.loads(response.read().decode("utf-8"))
                content = body.get("content", [])
                if content and isinstance(content, list):
                    text = content[0].get("text", "").strip()
                    if text:
                        return text
        except (urllib.error.URLError, TimeoutError, ValueError, KeyError) as e:
            print(f"Erreur API Anthropic: {e}")
            pass

    # Fallback local avec données réelles
    return reponse_locale_ia(question, contexte_enrichi)


def est_question_medical(question: str) -> bool:
    """Détermine si la question nécessite une recherche médicale."""
    mots_cles_medicaux = [
        'symptôme', 'symptome', 'douleur', 'maladie', 'pathologie', 'traitement',
        'médicament', 'soin', 'thérapie', 'diagnostic', 'examen',
        'carie', 'abcès', 'gingivite', 'parodontite', 'extraction',
        'détartrage', 'obturation', 'couronne', 'bridge', 'implant',
        'saignement', 'gonflement', 'sensibilité', 'infection'
    ]
    question_lower = question.lower()
    return any(mot in question_lower for mot in mots_cles_medicaux)


def rechercher_information_medicale_web(question: str) -> str:
    """
    Simule une recherche web pour des informations médicales fiables.
    En production, ceci pourrait utiliser une vraie API de recherche web.
    """
    question_lower = question.lower()
    
    # Informations médicales dentaires de base
    info_medicales = {
        'douleur dent': {
            'causes': ['Carie profonde', 'Abcès dentaire', 'Fracture dentaire', 'Maladie des gencives', 'Pulpite'],
            'conseils': 'Prendre un antalgique (paracétamol/ibuprofène), éviter aliments chauds/froids, consulter rapidement un dentiste',
            'urgence': 'Douleur intense = urgence dentaire'
        },
        'carie': {
            'causes': ['Hygiène buccale insuffisante', 'Alimentation sucrée', 'Facteurs génétiques'],
            'traitement': 'Obturation si détectée tôt, dévitalisation si atteinte pulpe, extraction si trop avancée',
            'prevention': 'Brossage régulier, détartrage annuel, alimentation équilibrée'
        },
        'gingivite': {
            'symptomes': ['Gencives rouges et gonflées', 'Saignement au brossage', 'Mauvaise haleine'],
            'traitement': 'Détartrage professionnel, brossage adapté, bain de bouche antiseptique',
            'complications': 'Peut évoluer en parodontite si non traitée'
        },
        'abcès': {
            'symptomes': ['Douleur intense', 'Gonflement', 'Fièvre', 'Ganglion'],
            'traitement': 'Drainage + antibiotiques, traitement de canal ou extraction',
            'urgence': 'Nécessite une consultation en urgence'
        },
        'extraction dent': {
            'indications': ['Dent non restaurable', 'Infection sévère', 'Dent de sagesse'],
            'soins': 'Compresses froides, alimentation molle, éviter activité intense 24h',
            'cicatrisation': '7-10 jours, éviter tabac et alcool'
        }
    }
    
    # Rechercher l'information pertinente
    for terme, info in info_medicales.items():
        if terme in question_lower:
            resultat = f"INFORMATIONS MÉDICALES - {terme.upper()}:\n"
            resultat += f"Causes possibles: {', '.join(info['causes'])}\n"
            if 'conseils' in info:
                resultat += f"Conseils immédiats: {info['conseils']}\n"
            if 'traitement' in info:
                resultat += f"Traitement: {info['traitement']}\n"
            if 'prevention' in info:
                resultat += f"Prévention: {info['prevention']}\n"
            if 'complications' in info:
                resultat += f"Complications: {info['complications']}\n"
            if 'urgence' in info:
                resultat += f"URGENCE: {info['urgence']}\n"
            return resultat
    
    return "Aucune information médicale spécifique trouvée. Consultez un professionnel pour des conseils personnalisés."


def enrichir_contexte(question: str, contexte: str, patient_id: int = None) -> str:
    """Enrichit le contexte avec les données réelles du projet."""
    contexte_complet = contexte
    
    # Ajouter les informations générales du cabinet
    nb_patients = Patient.objects.count()
    nb_consultations_aujourdhui = Consultation.objects.filter(
        date__date=datetime.now().date()
    ).count()
    nb_rdv_semaine = RendezVous.objects.filter(
        debut__gte=datetime.now(),
        debut__lte=datetime.now() + timedelta(days=7)
    ).count()
    
    contexte_complet += f"\n\nSTATISTIQUES DU CABINET:\n"
    contexte_complet += f"- Patients totaux: {nb_patients}\n"
    contexte_complet += f"- Consultations aujourd'hui: {nb_consultations_aujourdhui}\n"
    contexte_complet += f"- Rendez-vous cette semaine: {nb_rdv_semaine}\n"
    
    # Si un patient est spécifié, ajouter ses données
    if patient_id:
        try:
            patient = Patient.objects.get(id=patient_id)
            dossier = DossierPatient.objects.filter(patient=patient).first()
            
            contexte_complet += f"\n\nPATIENT: {patient.prenom} {patient.nom}\n"
            contexte_complet += f"- Email: {patient.email or 'Non renseigné'}\n"
            contexte_complet += f"- Téléphone: {patient.telephone or 'Non renseigné'}\n"
            
            if dossier:
                contexte_complet += f"\nDOSSIER MÉDICAL:\n"
                contexte_complet += f"- Numéro dossier: {dossier.numero_dossier}\n"
                contexte_complet += f"- Antécédents: {dossier.antecedents or 'Aucun'}\n"
                contexte_complet += f"- Allergies: {dossier.allergies or 'Aucune'}\n"
                contexte_complet += f"- Notes médicales: {dossier.notes_medicales or 'Aucune'}\n"
                
                # Consultations récentes
                consultations_recentes = Consultation.objects.filter(
                    dossier=dossier
                ).order_by('-date')[:5]
                
                if consultations_recentes:
                    contexte_complet += f"\nCONSULTATIONS RÉCENTES:\n"
                    for consultation in consultations_recentes:
                        contexte_complet += f"- {consultation.date.strftime('%d/%m/%Y')}: {consultation.motif or 'Non spécifié'}\n"
                        if consultation.diagnostic:
                            contexte_complet += f"  Diagnostic: {consultation.diagnostic}\n"
                
                # Prochains rendez-vous
                prochains_rdv = RendezVous.objects.filter(
                    patient=patient,
                    debut__gte=datetime.now()
                ).order_by('debut')[:3]
                
                if prochains_rdv:
                    contexte_complet += f"\nPROCHAINS RENDEZ-VOUS:\n"
                    for rdv in prochains_rdv:
                        contexte_complet += f"- {rdv.debut.strftime('%d/%m/%Y %H:%M')}: {rdv.motif or 'Non spécifié'}\n"
                        
        except Patient.DoesNotExist:
            contexte_complet += f"\n\nPatient ID {patient_id} non trouvé."
    
    return contexte_complet


def reponse_locale_ia(question: str, contexte: str) -> str:
    """Réponse locale fallback avec traitement intelligent des questions."""
    q = question.lower()
    
    # Questions sur les pathologies et symptômes
    if any(mot in q for mot in ['symptôme', 'symptome', 'maladie', 'pathologie', 'douleur']):
        return reponse_symptomes(question)
    
    # Questions sur les rendez-vous
    if any(mot in q for mot in ['rendez-vous', 'rdv', 'appointment', 'consultation']):
        return reponse_rendez_vous(question, contexte)
    
    # Questions sur les traitements
    if any(mot in q for mot in ['traitement', 'médicament', 'soin', 'thérapie']):
        return reponse_traitements(question)
    
    # Questions générales sur le cabinet
    if any(mot in q for mot in ['cabinet', 'clinique', 'horaire', 'contact']):
        return reponse_cabinet(question, contexte)
    
    # Réponse par défaut
    return (
        "Je suis WARMS, votre assistant médical. Je peux vous aider avec:\n"
        "- Informations sur les symptômes et pathologies dentaires\n"
        "- Gestion de vos rendez-vous\n"
        "- Informations sur les traitements dentaires\n"
        "- Questions sur le fonctionnement du cabinet\n\n"
        "Pour toute urgence médicale, veuillez contacter directement le cabinet ou les services d'urgence.\n"
        f"Contexte disponible: {contexte[:200]}..."
    )


def reponse_symptomes(question: str) -> str:
    """Réponses sur les symptômes dentaires courants."""
    q = question.lower()
    
    if 'douleur' in q and 'dent' in q:
        return (
            "La douleur dentaire peut avoir plusieurs causes:\n"
            "- Carie profonde atteignant la pulpe\n"
            "- Abcès dentaire\n"
            "- Fracture dentaire\n"
            "- Maladie des gencives\n\n"
            "Conseils immédiats:\n"
            "- Prenez un antalgique (paracétamol/ibuprofène)\n"
            "- Évitez les aliments trop chauds/froids\n"
            "- Contactez rapidement votre dentiste\n\n"
            "Cette douleur nécessite une consultation rapide pour éviter les complications."
        )
    
    if 'saignement' in q and 'gencive' in q:
        return (
            "Le saignement des gencives peut indiquer:\n"
            "- Gingivite (inflammation des gencives)\n"
            "- Parodontite (infection plus profonde)\n"
            "- Brossage trop agressif\n\n"
            "Conseils:\n"
            "- Brossage doux avec brossettes interdentaires\n"
            "- Bain de bouche antiseptique\n"
            "- Consultation pour diagnostic et détartrage\n\n"
            "Ne négligez pas les saignements répétés."
        )
    
    return (
        "Les symptômes dentaires nécessitent toujours un diagnostic professionnel. "
        "Les causes les plus fréquentes sont les caries, infections, maladies des gencives, "
        "et traumatismes. Consultez votre dentiste pour un examen complet."
    )


def reponse_rendez_vous(question: str, contexte: str) -> str:
    """Réponses sur les rendez-vous avec données réelles."""
    q = question.lower()
    
    if 'prochain' in q or 'suivant' in q:
        # Extraire les prochains RDV du contexte
        if 'PROCHAINS RENDEZ-VOUS:' in contexte:
            debut = contexte.find('PROCHAINS RENDEZ-VOUS:')
            section = contexte[debut:debut+500]
            return f"Vos prochains rendez-vous:\n{section}"
        
        return "Je n'ai pas trouvé de rendez-vous à venir dans votre dossier. Contactez le cabinet pour prendre rendez-vous."
    
    if 'annuler' in q or 'reporter' in q:
        return (
            "Pour annuler ou reporter un rendez-vous:\n"
            "- Contactez le cabinet au moins 24h à l'avance\n"
            "- Téléphone: [Numéro du cabinet]\n"
            "- Email: [Email du cabinet]\n\n"
            "Les annulations de dernière minute peuvent entraîner des frais."
        )
    
    return (
        "Pour la gestion des rendez-vous, contactez directement le cabinet:\n"
        "- Prise de RDV: Téléphone ou en ligne\n"
        "- Urgences: Appeler directement le cabinet\n"
        "- Annulations: 24h à l'avance minimum"
    )


def reponse_traitements(question: str) -> str:
    """Réponses sur les traitements dentaires."""
    q = question.lower()
    
    if 'détartrage' in q:
        return (
            "Le détartrage est un soin essentiel:\n"
            "- Fréquence recommandée: 1-2 fois par an\n"
            "- Élimine plaque et tartre\n"
            "- Prévient maladies des gencives\n"
            "- Durée: 30-45 minutes\n"
            "- Indolore avec anesthésie si nécessaire\n\n"
            "Le détartrage régulier prévient les parodontites et caries."
        )
    
    if 'carie' in q:
        return (
            "Traitement des caries:\n"
            "- Dépistage: radiographie et examen clinique\n"
            "- Soins: obturation (plombage) ou couronne\n"
            "- Matériaux: composite, amalgame, céramique\n"
            "- Anesthésie locale pour le confort\n"
            "- Prévention: hygiène et visites régulières\n\n"
            "Plus une carie est traitée tôt, plus le soin est simple."
        )
    
    return (
        "Les traitements dentaires courants incluent:\n"
        "- Détratrage et surfaçage prophylactique\n"
        "- Obturations (plombages)\n"
        "- Traitements de canal (dévitalisation)\n"
        "- Couronnes et bridges\n"
        "- Implants dentaires\n"
        "- Orthodontie\n\n"
        "Chaque traitement est personnalisé selon votre situation."
    )


def reponse_cabinet(question: str, contexte: str) -> str:
    """Réponses sur le fonctionnement du cabinet."""
    q = question.lower()
    
    if 'horaire' in q or 'ouvert' in q:
        return (
            "Horaires du cabinet:\n"
            "- Lundi: 8h-12h / 14h-18h\n"
            "- Mardi: 8h-12h / 14h-18h\n"
            "- Mercredi: 8h-12h / 14h-18h\n"
            "- Jeudi: 8h-12h / 14h-18h\n"
            "- Vendredi: 8h-12h / 14h-17h\n"
            "- Samedi/Dimanche: Fermé\n\n"
            "Urgences: appelez le cabinet, message indiquera le numéro d'astre."
        )
    
    if 'contact' in q or 'téléphone' in q:
        return (
            "Contact du cabinet:\n"
            "- Téléphone: [Numéro à configurer]\n"
            "- Email: [Email à configurer]\n"
            "- Adresse: [Adresse complète]\n\n"
            "Pour les urgences en dehors des heures d'ouverture, suivez les instructions sur le répondeur."
        )
    
    return (
        "Le cabinet dentaire WARMS offre:\n"
        "- Consultations et diagnostics\n"
            "- Soins conservateurs et prothèses\n"
            "- Orthodontie et implantologie\n"
            "- Urgences dentaires\n"
            "- Prévention et éducation\n\n"
            "Contactez-nous pour toute question ou rendez-vous."
    )


#EbaJioloLewis
