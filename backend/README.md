# Warm's — Backend (Django / PostgreSQL)

Backend API de l'application Warm's (cabinet dentaire).

## Prérequis

- Python 3.11+
- PostgreSQL (base nommée **`warms`**)

## Installation

Depuis la racine du repo:

```bash
python -m pip install -r backend/requirements.txt
```

## Configuration (.env)

1) Copier `backend/.env.example` en `backend/.env`
2) Adapter `DATABASE_URL` si besoin

Exemple PostgreSQL:

```text
DATABASE_URL=postgres://postgres:MacKenzie@localhost:5432/warms
DJANGO_DEBUG=True
DJANGO_SECRET_KEY=dev-only-change-me
DJANGO_ALLOWED_HOSTS=127.0.0.1,localhost
```

## Migrations

```bash
python backend/manage.py makemigrations
python backend/manage.py migrate
```

## Lancer le serveur

```bash
python backend/manage.py runserver 8000
```

## Endpoints (API v1)

- **Healthcheck**: `GET /api/v1/health/`
- **Auth JWT**:
  - `POST /api/v1/personnel/auth/token/` (username/password → access/refresh)
  - `POST /api/v1/personnel/auth/token/refresh/`
  - `GET /api/v1/personnel/me/` (profil)
- **Patients / Dossiers**:
  - CRUD `patients`: `/api/v1/patients/`
  - CRUD `dossiers`: `/api/v1/dossiers/`
  - CRUD `pages` carnet: `/api/v1/pages/`
  - Upload pièces jointes: `POST /api/v1/pieces-jointes/` (multipart)
- **QR carnet**:
  - CRUD: `/api/v1/qr/carnets/`
  - Vérification scan (public): `POST /api/v1/qr/carnets/verifier/`
- **Rendez-vous**:
  - CRUD: `/api/v1/rendez-vous/`
  - Actions:
    - `POST /api/v1/rendez-vous/{id}/annuler/`
    - `POST /api/v1/rendez-vous/{id}/marquer_absent/`
    - `POST /api/v1/rendez-vous/{id}/reporter/`
- **Consultations / Suivi clinique**:
  - CRUD consultations: `/api/v1/consultations/`
  - CRUD actes réalisés: `/api/v1/actes/`
  - Schéma dentaire (1 par consultation): `/api/v1/schemas-dentaires/`
  - Photos cliniques (upload multipart): `/api/v1/photos-cliniques/`
- **Prescriptions / Ordonnances**:
  - CRUD prescriptions: `/api/v1/prescriptions/`
  - CRUD lignes: `/api/v1/lignes-prescription/`
  - Historique patient: `GET /api/v1/prescriptions/patient/{patient_id}/historique/`
  - PDF ordonnance: `GET /api/v1/prescriptions/{id}/pdf/`
- **Personnel / Rôles**:
  - CRUD utilisateurs (gestion cabinet): `/api/v1/personnel/utilisateurs/`
  - Mon profil: `GET /api/v1/personnel/me/`
  - Mes préférences: `PATCH /api/v1/personnel/me/preferences/`
  - Actions:
    - `POST /api/v1/personnel/utilisateurs/{id}/desactiver/`
    - `POST /api/v1/personnel/utilisateurs/{id}/changer-mot-de-passe/`
- **Affectations**:
  - Affecter infirmière à un patient: `POST /api/v1/patients/{id}/affecter_infirmiere/` (`infirmiere_id`)
- **Journaux (logs)**:
  - Lecture: `/api/v1/journaux/`
- **Messagerie / Communication**:
  - Conversations CRUD: `/api/v1/conversations/`
  - Ajouter participant: `POST /api/v1/conversations/{id}/ajouter_participant/`
  - Lister messages: `GET /api/v1/conversations/{id}/messages/`
  - Envoyer message: `POST /api/v1/conversations/{id}/envoyer_message/`
  - Participants (liste): `/api/v1/participants-conversation/`
  - Notifications utilisateur: `/api/v1/notifications/`
  - Marquer notif lue: `POST /api/v1/notifications/{id}/marquer_lu/`
- **Recherche intelligente**:
  - Recherche globale multi-modules: `GET /api/v1/recherche/globale/?q=...`
  - Suggestions pendant la saisie: `GET /api/v1/recherche/suggestions/?q=...`
  - Filtres combinables (sur `recherche/globale`):
    - `date_debut` (ISO datetime)
    - `date_fin` (ISO datetime)
    - `statut` (rendez-vous)
    - `praticien_id`
    - `type_acte`
- **Fonctionnalités innovantes (IA/OCR/offline)**:
  - OCR carnet (upload + texte extrait): `/api/v1/ia/ocr-imports/`
  - Assistant IA contextuel dossier: `/api/v1/ia/messages/`
  - Recommandations automatiques:
    - lecture: `/api/v1/ia/recommandations/`
    - génération: `POST /api/v1/ia/recommandations/generer/`
  - Compte-rendu consultation:
    - lecture: `/api/v1/ia/comptes-rendus/`
    - génération: `POST /api/v1/ia/comptes-rendus/generer/` (`consultation_id`)
  - Sync mode hors-ligne: `GET /api/v1/offline/sync/`
  - Provider IA configurable:
    - priorité: **Anthropic Claude** via `ANTHROPIC_API_KEY`
    - fallback local si la clé n'est pas fournie
- **Tableau de bord & statistiques**:
  - Vue générale: `GET /api/v1/statistiques/vue-generale/`
  - Absentéisme: `GET /api/v1/statistiques/absenteisme/`

## Exemple rapide (PowerShell)

Récupérer un token:

```powershell
$body = @{ username = "admin"; password = "ton_mdp" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8000/api/v1/personnel/auth/token/" -ContentType "application/json" -Body $body
```

Appeler `me/`:

```powershell
$token = "<ACCESS_TOKEN>"
Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:8000/api/v1/personnel/me/" -Headers @{ Authorization = "Bearer $token" }
```
