import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/analyse_medicale.dart';
import '../services/ia_service.dart';

class AnalyseSymptomesScreen extends StatefulWidget {
  const AnalyseSymptomesScreen({Key? key}) : super(key: key);

  @override
  _AnalyseSymptomesScreenState createState() => _AnalyseSymptomesScreenState();
}

class _AnalyseSymptomesScreenState extends State<AnalyseSymptomesScreen> {
  final TextEditingController _symptomeController = TextEditingController();
  final List<String> _symptomesCommuns = [
    'Fièvre',
    'Toux',
    'Mal de tête',
    'Fatigue',
    'Nausées',
    'Douleur abdominale',
    'Essoufflement',
    'Vertiges',
    'Perte d\'appétit',
    'Insomnie',
    'Frissons',
    'Sueurs nocturnes',
  ];

  List<String> _symptomesSelectionnes = [];
  List<AnalyseMedicale> _historiqueAnalyses = [];
  bool _isLoading = false;
  AnalyseMedicale? _derniereAnalyse;

  @override
  void initState() {
    super.initState();
    _chargerHistorique();
  }

  Future<void> _chargerHistorique() async {
    try {
      // Simuler le chargement de l'historique
      // En production, appeler le service approprié
    } catch (e) {
      print('Erreur chargement historique: $e');
    }
  }

