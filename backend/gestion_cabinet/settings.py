"""
Configuration Django pour Warm's (gestion d'un cabinet dentaire).

Objectif: une base claire et robuste pour:
- une API (mobile + web administration)
- des rôles (chirurgien-dentiste, secrétaire, infirmière, patient)
- PostgreSQL en environnement réel (SQLite possible en dev si besoin)
"""

import os
from pathlib import Path

import environ

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent


# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/5.2/howto/deployment/checklist/

env = environ.Env(
    DJANGO_DEBUG=(bool, True),
)
environ.Env.read_env(BASE_DIR / ".env")

# Sécurité: ne pas versionner la vraie clé en prod (mettre dans .env).
SECRET_KEY = env("DJANGO_SECRET_KEY", default="dev-only-change-me")

DEBUG = env("DJANGO_DEBUG")

ALLOWED_HOSTS = env.list("DJANGO_ALLOWED_HOSTS", default=["127.0.0.1", "localhost"])

# Configuration des URLs
APPEND_SLASH = False

# Application definition

INSTALLED_APPS = [
    "daphne",
    "channels",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # API
    "corsheaders",
    "rest_framework",
    "rest_framework_simplejwt",
    # Apps métier Warm's
    "personnel",
    "patients",
    "rendez_vous",
    "consultations",
    "prescriptions",
    "messagerie",
    "qr_codes",
    "journaux",
    "avis",
    "statistiques",
    "assistant_ia",
    "ocr",
    "ia_avancee",
    "ia_shared",
    "comptes_rendus",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "personnel.middleware.ActivitePresenceMiddleware",
]

ROOT_URLCONF = "gestion_cabinet.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "gestion_cabinet.wsgi.application"


# Base de données:
# En local/dev, on veut éviter l'ambiguïté "ça marche mais sur SQLite".
# Si `DATABASE_URL` n'est pas défini, on utilise SQLite uniquement en mode DEBUG
# et on affiche un avertissement clair.
default_db_url = f"sqlite:///{(BASE_DIR / 'db.sqlite3').as_posix()}"
DATABASE_URL = env("DATABASE_URL", default="")
if not DATABASE_URL:
    if env("DJANGO_DEBUG", default=True):
        import warnings

        warnings.warn(
            "DATABASE_URL n'est pas défini: utilisation de SQLite (backend/db.sqlite3). "
            "Pour utiliser PostgreSQL, crée `backend/.env` et définis DATABASE_URL.",
            RuntimeWarning,
        )
        DATABASES = {"default": env.db("DATABASE_URL", default=default_db_url)}
    else:
        raise RuntimeError("DATABASE_URL requis en production (PostgreSQL).")
else:
    # Parser via django-environ, en s'appuyant sur la variable d'environnement.
    # (On évite une API non standard selon les versions.)
    import os

    os.environ["DATABASE_URL"] = DATABASE_URL
    DATABASES = {"default": env.db("DATABASE_URL")}


# Password validation
# https://docs.djangoproject.com/en/5.2/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",
    },
]


# Internationalization
# https://docs.djangoproject.com/en/5.2/topics/i18n/

LANGUAGE_CODE = "fr-fr"

TIME_ZONE = "Africa/Abidjan"

USE_I18N = True

USE_TZ = True


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/5.2/howto/static-files/

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

# Médias (photos de dossier, pièces jointes scannées, etc.)
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

# WhiteNoise: sert STATIC_ROOT (après `collectstatic`) directement depuis
# Django, sans dépendre d'un Nginx déjà en place pour le premier hébergement.
STORAGES = {
    "default": {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
    },
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
    },
}

# Paramètres DRF (seront complétés lors de la mise en place de l'auth)
REST_FRAMEWORK = {
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ],
    # Anti-abus de base (force brute login, coûts API Google côté
    # recherche IA). Valeurs larges pour ne pas gêner l'usage normal du
    # cabinet ; à resserrer si des abus réels sont constatés.
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {
        "anon": "60/min",
        "user": "300/min",
    },
}

