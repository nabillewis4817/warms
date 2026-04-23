import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from .models import Conversation, Message

class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope["user"]
        if isinstance(self.user, AnonymousUser):
            await self.close()
            return
        
        self.conversation_id = self.scope["url_route"]["kwargs"]["conversation_id"]
        self.conversation_group_name = f"chat_{self.conversation_id}"
        
        # Vérifier si l'utilisateur a accès à cette conversation
        if not await self.has_conversation_access():
            await self.close()
            return
        
        # Rejoindre le groupe de conversation
        await self.channel_layer.group_add(
            self.conversation_group_name,
            self.channel_name
        )
        
        await self.accept()
    
    async def disconnect(self, close_code):
        # Quitter le groupe de conversation
        await self.channel_layer.group_discard(
            self.conversation_group_name,
            self.channel_name
        )
    
    async def receive(self, text_data):
        text_data_json = json.loads(text_data)
        message_content = text_data_json['message']
        
        # Sauvegarder le message en base de données
        message = await self.save_message(message_content)
        
        # Envoyer le message au groupe
        await self.channel_layer.group_send(
            self.conversation_group_name,
            {
                'type': 'chat_message',
                'message': {
                    'id': message.id,
                    'contenu': message.contenu,
                    'auteur_username': message.auteur.username,
                    'date_creation': message.date_creation.isoformat(),
                    'conversation_id': message.conversation.id
                }
            }
        )
    
    async def chat_message(self, event):
        message = event['message']
        
        # Envoyer le message au WebSocket
        await self.send(text_data=json.dumps({
            'message': message
        }))
    
    @database_sync_to_async
    def has_conversation_access(self):
        try:
            conversation = Conversation.objects.get(id=self.conversation_id)
            # Vérifier si l'utilisateur est participant de la conversation
            return conversation.participants.filter(id=self.user.id).exists()
        except Conversation.DoesNotExist:
            return False
    
    @database_sync_to_async
    def save_message(self, content):
        conversation = Conversation.objects.get(id=self.conversation_id)
        message = Message.objects.create(
            conversation=conversation,
            auteur=self.user,
            contenu=content
        )
        return message

class NotificationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope["user"]
        if isinstance(self.user, AnonymousUser):
            await self.close()
            return
        
        self.user_group_name = f"user_{self.user.id}"
        
        # Rejoindre le groupe de notifications de l'utilisateur
        await self.channel_layer.group_add(
            self.user_group_name,
            self.channel_name
        )
        
        await self.accept()
    
    async def disconnect(self, close_code):
        # Quitter le groupe de notifications
        await self.channel_layer.group_discard(
            self.user_group_name,
            self.channel_name
        )
    
    async def notification_message(self, event):
        notification = event['notification']
        
        # Envoyer la notification au WebSocket
        await self.send(text_data=json.dumps({
            'notification': notification
        }))
