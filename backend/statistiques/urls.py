from django.urls import path

from .views import absentéisme, parcours_patient, vue_generale

urlpatterns = [
    path("statistiques/vue-generale/", vue_generale, name="stats-vue-generale"),
    path("statistiques/absenteisme/", absentéisme, name="stats-absenteisme"),
    path("statistiques/parcours-patient/", parcours_patient, name="stats-parcours-patient"),
]


#EbaJioloLewis
