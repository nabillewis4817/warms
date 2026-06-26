"""
Configuration Django pour Warm's (gestion d'un cabinet dentaire).

Objectif: une base claire et robuste pour:
- une API (mobile + web administration)
- des rôles (chirurgien-dentiste, secrétaire, infirmière, patient)
- PostgreSQL en environnement réel (SQLite possible en dev si besoin)
"""

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
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
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
        "DIRS": [],
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

# Médias (photos de dossier, pièces jointes scannées, etc.)
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

# Paramètres DRF (seront complétés lors de la mise en place de l'auth)
REST_FRAMEWORK = {
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ],
}

# Configuration JWT
from datetime import timedelta

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=60),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
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
]

# Utilisateur applicatif (avec rôles Warm's)
AUTH_USER_MODEL = "personnel.Utilisateur"

# IA provider (Anthropic Claude prioritaire)
ANTHROPIC_API_KEY = env("ANTHROPIC_API_KEY", default="")
ANTHROPIC_MODEL = env("ANTHROPIC_MODEL", default="claude-3-5-sonnet-latest")

# Recherche web (Google Custom Search) pour l'écran "Recherche IA"
GOOGLE_API_KEY = env("GOOGLE_API_KEY", default="")
GOOGLE_CSE_ID = env("GOOGLE_CSE_ID", default="")

# Default primary key field type
# https://docs.djangoproject.com/en/5.2/ref/settings/#default-auto-field

# Channels configuration (WebSocket temps réel pour la messagerie)
ASGI_APPLICATION = 'gestion_cabinet.asgi.application'

# Couche en mémoire locale : aucune dépendance externe (pas de Redis requis).
# Suffisant pour un seul processus serveur (dev, ou un seul worker en prod).
# Pour scaler sur plusieurs workers/processus, remplacer par channels_redis
# une fois un serveur Redis disponible.
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels.layers.InMemoryChannelLayer',
    },
}

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
