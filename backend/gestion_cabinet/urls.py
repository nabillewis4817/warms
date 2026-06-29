"""
URL configuration for gestion_cabinet project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""

from django.conf import settings
from django.contrib import admin
from django.urls import include, path, re_path
from django.views.static import serve as serve_static

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/v1/", include("gestion_cabinet.urls_api_v1")),
]

# Sert /media/ (photos patients, PDF d'ordonnances) que DEBUG soit True ou
# False. `django.conf.urls.static.static()` ne sert ces fichiers qu'en
# DEBUG=True ; à l'échelle de ce projet (un seul petit serveur, pas encore
# de Nginx/CDN devant l'API), on garde Django responsable de ce service
# plutôt que de casser le téléchargement des ordonnances en production.
# À migrer vers Nginx/stockage objet si le trafic média devient important.
urlpatterns += [
    re_path(r"^media/(?P<path>.*)$", serve_static, {"document_root": settings.MEDIA_ROOT}),
]
