import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from .models import Conversation, Message


class ChatConsumer(AsyncWebsocketConsumer):

    async def connect(self):
        # JWT auth via query-string: ?token=<access_token>
        query_string = self.scope.get('query_string', b'').decode()
        params = {}
        for pair in query_string.split('&'):
            if '=' in pair:
                k, _, v = pair.partition('=')
                params[k] = v

        self.user = await self.authentifier_token(params.get('token', ''))
        if self.user is None:
            await self.close()
            return

        self.conversation_id = self.scope['url_route']['kwargs']['conversation_id']
        self.conversation_group_name = f'chat_{self.conversation_id}'

        if not await self.verifier_acces():
            await self.close()
            return

        await self.channel_layer.group_add(self.conversation_group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, 'conversation_group_name'):
            await self.channel_layer.group_discard(self.conversation_group_name, self.channel_name)

    async def receive(self, text_data):
        data = json.loads(text_data)
        contenu = data.get('message', '').strip()
        if not contenu:
            return
        message_data = await self.sauvegarder_message(contenu)
        await self.channel_layer.group_send(
            self.conversation_group_name,
            {'type': 'chat_message', 'message': message_data},
        )

    async def chat_message(self, event):
        await self.send(text_data=json.dumps({'message': event['message']}))

    @database_sync_to_async
    def authentifier_token(self, token_str):
        if not token_str:
            return None
        try:
            from rest_framework_simplejwt.tokens import AccessToken
            from django.contrib.auth import get_user_model
            payload = AccessToken(token_str).payload
            User = get_user_model()
            return User.objects.get(pk=payload['user_id'])
        except Exception:
            return None

    @database_sync_to_async
    def verifier_acces(self):
        try:
            conv = Conversation.objects.get(id=self.conversation_id)
            # Le personnel non-patient peut accéder à toute conversation de type patient
            role = getattr(self.user, 'role', None)
            if role and role != 'patient':
                return True
            return conv.participants.filter(id=self.user.id).exists()
        except Conversation.DoesNotExist:
            return False

    @database_sync_to_async
    def sauvegarder_message(self, contenu):
        conv = Conversation.objects.get(id=self.conversation_id)
        msg = Message.objects.create(conversation=conv, auteur=self.user, contenu=contenu)
        return {
            'id': msg.id,
            'contenu': msg.contenu,
            'auteur_username': self.user.username,
            'cree_le': msg.cree_le.isoformat(),
            'conversation_id': conv.id,
            'est_lu': msg.lu,
        }


class NotificationConsumer(AsyncWebsocketConsumer):

    async def connect(self):
        query_string = self.scope.get('query_string', b'').decode()
        params = {}
        for pair in query_string.split('&'):
            if '=' in pair:
                k, _, v = pair.partition('=')
                params[k] = v

        self.user = await self.authentifier_token(params.get('token', ''))
        if self.user is None:
            await self.close()
            return

        self.user_group_name = f'user_{self.user.id}'
        await self.channel_layer.group_add(self.user_group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, 'user_group_name'):
            await self.channel_layer.group_discard(self.user_group_name, self.channel_name)

    async def notification_message(self, event):
        await self.send(text_data=json.dumps({'notification': event['notification']}))

    @database_sync_to_async
    def authentifier_token(self, token_str):
        if not token_str:
            return None
        try:
            from rest_framework_simplejwt.tokens import AccessToken
            from django.contrib.auth import get_user_model
            payload = AccessToken(token_str).payload
            User = get_user_model()
            return User.objects.get(pk=payload['user_id'])
        except Exception:
            return None
