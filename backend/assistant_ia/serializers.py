from rest_framework import serializers

from .models import CompteRenduIA, MessageAssistantIA, OCRImportCarnet, RecommandationIA


class OCRImportCarnetSerializer(serializers.ModelSerializer):
    class Meta:
        model = OCRImportCarnet
        fields = [
            "id",
            "patient",
            "dossier",
            "image_source",
            "texte_extrait",
            "cree_par",
            "cree_le",
        ]
        read_only_fields = ["cree_par", "cree_le"]


class RecommandationIASerializer(serializers.ModelSerializer):
    class Meta:
        model = RecommandationIA
        fields = [
            "id",
            "patient",
            "type_recommandation",
            "message",
            "score_confiance",
            "resolue",
            "cree_le",
        ]


class CompteRenduIASerializer(serializers.ModelSerializer):
    class Meta:
        model = CompteRenduIA
        fields = ["id", "consultation", "contenu", "genere_par", "cree_le"]
        read_only_fields = ["genere_par", "cree_le"]


class MessageAssistantIASerializer(serializers.ModelSerializer):
    class Meta:
        model = MessageAssistantIA
        fields = ["id", "dossier", "auteur", "question", "reponse", "cree_le"]
        read_only_fields = ["auteur", "cree_le"]


#EbaJioloLewis
