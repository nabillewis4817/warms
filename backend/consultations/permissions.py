from rest_framework.permissions import BasePermission

from personnel.models import Utilisateur


class EstPraticien(BasePermission):
    """
    Permission pour vérifier si l'utilisateur est un praticien (chirurgien-dentiste)
    """
    
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        
        try:
            utilisateur = Utilisateur.objects.get(user=request.user)
            return utilisateur.role in ['chirurgien_dentiste', 'medecin', 'infirmiere']
        except Utilisateur.DoesNotExist:
            return False


class PeutGererAppels(BasePermission):
    """
    Permission pour gérer les appels (praticiens et personnel autorisé)
    """
    
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        
        try:
            utilisateur = Utilisateur.objects.get(user=request.user)
            return utilisateur.role in [
                'chirurgien_dentiste', 
                'medecin', 
                'infirmiere',
                'assistant',
                'secretaire'
            ]
        except Utilisateur.DoesNotExist:
            return False


class PeutVoirTauxAbsenteisme(BasePermission):
    """
    Permission pour voir les taux d'absentéisme (personnel autorisé)
    """
    
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        
        try:
            utilisateur = Utilisateur.objects.get(user=request.user)
            return utilisateur.role in [
                'chirurgien_dentiste', 
                'medecin', 
                'infirmiere',
                'assistant',
                'secretaire',
                'administrateur'
            ]
        except Utilisateur.DoesNotExist:
            return False


class EstPatientConcerne(BasePermission):
    """
    Permission pour vérifier si le patient peut voir ses propres consultations
    """
    
    def has_object_permission(self, request, view, obj):
        if not request.user or not request.user.is_authenticated:
            return False
        
        try:
            utilisateur = Utilisateur.objects.get(user=request.user)
            
            # Les praticiens peuvent voir toutes les consultations
            if utilisateur.role in ['chirurgien_dentiste', 'medecin', 'infirmiere']:
                return True
            
            # Les patients ne peuvent voir que leurs propres consultations
            if utilisateur.role == 'patient':
                return hasattr(obj, 'patient') and obj.patient.user == request.user
            
            return False
        except Utilisateur.DoesNotExist:
            return False


class PeutModifierConsultation(BasePermission):
    """
    Permission pour modifier une consultation (praticiens uniquement)
    """
    
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        
        # Seuls les praticiens peuvent modifier les consultations
        if request.method in ['POST', 'PUT', 'PATCH', 'DELETE']:
            try:
                utilisateur = Utilisateur.objects.get(user=request.user)
                return utilisateur.role in ['chirurgien_dentiste', 'medecin']
            except Utilisateur.DoesNotExist:
                return False
        
        # Pour les requêtes GET, tous les utilisateurs authentifiés peuvent voir
        return True
    
    def has_object_permission(self, request, view, obj):
        if not request.user or not request.user.is_authenticated:
            return False
        
        try:
            utilisateur = Utilisateur.objects.get(user=request.user)
            
            # Les praticiens peuvent modifier toutes les consultations
            if utilisateur.role in ['chirurgien_dentiste', 'medecin']:
                return True
            
            # Les patients peuvent voir leurs consultations mais pas les modifier
            if request.method in ['GET', 'HEAD', 'OPTIONS']:
                if utilisateur.role == 'patient' and hasattr(obj, 'patient'):
                    return obj.patient.user == request.user
            
            return False
        except Utilisateur.DoesNotExist:
            return False


class PeutFaireAppel(BasePermission):
    """
    Permission pour faire l'appel (personnel autorisé)
    """
    
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        
        try:
            utilisateur = Utilisateur.objects.get(user=request.user)
            return utilisateur.role in [
                'chirurgien_dentiste', 
                'medecin', 
                'infirmiere',
                'assistant',
                'secretaire'
            ]
        except Utilisateur.DoesNotExist:
            return False


#EbaJioloLewis
