from django.apps import AppConfig


class IaSharedConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'ia_shared'
    
    def ready(self):
        """Initialiser les services IA partagés"""
        print("Module IA partage WARMS initialise")
        print("Support Web + Mobile")
        print("Services IA unifies")
