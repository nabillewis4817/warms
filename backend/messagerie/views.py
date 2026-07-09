from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from django.db.models import Count, Q

from journaux.utils import journaliser
from patients.models import Patient

from .models import Conversation, Message, NotificationInterne, ParticipantConversation, Rappel
from .serializers import (
    ConversationSerializer,
    MessageSerializer,
    NotificationInterneSerializer,
    ParticipantConversationSerializer,
    RappelSerializer,
)


class ConversationViewSet(viewsets.ModelViewSet):
    queryset = Conversation.objects.select_related("patient").prefetch_related("participants").all()
    serializer_class = ConversationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        base = Conversation.objects.select_related("patient").prefetch_related("participants")
        if user.is_superuser:
            return base.all()
        role = getattr(user, 'role', None)
        if role and role != 'patient':
            # Le personnel voit ses propres conversations + toutes les conversations patient
            return base.filter(
                Q(participants=user) | Q(type_conversation=Conversation.TypeConversation.PATIENT)
            ).distinct()
        return base.filter(participants=user).distinct()

    def perform_create(self, serializer):
        conversation = serializer.save(cree_par=self.request.user)
        ParticipantConversation.objects.get_or_create(
            conversation=conversation,
            utilisateur=self.request.user,
            defaults={"est_admin": True},
        )

        # Si c'est un patient qui crée la conversation, auto-lier son profil Patient
        role = getattr(self.request.user, 'role', None)
        if conversation.type_conversation == Conversation.TypeConversation.PATIENT and role == 'patient':
            try:
                patient = Patient.objects.get(user=self.request.user)
                if not conversation.patient_id:
                    conversation.patient = patient
                    conversation.save(update_fields=['patient'])
            except Exception:
                pass

        # Conversation patient: ajouter l'utilisateur patient lié comme participant
        if conversation.type_conversation == Conversation.TypeConversation.PATIENT and conversation.patient_id:
            patient_user_id = getattr(conversation.patient, "user_id", None)
            if patient_user_id and patient_user_id != self.request.user.id:
                ParticipantConversation.objects.get_or_create(
                    conversation=conversation,
                    utilisateur_id=patient_user_id,
                )

        # Conversation interne: ajouter les membres d'équipe sélectionnés.
        participants_ids = self.request.data.get("participants_ids") or []
        for utilisateur_id in participants_ids:
            ParticipantConversation.objects.get_or_create(
                conversation=conversation,
                utilisateur_id=utilisateur_id,
            )
        journaliser(
            acteur=self.request.user,
            action="conversation.created",
            objet_type="Conversation",
            objet_id=conversation.id,
            message=f"Conversation créée: {conversation.titre or conversation.id}",
        )

    @action(detail=True, methods=["post"])
    def marquer_lus(self, request, pk=None):
        """
        Marquer tous les messages de la conversation comme lus pour l'utilisateur actuel
        """
        try:
            conversation = self.get_object()
            
            # Vérifier que la conversation existe
            if not conversation:
                return Response({
                    "detail": "Conversation introuvable",
                    "conversation_id": pk
                }, status=404)
            
            # Marquer tous les messages non lus comme lus
            # Note: Le modèle Message a un champ 'lu' booléen, pas une relation ManyToMany
            
            # Vérifier d'abord que le champ 'lu' existe dans le modèle
            try:
                messages_non_lus = Message.objects.filter(
                    conversation=conversation,
                    lu=False
                )
            except Exception as field_error:
                # Si le champ 'lu' n'existe pas, retourner une erreur claire
                return Response({
                    "detail": "Erreur de configuration du modèle de message",
                    "error": str(field_error),
                    "conversation_id": pk,
                    "debug_info": "Le champ 'lu' n'existe peut-être pas dans le modèle Message"
                }, status=500)
            
            # Marquer les messages comme lus (un par un pour éviter les problèmes de bulk update)
            messages_count = 0
            for message in messages_non_lus:
                try:
                    message.lu = True
                    message.save(update_fields=['lu'])
                    messages_count += 1
                except Exception as save_error:
                    # Continuer même si un message ne peut pas être sauvegardé
                    print(f"Erreur lors de la sauvegarde du message {message.id}: {save_error}")
                    continue
            
            return Response({
                "detail": f"{messages_count} message(s) marqué(s) comme lu(s)",
                "messages_count": messages_count,
                "conversation_id": pk
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            # Gérer toutes les autres erreurs
            return Response({
                "detail": "Erreur lors du marquage des messages comme lus",
                "error": str(e),
                "conversation_id": pk,
                "debug_info": {
                    "error_type": type(e).__name__,
                    "user_authenticated": request.user.is_authenticated if hasattr(request, 'user') else False
                }
            }, status=500)

    @action(detail=True, methods=["post"])
    def ajouter_participant(self, request, pk=None):
        conversation = self.get_object()
        utilisateur_id = request.data.get("utilisateur_id")
        participant, created = ParticipantConversation.objects.get_or_create(
            conversation=conversation,
            utilisateur_id=utilisateur_id,
        )
        if not created:
            return Response({"detail": "Participant déjà présent."}, status=status.HTTP_200_OK)
        NotificationInterne.objects.create(
            destinataire=participant.utilisateur,
            titre="Nouvelle conversation",
            contenu=f"Vous avez été ajouté à la conversation {conversation.id}.",
        )
        return Response({"status": "ok"}, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=["get"])
    def messages(self, request, pk=None):
        try:
            conversation = self.get_object()
            
            # Vérifier que l'utilisateur a le droit d'accéder à cette conversation
            # Soit il est participant, soit c'est une conversation de patient où il est le patient
            is_participant = ParticipantConversation.objects.filter(
                conversation=conversation,
                utilisateur=request.user
            ).exists()
            
            is_patient_conversation = (conversation.type_conversation == 'patient' and 
                                     hasattr(request.user, 'role') and 
                                     request.user.role.lower() in ['patient'] and
                                     conversation.patient and
                                     Patient.objects.filter(user=request.user, id=conversation.patient.id).exists())
            
            # Autoriser le personnel cabinet (rôles Warm's)
            is_staff = (hasattr(request.user, 'role') and 
                       request.user.role.lower() in ['chirurgien_dentiste', 'secretaire', 'infirmiere', 'admin'])
            
            if not (is_participant or is_patient_conversation or is_staff or request.user.is_superuser):
                return Response({
                    "detail": "Vous n'êtes pas autorisé à accéder aux messages de cette conversation.",
                    "conversation_id": pk,
                    "user_id": request.user.id,
                    "debug_info": {
                        "is_participant": is_participant,
                        "is_patient_conversation": is_patient_conversation,
                        "is_staff": is_staff,
                        "conversation_type": conversation.type_conversation
                    }
                }, status=403)
            
            # Récupérer les messages
            qs = Message.objects.filter(conversation=conversation).select_related("auteur")

            # Marquer comme lus les messages des AUTRES participants (jamais les siens,
            # sinon l'accusé de réception "Vu" deviendrait vrai dès le propre rafraîchissement de l'auteur).
            if is_participant:
                qs.filter(lu=False).exclude(auteur_id=request.user.id).update(lu=True)

            messages_data = MessageSerializer(qs, many=True, context={"request": request}).data
            
            return Response(messages_data)
            
        except Exception as e:
            return Response({
                "detail": "Erreur lors de la récupération des messages",
                "error": str(e),
                "conversation_id": pk
            }, status=500)

    @action(detail=True, methods=["post"])
    def envoyer_message(self, request, pk=None):
        conversation = self.get_object()
        serializer = MessageSerializer(data={"conversation": conversation.id, "contenu": request.data.get("contenu", "")})
        serializer.is_valid(raise_exception=True)
        message = Message.objects.create(
            conversation=conversation,
            auteur=request.user,
            contenu=serializer.validated_data["contenu"],
        )
        conversation.save(update_fields=["modifie_le"])

        # Notifier les autres participants
        destinataires = conversation.participants.exclude(id=request.user.id)
        NotificationInterne.objects.bulk_create(
            [
                NotificationInterne(
                    destinataire=user,
                    titre="Nouveau message",
                    contenu=f"Nouveau message dans la conversation {conversation.id}.",
                )
                for user in destinataires
            ]
        )

        # Diffuser en temps réel via WebSocket (pour les clients déjà connectés
        # au canal — mobile ou web en polling n'en bénéficient pas, mais les
        # onglets web ouverts sur cette conversation reçoivent le message
        # instantanément sans attendre le cycle de polling de 30 s).
        try:
            from asgiref.sync import async_to_sync
            from channels.layers import get_channel_layer
            channel_layer = get_channel_layer()
            if channel_layer:
                msg_data = {
                    "id": message.id,
                    "contenu": message.contenu,
                    "auteur_username": request.user.username,
                    "cree_le": message.cree_le.isoformat(),
                    "conversation_id": conversation.id,
                    "est_lu": message.lu,
                }
                async_to_sync(channel_layer.group_send)(
                    f"chat_{conversation.id}",
                    {"type": "chat_message", "message": msg_data},
                )
        except Exception:
            pass  # Ne jamais faire échouer l'envoi à cause du WS

        return Response(
            MessageSerializer(message, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class ParticipantConversationViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    queryset = ParticipantConversation.objects.select_related("utilisateur", "conversation").all()
    serializer_class = ParticipantConversationSerializer


class NotificationInterneViewSet(
    mixins.ListModelMixin, mixins.UpdateModelMixin, viewsets.GenericViewSet
):
    serializer_class = NotificationInterneSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if not getattr(user, "is_authenticated", False):
            return NotificationInterne.objects.none()
        return NotificationInterne.objects.filter(destinataire=user)

    @action(detail=True, methods=["post"])
    def marquer_lu(self, request, pk=None):
        notif = self.get_object()
        notif.lu = True
        notif.save(update_fields=["lu"])
        return Response(NotificationInterneSerializer(notif).data)

    @action(detail=False, methods=["get"])
    def badges(self, request):
        qs = self.get_queryset().filter(lu=False)
        counts = qs.values("niveau").annotate(total=Count("id"))
        resume = {"rappel": 0, "message": 0, "critique": 0, "rdv": 0, "ordonnance": 0}
        for row in counts:
            niveau = row["niveau"]
            if niveau in resume:
                resume[niveau] = row["total"]

        # Pour les patients : compter les RDV à venir et ordonnances actives
        user = request.user
        role = getattr(user, 'role', None)
        if role == 'patient':
            try:
                from patients.models import Patient
                from django.utils import timezone
                patient = Patient.objects.filter(user=user).first()
                if patient:
                    from rendez_vous.models import RendezVous
                    from prescriptions.models import Prescription
                    resume["rdv"] = RendezVous.objects.filter(
                        patient=patient,
                        debut__gte=timezone.now(),
                        statut__in=["programme", "confirme"],
                    ).count()
                    resume["ordonnance"] = Prescription.objects.filter(
                        patient=patient, statut="active"
                    ).count()
            except Exception:
                pass

        return Response(resume)


class RappelViewSet(viewsets.ModelViewSet):
    """Rappels personnalisables programmés par l'utilisateur lui-même (CRUD complet)."""

    serializer_class = RappelSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Rappel.objects.filter(utilisateur=self.request.user)

    def perform_create(self, serializer):
        serializer.save(utilisateur=self.request.user)


#EbaJioloLewis