# Configuration JWT
from datetime import timedelta

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=60),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    "ROTATE_REFRESH_TOKENS": True,
    # BLACKLIST_AFTER_ROTATION nécessite "rest_framework_simplejwt.token_blacklist"
    # dans INSTALLED_APPS + migration. Désactivé pour l'instant (SimpleJWT silencieux
    # si l'app n'est pas installée mais cela laisse les anciens refresh tokens valides).
    # Pour activer : ajouter l'app à INSTALLED_APPS et lancer manage.py migrate.
    "BLACKLIST_AFTER_ROTATION": False,
    "UPDATE_LAST_LOGIN": True,
    "ALGORITHM": "HS256",
    "SIGNING_KEY": SECRET_KEY,
    "VERIFYING_KEY": None,
    "AUDIENCE": None,
    "ISSUER": None,
    "AUTH_HEADER_TYPES": ("Bearer",),
    "AUTH_HEADER_NAME": "HTTP_AUTHORIZATION",
    "USER_ID_FIELD": "id",
    "USER_ID_CLAIM": "user_id",
    "USER_AUTHENTICATION_RULE": "rest_framework_simplejwt.authentication.default_user_authentication_rule",
    "AUTH_TOKEN_CLASSES": ("rest_framework_simplejwt.tokens.AccessToken",),
    "TOKEN_TYPE_CLAIM": "token_type",
    "JTI_CLAIM": "jti",
    "SLIDING_TOKEN_REFRESH_EXP_CLAIM": "refresh_exp",
    "SLIDING_TOKEN_LIFETIME": timedelta(minutes=5),
    "SLIDING_TOKEN_REFRESH_LIFETIME": timedelta(days=1),
}

# CORS: autorise le front web-admin en local
CORS_ALLOWED_ORIGINS = env.list(
    "CORS_ALLOWED_ORIGINS",
    default=[
        "http://localhost:4200",
        "http://127.0.0.1:4200",
        "http://localhost:51155",
        "http://127.0.0.1:51155",
    ],
)
# Autorise les ports dynamiques (Angular/Flutter web en dev local).
CORS_ALLOWED_ORIGIN_REGEXES = [
    r"^http://localhost:\d+$",
    r"^http://127\.0\.0\.1:\d+$",
    r"^http://192\.168\.\d+\.\d+:\d+$",  # réseau LAN (device physique)
    r"^http://10\.\d+\.\d+\.\d+:\d+$",   # réseau LAN alternatif
]
# En mode DEBUG, accepte toutes les origines (Flutter web + builds locaux).
if DEBUG:
    CORS_ALLOW_ALL_ORIGINS = True

# Utilisateur applicatif (avec rôles Warm's)
AUTH_USER_MODEL = "personnel.Utilisateur"

# IA provider (Anthropic Claude prioritaire)
ANTHROPIC_API_KEY = env("ANTHROPIC_API_KEY", default="")
ANTHROPIC_MODEL = env("ANTHROPIC_MODEL", default="claude-3-5-sonnet-latest")

# Recherche web (Google Custom Search) pour l'écran "Recherche IA"
GOOGLE_API_KEY = env("GOOGLE_API_KEY", default="")
GOOGLE_CSE_ID = env("GOOGLE_CSE_ID", default="")

# Notifications push mobiles (Firebase Cloud Messaging). Chemin vers le
# fichier JSON de clé de compte de service Firebase (Project Settings >
# Service accounts > Generate new private key). Vide = push désactivé
# silencieusement, voir messagerie/services_push.py.
FIREBASE_CREDENTIALS_PATH = env("FIREBASE_CREDENTIALS_PATH", default="")