  Future<void> _analyserSymptomes() async {
    if (_symptomesSelectionnes.isEmpty) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final analyse = await IAService.analyserSymptomes(
        symptomes: _symptomesSelectionnes,
        patientInfo: {
          'age': 'adulte',
          'sexe': 'non spécifié',
          'antecedents': [],
        },
      );

      setState(() {
        _derniereAnalyse = analyse;
        _historiqueAnalyses.insert(0, analyse);
        _isLoading = false;
      });

      _montrerResultatsAnalyse(analyse);
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Erreur lors de l\'analyse: $e');
    }
  }

  void _montrerResultatsAnalyse(AnalyseMedicale analyse) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildResultatsBottomSheet(analyse),
    );
  }

  Widget _buildResultatsBottomSheet(AnalyseMedicale analyse) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: analyse.resultat.urgence 
                            ? Colors.red[100] 
                            : Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        analyse.resultat.urgence 
                            ? Icons.warning 
                            : Icons.check_circle,
                        color: analyse.resultat.urgence 
                            ? Colors.red[800] 
                            : Colors.green[800],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Résultats de l\'analyse',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Confiance: ${(analyse.confiance * 100).toInt()}%',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (analyse.resultat.urgence) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.emergency, color: Colors.red[800]),
                            const SizedBox(width: 8),
                            Text(
                              '⚠️ ATTENTION - NIVEAU D\'URGENCE',
                              style: TextStyle(
                                color: Colors.red[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Certains symptômes peuvent indiquer une condition médicale nécessitant une attention immédiate.',
                          style: TextStyle(color: Colors.red, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _contacterUrgence();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Contacter les urgences'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Diagnostics possibles:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...analyse.resultat.diagnosticsPossibles
                            .map((diagnostic) => _buildDiagnosticCard(diagnostic)),
                        const SizedBox(height: 20),
                        _buildRecommandationsSection(analyse),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticCard(DiagnosticPossible diagnostic) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    diagnostic.condition,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getProbabiliteColor(diagnostic.probabilite),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(diagnostic.probabilite * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (diagnostic.symptomesAssocies.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Symptômes associés: ${diagnostic.symptomesAssocies.join(', ')}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
            if (diagnostic.recommandations.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...diagnostic.recommandations.map((rec) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, 
                         size: 16, 
                         color: Colors.green[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rec,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecommandationsSection(AnalyseMedicale analyse) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.blue[800]),
              const SizedBox(width: 8),
              Text(
                'Recommandations générales',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Consulter un professionnel de santé pour un diagnostic précis\n'
            '• Ne pas ignorer les symptômes persistants\n'
            '• Surveiller l\'évolution des symptômes\n'
            '• Prendre note des changements dans votre état de santé',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            '⚠️ Cette analyse est générée par IA et ne remplace pas un avis médical professionnel.',
            style: TextStyle(
              color: Colors.blue[800],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getProbabiliteColor(double probabilite) {
    if (probabilite >= 0.7) return Colors.red[600]!;
    if (probabilite >= 0.4) return Colors.orange[600]!;
    return Colors.green[600]!;
  }

  void _contacterUrgence() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contacter les urgences'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Composez le 15 (SAMU) ou le 112'),
            SizedBox(height: 16),
            Text('Ou rendez-vous aux urgences les plus proches'),
            SizedBox(height: 16),
            Text('Ne tardez pas à consulter un professionnel de santé!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Compris'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implémenter l'appel d'urgence
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Appeler le 15'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
          textColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Analyse de Symptômes'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            _buildSymptomesInput(),
            const SizedBox(height: 24),
            _buildSymptomesCommuns(),
            const SizedBox(height: 24),
            _buildSymptomesSelectionnes(),
            const SizedBox(height: 24),
            _buildAnalyseButton(),
            if (_historiqueAnalyses.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildHistoriqueSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.blue[800]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comment ça fonctionne?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Décrivez vos symptômes et notre IA analysera les possibilités diagnostiques.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomesInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ajouter un symptôme',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _symptomeController,
                decoration: InputDecoration(
                  hintText: 'Tapez un symptôme...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (value) => _ajouterSymptome(value),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => _ajouterSymptome(_symptomeController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ],
    );
  }

  void _ajouterSymptome(String symptome) {
    if (symptome.trim().isEmpty) return;
    
    final symptomeNettoye = symptome.trim().toLowerCase();
    if (!_symptomesSelectionnes.contains(symptomeNettoye)) {
      setState(() {
        _symptomesSelectionnes.add(symptomeNettoye);
        _symptomeController.clear();
      });
      HapticFeedback.lightImpact();
    }
  }

  Widget _buildSymptomesCommuns() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Symptômes courants',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _symptomesCommuns.map((symptome) {
            final isSelected = _symptomesSelectionnes.contains(symptome.toLowerCase());
            return FilterChip(
              label: Text(symptome),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _symptomesSelectionnes.add(symptome.toLowerCase());
                  } else {
                    _symptomesSelectionnes.remove(symptome.toLowerCase());
                  }
                });
                HapticFeedback.lightImpact();
              },
              backgroundColor: Colors.grey[200],
              selectedColor: Colors.blue[100],
              labelStyle: TextStyle(
                color: isSelected ? Colors.blue[800] : Colors.black87,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSymptomesSelectionnes() {
    if (_symptomesSelectionnes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Symptômes sélectionnés',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _symptomesSelectionnes.clear());
              },
              child: const Text('Tout effacer'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _symptomesSelectionnes.map((symptome) {
            return Chip(
              label: Text(symptome),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () {
                setState(() {
                  _symptomesSelectionnes.remove(symptome);
                });
                HapticFeedback.lightImpact();
              },
              backgroundColor: Colors.blue[100],
              labelStyle: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAnalyseButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _symptomesSelectionnes.isEmpty || _isLoading 
            ? null 
            : _analyserSymptomes,
        style: ElevatedButton.styleFrom(
          backgroundColor: _symptomesSelectionnes.isEmpty 
              ? Colors.grey 
              : Colors.blue[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Analyse en cours...'),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.analytics),
                  const SizedBox(width: 8),
                  Text(
                    'Analyser les symptômes (${_symptomesSelectionnes.length})',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHistoriqueSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analyses récentes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ..._historiqueAnalyses.take(3).map((analyse) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: analyse.resultat.urgence 
                      ? Colors.red[100] 
                      : Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  analyse.resultat.urgence 
                      ? Icons.warning 
                      : Icons.check_circle,
                  color: analyse.resultat.urgence 
                      ? Colors.red[800] 
                      : Colors.green[800],
                  size: 20,
                ),
              ),
              title: Text(
                'Analyse du ${_formatDate(analyse.creeLe)}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                '${analyse.donneesEntree['symptomes']?.length ?? 0} symptômes analysés',
                style: TextStyle(color: Colors.grey[600]),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _montrerResultatsAnalyse(analyse),
            ),
          );
        }),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
