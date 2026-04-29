from django.urls import path
from . import views

urlpatterns = [
    path('recherche-web/', views.recherche_web, name='ia_recherche_web'),
    path('recherche-medicale/', views.recherche_medicale, name='ia_recherche_medicale'),
    path('generer-reponse/', views.generer_reponse, name='ia_generer_reponse'),
    path('analyser-symptomes/', views.analyser_symptomes, name='ia_analyser_symptomes'),
    path('suggerer-traitements/', views.suggerer_traitements, name='ia_suggerer_traitements'),
    path('verifier-interactions/', views.verifier_interactions, name='ia_verifier_interactions'),
    path('chat-medical/', views.chat_medical, name='ia_chat_medical'),
    path('configurer/', views.configurer_service, name='ia_configurer'),
]
