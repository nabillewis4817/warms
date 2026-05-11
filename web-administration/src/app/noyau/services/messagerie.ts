import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

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
  private readonly baseUrl = environment.apiBaseUrl;

  constructor(private readonly http: HttpClient) {}

  listerConversations(): Observable<Conversation[]> {
    return this.http.get<Conversation[]>(`${this.baseUrl}/conversations/`);
  }

  listerMessages(conversationId: number): Observable<MessageConversation[]> {
    return this.http.get<MessageConversation[]>(
      `${this.baseUrl}/conversations/${conversationId}/messages/`
    );
  }

  creerConversation(titre: string, typeConversation: 'interne' | 'patient' = 'interne', patientId?: number): Observable<Conversation> {
    return this.http.post<Conversation>(`${this.baseUrl}/conversations/`, {
      titre,
      type_conversation: typeConversation,
      ...(patientId ? { patient: patientId } : {}),
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
