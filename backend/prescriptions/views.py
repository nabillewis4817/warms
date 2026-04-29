import io

from django.http import FileResponse
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from patients.models import Patient
from .models import LignePrescription, Prescription
from .serializers import (
    LignePrescriptionSerializer,
    PrescriptionCreateSerializer,
    PrescriptionSerializer,
)


class PrescriptionViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    queryset = Prescription.objects.select_related(
        "patient", "dossier", "consultation", "praticien"
    ).prefetch_related("lignes")

    def get_serializer_class(self):
        if self.action == "create":
            return PrescriptionCreateSerializer
        return PrescriptionSerializer

    def get_permissions(self):
        """
        Définir les permissions en fonction de l'action
        """
        if self.action == 'me':
            # L'action 'me' est accessible par tout utilisateur authentifié (patients)
            self.permission_classes = [IsAuthenticated]
        return super().get_permissions()

    @action(detail=False, methods=["get"], url_path=r"patient/(?P<patient_id>\d+)/historique")
    def historique_patient(self, request, patient_id=None):
        qs = self.get_queryset().filter(patient_id=patient_id)
        page = self.paginate_queryset(qs)
        if page is not None:
            serializer = PrescriptionSerializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = PrescriptionSerializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=["get"], url_path="me")
    def me(self, request):
        try:
            # Vérifier l'authentification
            if not request.user.is_authenticated:
                return Response({"detail": "Utilisateur non authentifié."}, status=401)
            
            # Vérifier si l'utilisateur est un patient ou superutilisateur
            user_role = getattr(request.user, 'role', None)
            if not request.user.is_superuser and (not user_role or user_role.lower() not in ['patient', 'PATIENT']):
                return Response({"detail": "L'utilisateur n'est pas un patient."}, status=403)
            
            # Rechercher le patient lié à cet utilisateur
            patient = Patient.objects.filter(user=request.user).first()
            if not patient:
                return Response({
                    "detail": "Profil patient introuvable.",
                    "user_id": request.user.id,
                    "username": request.user.username,
                    "debug_role": user_role
                }, status=404)
            
            # Récupérer les prescriptions du patient
            qs = self.get_queryset().filter(patient=patient)
            serializer = PrescriptionSerializer(qs, many=True)
            data = serializer.data
            
            # Ajouter les URLs PDF pour chaque prescription
            for item in data:
                try:
                    item["pdf_url"] = f"/api/v1/prescriptions/{item['id']}/pdf/"
                except KeyError:
                    item["pdf_url"] = None
            
            return Response(data)
            
        except Patient.DoesNotExist:
            return Response({
                "detail": "Profil patient introuvable.",
                "user_id": getattr(request.user, 'id', None),
                "debug_role": getattr(request.user, 'role', None)
            }, status=404)
        except Exception as e:
            return Response({
                "detail": "Erreur lors de la récupération des prescriptions",
                "error": str(e),
                "debug_info": {
                    "user_id": getattr(request.user, 'id', None),
                    "username": getattr(request.user, 'username', None),
                    "is_authenticated": getattr(request.user, 'is_authenticated', False),
                    "role": getattr(request.user, 'role', None)
                }
            }, status=500)

    @action(detail=True, methods=["get"])
    def pdf(self, request, pk=None):
        """
        Génère une ordonnance PDF simple (A4).
        """
        prescription = self.get_object()
        buffer = io.BytesIO()

        c = canvas.Canvas(buffer, pagesize=A4)
        width, height = A4

        y = height - 60
        c.setFont("Helvetica-Bold", 16)
        c.drawString(50, y, "ORDONNANCE")

        y -= 30
        c.setFont("Helvetica", 11)
        patient = prescription.patient
        c.drawString(50, y, f"Patient : {patient.prenom} {patient.nom}")

        y -= 18
        c.drawString(50, y, f"Date : {prescription.cree_le:%d/%m/%Y}")

        if prescription.titre:
            y -= 18
            c.drawString(50, y, f"Titre : {prescription.titre}")

        y -= 28
        c.setFont("Helvetica-Bold", 12)
        c.drawString(50, y, "Traitement :")

        y -= 18
        c.setFont("Helvetica", 11)
        for idx, ligne in enumerate(prescription.lignes.all(), start=1):
            texte = f"{idx}. {ligne.medicament}"
            if ligne.posologie:
                texte += f" — {ligne.posologie}"
            if ligne.duree:
                texte += f" — Durée: {ligne.duree}"
            if ligne.remarques:
                texte += f" — {ligne.remarques}"
            c.drawString(60, y, texte[:120])
            y -= 16
            if y < 80:
                c.showPage()
                y = height - 60
                c.setFont("Helvetica", 11)

        if prescription.note_praticien:
            y -= 10
            c.setFont("Helvetica-Bold", 12)
            c.drawString(50, y, "Notes :")
            y -= 18
            c.setFont("Helvetica", 11)
            for line in prescription.note_praticien.splitlines():
                c.drawString(60, y, line[:120])
                y -= 16
                if y < 80:
                    c.showPage()
                    y = height - 60
                    c.setFont("Helvetica", 11)

        y = 60
        c.setFont("Helvetica-Oblique", 9)
        c.drawString(50, y, "#EbaJioloLewis")

        c.showPage()
        c.save()

        buffer.seek(0)
        filename = f"ordonnance_{prescription.id}.pdf"
        return FileResponse(buffer, as_attachment=False, filename=filename)


class LignePrescriptionViewSet(viewsets.ModelViewSet):
    queryset = LignePrescription.objects.select_related("prescription").all()
    serializer_class = LignePrescriptionSerializer


#EbaJioloLewis