# OCR (carnets/ordonnances scannés) : chemin du binaire Tesseract.
# Sur Windows, l'installeur (winget/UB-Mannheim) ne place pas toujours le
# binaire sur le PATH des processus déjà démarrés — on pointe directement
# vers l'emplacement par défaut plutôt que de dépendre du PATH système.
TESSERACT_PATH = env(
    "TESSERACT_PATH",
    default=r"C:\Program Files\Tesseract-OCR\tesseract.exe" if os.name == "nt" else "",
)
# Dossier des modèles de langue (.traineddata). Le paquet Windows
# (winget/UB-Mannheim en mode silencieux) n'installe que l'anglais, et son
# dossier "tessdata" système nécessite des droits administrateur pour y
# ajouter le français — on utilise donc un dossier local au projet à la
# place (voir backend/.tessdata/, à peupler via le README OCR).
TESSDATA_PREFIX = env("TESSDATA_PREFIX", default=str(BASE_DIR / ".tessdata"))
# Posée ici (au chargement des settings, avant tout code applicatif) plutôt
# que dans chacun des modules OCR : pytesseract/tesseract.exe lisent cette
# variable d'environnement directement, peu importe quel module Python
# l'importe en premier.
if TESSDATA_PREFIX:
    os.environ["TESSDATA_PREFIX"] = TESSDATA_PREFIX

# Default primary key field type
# https://docs.djangoproject.com/en/5.2/ref/settings/#default-auto-field

# Channels configuration (WebSocket temps réel pour la messagerie)
ASGI_APPLICATION = 'gestion_cabinet.asgi.application'

# Couche en mémoire locale par défaut : aucune dépendance externe, mais ne
# fonctionne correctement qu'avec un seul processus serveur (dev, ou un seul
# worker en prod) — un message envoyé depuis un worker n'atteint pas un
# client connecté à un autre worker. Dès qu'un REDIS_URL est fourni (prod
# avec plusieurs workers Daphne), on bascule automatiquement sur Redis.
REDIS_URL = env("REDIS_URL", default="")
if REDIS_URL:
    CHANNEL_LAYERS = {
        'default': {
            'BACKEND': 'channels_redis.core.RedisChannelLayer',
            'CONFIG': {
                'hosts': [REDIS_URL],
            },
        },
    }
else:
    CHANNEL_LAYERS = {
        'default': {
            'BACKEND': 'channels.layers.InMemoryChannelLayer',
        },
    }

# Email (réinitialisation de mot de passe, etc.). En dev (DEBUG=True) sans
# config explicite, on affiche les emails dans la console au lieu d'essayer
# une vraie connexion SMTP (qui échouerait silencieusement). En prod, fournir
# EMAIL_HOST/EMAIL_HOST_USER/EMAIL_HOST_PASSWORD via .env.
EMAIL_BACKEND = env(
    "EMAIL_BACKEND",
    default="django.core.mail.backends.console.EmailBackend" if DEBUG
    else "django.core.mail.backends.smtp.EmailBackend",
)
EMAIL_HOST = env("EMAIL_HOST", default="")
EMAIL_PORT = env.int("EMAIL_PORT", default=587)
EMAIL_USE_TLS = env.bool("EMAIL_USE_TLS", default=True)
EMAIL_HOST_USER = env("EMAIL_HOST_USER", default="")
EMAIL_HOST_PASSWORD = env("EMAIL_HOST_PASSWORD", default="")
DEFAULT_FROM_EMAIL = env("DEFAULT_FROM_EMAIL", default="no-reply@wams-dentaire.com")

# Identité utilisée dans les emails (templates HTML) et lien "Se connecter".
SITE_NAME = env("SITE_NAME", default="Warm's")
FRONTEND_URL = env("FRONTEND_URL", default="http://localhost:4200")

# Durcissement HTTPS/cookies en production uniquement (laissé désactivé en
# dev pour ne pas casser les tests en http://127.0.0.1 sans certificat).
if not DEBUG:
    SECURE_SSL_REDIRECT = env.bool("SECURE_SSL_REDIRECT", default=True)
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = env.int("SECURE_HSTS_SECONDS", default=60 * 60 * 24 * 7)
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
    CSRF_TRUSTED_ORIGINS = env.list("CSRF_TRUSTED_ORIGINS", default=[])

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
