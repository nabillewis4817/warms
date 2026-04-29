import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface Conversation {
  id: number;
  titre: string;
  type_conversation: string;
  patient: number | null;
  participants: number[];
  cree_par: number;
  cree_le: string;
  modifie_le: string;
}

export interface MessageConversation {
  id: number;
  conversation: number;
  auteur_username: string;
  contenu: string;
  cree_le: string;
}

export interface BadgesNotifications {
  rappel: number;
  message: number;
  critique: number;
}

@Injectable({
  providedIn: 'root',
})
export class Messagerie {
  private readonly baseUrl = 'http://127.0.0.1:8000/api/v1';

  constructor(private readonly http: HttpClient) {}

  listerConversations(): Observable<Conversation[]> {
    return this.http.get<Conversation[]>(`${this.baseUrl}/conversations/`);
  }

  listerMessages(conversationId: number): Observable<MessageConversation[]> {
    return this.http.get<MessageConversation[]>(
      `${this.baseUrl}/conversations/${conversationId}/messages/`
    );
  }

  creerConversation(titre: string): Observable<Conversation> {
    return this.http.post<Conversation>(`${this.baseUrl}/conversations/`, {
      titre,
      type_conversation: 'interne',
    });
  }

  envoyerMessage(conversationId: number, contenu: string): Observable<MessageConversation> {
    return this.http.post<MessageConversation>(
      `${this.baseUrl}/conversations/${conversationId}/envoyer_message/`,
      { contenu }
    );
  }

  badges(): Observable<BadgesNotifications> {
    return this.http.get<BadgesNotifications>(`${this.baseUrl}/notifications/badges/`);
  }
}

// #EbaJioloLewis
