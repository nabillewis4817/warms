import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface ParticipantInfo {
  id: number;
  nom: string;
  role: string;
  en_ligne: boolean;
}

export interface Conversation {
  id: number;
  titre: string;
  type_conversation: string;
  patient: number | null;
  patient_nom?: string | null;
  participants: number[];
  participants_info?: ParticipantInfo[];
  en_ligne?: boolean;
  dernier_message?: string | null;
  dernier_message_le?: string | null;
  non_lus?: number;
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
  est_lu?: boolean;
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

  detailConversation(id: number): Observable<Conversation> {
    return this.http.get<Conversation>(`${this.baseUrl}/conversations/${id}/`);
  }

  listerMessages(conversationId: number): Observable<MessageConversation[]> {
    return this.http.get<MessageConversation[]>(
      `${this.baseUrl}/conversations/${conversationId}/messages/`
    );
  }

  creerConversation(
    titre: string,
    typeConversation: 'interne' | 'patient' = 'interne',
    patientId?: number,
    participantsIds?: number[]
  ): Observable<Conversation> {
    return this.http.post<Conversation>(`${this.baseUrl}/conversations/`, {
      titre,
      type_conversation: typeConversation,
      ...(patientId ? { patient: patientId } : {}),
      ...(participantsIds?.length ? { participants_ids: participantsIds } : {}),
    });
  }

  envoyerMessage(conversationId: number, contenu: string): Observable<MessageConversation> {
    return this.http.post<MessageConversation>(
      `${this.baseUrl}/conversations/${conversationId}/envoyer_message/`,
      { contenu }
    );
  }

  marquerLus(conversationId: number): Observable<{ detail: string }> {
    return this.http.post<{ detail: string }>(
      `${this.baseUrl}/conversations/${conversationId}/marquer_lus/`,
      {}
    );
  }

  badges(): Observable<BadgesNotifications> {
    return this.http.get<BadgesNotifications>(`${this.baseUrl}/notifications/badges/`);
  }
}

// #EbaJioloLewis
