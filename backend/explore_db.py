#!/usr/bin/env python
import os
import django

# Configuration Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'gestion_cabinet.settings')
django.setup()

from django.db import connection

def explore_tables():
    """Explorer les tables consultations et rendez_vous existantes"""
    try:
        with connection.cursor() as cursor:
            # Lister toutes les tables
            print("=== Tables disponibles dans la base de données ===")
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
            tables = cursor.fetchall()
            for table in tables:
                print(f"- {table[0]}")
            
            # Explorer la table consultations_consultation
            if any('consultations_consultation' in table[0] for table in tables):
                print("\n=== Structure de la table consultations_consultation ===")
                cursor.execute("PRAGMA table_info(consultations_consultation)")
                columns = cursor.fetchall()
                for col in columns:
                    print(f"- {col[1]}: {col[2]} (nullable: {not col[3]})")
                
                # Afficher quelques exemples de données
                print("\n=== Exemples de consultations ===")
                cursor.execute("SELECT * FROM consultations_consultation LIMIT 3")
                rows = cursor.fetchall()
                for row in rows:
                    print(row)
            
            # Explorer la table rendez_vous_rendezvous
            if any('rendez_vous_rendezvous' in table[0] for table in tables):
                print("\n=== Structure de la table rendez_vous_rendezvous ===")
                cursor.execute("PRAGMA table_info(rendez_vous_rendezvous)")
                columns = cursor.fetchall()
                for col in columns:
                    print(f"- {col[1]}: {col[2]} (nullable: {not col[3]})")
                
                # Afficher quelques exemples de données
                print("\n=== Exemples de rendez-vous ===")
                cursor.execute("SELECT * FROM rendez_vous_rendezvous LIMIT 3")
                rows = cursor.fetchall()
                for row in rows:
                    print(row)
        
    except Exception as e:
        print(f"Erreur lors de l'exploration: {e}")

if __name__ == "__main__":
    explore_tables()
