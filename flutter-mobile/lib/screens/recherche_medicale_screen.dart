import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/recherche_ia.dart';
import '../services/ia_service.dart';

class RechercheMedicaleScreen extends StatefulWidget {
  const RechercheMedicaleScreen({Key? key}) : super(key: key);

  @override
  _RechercheMedicaleScreenState createState() => _RechercheMedicaleScreenState();
}

class _RechercheMedicaleScreenState extends State<RechercheMedicaleScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _suggestions = [
    'diabète symptômes',
    'hypertension traitement',
    'migraine causes',
    'allergie alimentaire',
    'dépression symptômes',
    'arthrose douleurs',
    'asthme traitement',
    'cholestérol alimentation',
  ];

  List<RechercheIA> _historique = [];
  List<RechercheResult> _resultats = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _chargerHistorique();
  }

  Future<void> _chargerHistorique() async {
    try {
      final historique = await IAService.getHistoriqueRecherches();
      setState(() {
        _historique = historique.take(10).toList();
      });
    } catch (e) {
      print('Erreur chargement historique: $e');
    }
  }

  Future<void> _effectuerRecherche(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _isLoading = true;
      _resultats = [];
    });

    HapticFeedback.lightImpact();

    try {
      final recherche = await IAService.rechercherMedical(
        query: query,
        contexte: {
          'specialite': 'medicale',
          'langue': 'fr',
          'plateforme': 'mobile'
        },
      );

      setState(() {
        _resultats = recherche.resultat;
        _isLoading = false;
        
        // Ajouter à l'historique
        _historique.insert(0, recherche);
        if (_historique.length > 10) {
          _historique.removeLast();
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Erreur lors de la recherche: $e');
    }
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
        title: const Text('Recherche Médicale'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isSearching ? _buildResultsView() : _buildSuggestionsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher des informations médicales...',
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _isSearching = false;
                      _resultats = [];
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            _effectuerRecherche(value);
          }
        },
        onChanged: (value) {
          if (value.isEmpty && _isSearching) {
            setState(() {
              _isSearching = false;
              _resultats = [];
            });
          }
        },
      ),
    );
  }

  Widget _buildSuggestionsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_historique.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Recherches récentes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            ..._historique.map((recherche) => _buildHistoriqueItem(recherche)),
            const SizedBox(height: 24),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Suggestions de recherche',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((suggestion) {
              return _buildSuggestionChip(suggestion);
            }).toList(),
          ),
          const SizedBox(height: 24),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildHistoriqueItem(RechercheIA recherche) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.history,
            color: Colors.blue[800],
            size: 20,
          ),
        ),
        title: Text(
          recherche.query,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${recherche.resultat.length} résultats • ${_formatDate(recherche.timestamp)}',
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          _searchController.text = recherche.query;
          _effectuerRecherche(recherche.query);
        },
      ),
    );
  }

  Widget _buildSuggestionChip(String suggestion) {
    return ActionChip(
      label: Text(suggestion),
      backgroundColor: Colors.blue[50],
      labelStyle: TextStyle(color: Colors.blue[800]),
      avatar: Icon(Icons.search, size: 16, color: Colors.blue[800]),
      onPressed: () {
        _searchController.text = suggestion;
        _effectuerRecherche(suggestion);
      },
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions rapides',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 3,
          children: [
            _buildQuickActionCard(
              'Symptômes',
              Icons.healing,
              Colors.red[100]!,
              Colors.red[800]!,
              () => _effectuerRecherche('symptômes analyse'),
            ),
            _buildQuickActionCard(
              'Traitements',
              Icons.medication,
              Colors.green[100]!,
              Colors.green[800]!,
              () => _effectuerRecherche('traitements médicamenteux'),
            ),
            _buildQuickActionCard(
              'Interactions',
              Icons.warning,
              Colors.orange[100]!,
              Colors.orange[800]!,
              () => _effectuerRecherche('interactions médicamenteuses'),
            ),
            _buildQuickActionCard(
              'Urgence',
              Icons.emergency,
              Colors.purple[100]!,
              Colors.purple[800]!,
              () => _effectuerRecherche('symptômes urgence'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    Color backgroundColor,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: iconColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Recherche en cours...'),
          ],
        ),
      );
    }

    if (_resultats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun résultat trouvé',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez avec d autres mots-clés',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _resultats.length,
      itemBuilder: (context, index) {
        final result = _resultats[index];
        return _buildResultCard(result);
      },
    );
  }

  Widget _buildResultCard(RechercheResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              result.titre,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  result.snippet,
                  style: TextStyle(
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getSourceColor(result.source),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        result.source,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (result.date != null) ...[
                      Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        result.date!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(result.pertinence * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ButtonBar(
            children: [
              TextButton.icon(
                onPressed: () => _ouvrirLien(result.url),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Voir'),
              ),
              TextButton.icon(
                onPressed: () => _partagerResultat(result),
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Partager'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getSourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'pubmed':
        return Colors.blue[600]!;
      case 'google scholar':
        return Colors.green[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  void _ouvrirLien(String url) {
    // Implémenter l'ouverture du lien dans le navigateur
    print('Ouverture du lien: $url');
  }

  void _partagerResultat(RechercheResult result) {
    // Implémenter le partage du résultat
    print('Partage du résultat: ${result.titre}');
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inHours < 1) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return 'Il y a ${difference.inHours}h';
    } else {
      return 'Il y a ${difference.inDays}j';
    }
  }
}
