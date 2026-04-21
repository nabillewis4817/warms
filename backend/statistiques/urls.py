from django.urls import path

from .views import absentéisme, vue_generale

urlpatterns = [
    path("statistiques/vue-generale/", vue_generale, name="stats-vue-generale"),
    path("statistiques/absenteisme/", absentéisme, name="stats-absenteisme"),
]


#EbaJioloLewis
