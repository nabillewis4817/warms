import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import '../services/ia_service.dart';
import 'package:flutter/foundation.dart';

/// Écran de Recherche Médicale IA pour WARMS Mobile
/// 
/// Cet écran permet aux utilisateurs de rechercher des informations médicales
/// à partir de sources fiables comme PubMed, Google Scholar et l'OMS.
/// 
/// Fonctionnalités principales :
/// - Recherche médicale multi-sources
/// - Suggestions intelligentes de recherche
/// - Historique des recherches récentes
/// - Affichage des résultats avec pertinence
/// - Interface moderne avec animations
/// 
/// @author WARMS Team
/// @version 1.0.0
class IARechercheScreen extends StatefulWidget {
  const IARechercheScreen({super.key});

  @override
  State<IARechercheScreen> createState() => _IARechercheScreenState();
}

class _IARechercheScreenState extends State<IARechercheScreen>
    with TickerProviderStateMixin {
  
  // ==================== CONTRÔLEURS ====================
  
  /// Contrôleur pour le champ de recherche
  final TextEditingController _searchController = TextEditingController();
  
  /// Contrôleur pour le scrolling des résultats
  final ScrollController _scrollController = ScrollController();
  
  /// Animation pour la recherche
  late AnimationController _searchAnimationController;
  
  /// Animation pour les résultats
  late AnimationController _resultsAnimationController;

  // ==================== ÉTAT ====================
  
  /// Résultats de la recherche
  List<Map<String, dynamic>> _results = [];
  
  /// Historique des recherches récentes
  List<String> _searchHistory = [];
  
  /// Suggestions de recherche
  List<String> _suggestions = [];
  
  /// État de chargement
  bool _isLoading = false;
  
  /// Message d'erreur
  String? _errorMessage;
  
  /// Requête de recherche actuelle
  String _currentQuery = '';

  // ==================== SUGGESTIONS PRÉDÉFINIES ====================
  
  static const List<String> _popularSearches = [
    'Diabète type 2',
    'Hypertension artérielle',
    'COVID-19 symptômes',
    'Cancer du sein',
    'Dépression traitement',
    'Vaccination enfance',
    'Maladie d\'Alzheimer',
    'Asthme traitement',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadSearchHistory();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchAnimationController.dispose();
    _resultsAnimationController.dispose();
    super.dispose();
  }

  // ==================== INITIALISATION ====================

  /// Initialise les animations
  void _initializeAnimations() {
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _resultsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  /// Charge l'historique des recherches
  Future<void> _loadSearchHistory() async {
    // TODO: Charger depuis le stockage local
    setState(() {
      _searchHistory = [
        'Grippe symptômes',
        'Maux de tête',
        'Allergies saisonnières',
      ];
    });
  }

  // ==================== GESTION DE LA RECHERCHE ====================

  /// Gère les changements dans le champ de recherche
  void _onSearchChanged() {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _suggestions.clear();
      });
      return;
    }

    // Générer des suggestions basées sur l'entrée
    _generateSuggestions(query);
  }

  /// Génère des suggestions de recherche intelligentes
  void _generateSuggestions(String query) {
    final suggestions = <String>[];
    
    // Suggestions basées sur l'historique
    for (String historyItem in _searchHistory) {
      if (historyItem.toLowerCase().contains(query.toLowerCase())) {
        suggestions.add(historyItem);
      }
    }
    
    // Suggestions basées sur les recherches populaires
    for (String popular in _popularSearches) {
      if (popular.toLowerCase().contains(query.toLowerCase()) &&
          !suggestions.contains(popular)) {
        suggestions.add(popular);
      }
    }
    
    setState(() {
      _suggestions = suggestions.take(5).toList();
    });
  }

  /// Effectue la recherche médicale
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      _showError('Veuillez entrer une recherche');
      return;
    }

    setState(() {
      _currentQuery = query;
      _isLoading = true;
      _errorMessage = null;
      _results.clear();
      _suggestions.clear();
    });

    // Animation de recherche
    _searchAnimationController.forward();

    try {
      final response = await IAService().rechercherMedical(
        query: query,
        plateforme: 'mobile',
        contexte: {
          'user_id': 'current_user', // À remplacer
          'search_session': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      final searchResults = response['resultats'] as List<dynamic>? ?? [];
      
      setState(() {
        _results = searchResults.cast<Map<String, dynamic>>();
        _isLoading = false;
      });

      // Ajouter à l'historique
      _addToSearchHistory(query);

      // Animation des résultats
      _resultsAnimationController.forward();

      if (kDebugMode) {
        print('🔍 Recherche terminée: ${_results.length} résultats');
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// Ajoute une recherche à l'historique
  void _addToSearchHistory(String query) {
    setState(() {
      // Supprimer si déjà présent
      _searchHistory.remove(query);
      // Ajouter au début
      _searchHistory.insert(0, query);
      // Limiter à 10 éléments
      if (_searchHistory.length > 10) {
        _searchHistory = _searchHistory.take(10).toList();
      }
    });
    
    // TODO: Sauvegarder dans le stockage local
  }

  // ==================== INTERFACE UTILISATEUR ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Barre de recherche
          _buildSearchBar(),
          
          // Message d'erreur
          if (_errorMessage != null) _buildErrorMessage(),
          
          // Contenu principal
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  /// Construit la barre d'application
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[600],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.search,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Recherche Médicale',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      actions: [
        // Filtres
        IconButton(
          onPressed: _showFilters,
          icon: const Icon(Icons.filter_list),
          tooltip: 'Filtres',
        ),
      ],
    );
  }

  /// Construit la barre de recherche avec suggestions
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Champ de recherche
          TextField(
            controller: _searchController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Rechercher des informations médicales...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () => _searchController.clear(),
                      icon: const Icon(Icons.clear),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue[600]!),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onSubmitted: _performSearch,
          ),
          
          // Suggestions
          if (_suggestions.isNotEmpty) _buildSuggestions(),
        ],
      ),
    );
  }

  /// Affiche les suggestions de recherche
  Widget _buildSuggestions() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Suggestions',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ..._suggestions.map((suggestion) {
            return ListTile(
              dense: true,
              leading: Icon(Icons.history, color: Colors.grey[400], size: 16),
              title: Text(
                suggestion,
                style: const TextStyle(fontSize: 14),
              ),
              onTap: () {
                _searchController.text = suggestion;
                _performSearch(suggestion);
              },
            );
          }),
        ],
      ),
    );
  }

  /// Affiche un message d'erreur
  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[600], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red[800],
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _errorMessage = null),
            icon: const Icon(Icons.close, size: 16),
            color: Colors.red[600],
          ),
        ],
      ),
    );
  }

  /// Construit le contenu principal selon l'état
  Widget _buildMainContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    if (_currentQuery.isEmpty) {
      return _buildInitialState();
    }
    
    if (_results.isEmpty && _errorMessage == null) {
      return _buildNoResultsState();
    }
    
    return _buildResultsList();
  }

  /// État de chargement
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animation de recherche
          AnimatedBuilder(
            animation: _searchAnimationController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_searchAnimationController.value * 0.2),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Recherche en cours...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'WARMS analyse les sources médicales fiables',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Sources consultées
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSourceChip('PubMed'),
              const SizedBox(width: 8),
              _buildSourceChip('Google Scholar'),
              const SizedBox(width: 8),
              _buildSourceChip('WHO'),
            ],
          ),
        ],
      ),
    );
  }

  /// État initial (aucune recherche)
  Widget _buildInitialState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Recherche Médicale IA',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Accédez à des informations médicales fiables et à jour',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Sources fiables
          _buildReliableSourcesSection(),
          
          const SizedBox(height: 32),
          
          // Recherches populaires
          _buildPopularSearchesSection(),
          
          const SizedBox(height: 32),
          
          // Historique
          if (_searchHistory.isNotEmpty) _buildHistorySection(),
        ],
      ),
    );
  }

  /// Section des sources fiables
  Widget _buildReliableSourcesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: Colors.green[600]),
              const SizedBox(width: 8),
              Text(
                'Sources Fiables',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(child: _buildSourceCard('PubMed', 'Articles scientifiques', Icons.article)),
              const SizedBox(width: 12),
              Expanded(child: _buildSourceCard('Google Scholar', 'Publications académiques', Icons.school)),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(child: _buildSourceCard('WHO', 'Directives OMS', Icons.health_and_safety)),
              const SizedBox(width: 12),
              Expanded(child: _buildSourceCard('CDC', 'Recommandations CDC', Icons.local_hospital)),
            ],
          ),
        ],
      ),
    );
  }

  /// Carte de source individuelle
  Widget _buildSourceCard(String name, String description, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue[600], size: 16),
              const SizedBox(width: 4),
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[800],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: Colors.blue[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Section des recherches populaires
  Widget _buildPopularSearchesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recherches Populaires',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        
        const SizedBox(height: 12),
        
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _popularSearches.map((search) {
            return ActionChip(
              label: Text(
                search,
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () {
                _searchController.text = search;
                _performSearch(search);
              },
              backgroundColor: Colors.grey[100],
              side: BorderSide(color: Colors.grey[300]!),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Section de l'historique
  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recherches Récentes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            TextButton(
              onPressed: _clearHistory,
              child: Text(
                'Effacer',
                style: TextStyle(color: Colors.blue[600]),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        ..._searchHistory.map((search) {
          return ListTile(
            dense: true,
            leading: Icon(Icons.history, color: Colors.grey[400]),
            title: Text(search),
            trailing: IconButton(
              onPressed: () {
                _searchController.text = search;
                _performSearch(search);
              },
              icon: const Icon(Icons.arrow_forward),
            ),
            onTap: () {
              _searchController.text = search;
              _performSearch(search);
            },
          );
        }),
      ],
    );
  }

  /// État sans résultats
  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Aucun résultat trouvé',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
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
          
          const SizedBox(height: 24),
          
          ElevatedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _currentQuery = '';
              });
            },
            child: const Text('Nouvelle recherche'),
          ),
        ],
      ),
    );
  }

  /// Liste des résultats
  Widget _buildResultsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header des résultats
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                '${_results.length} résultats pour',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '"$_currentQuery"',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Liste des résultats
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _results.length,
            itemBuilder: (context, index) {
              return _buildResultCard(_results[index], index);
            },
          ),
        ),
      ],
    );
  }

  /// Carte de résultat individuelle
  Widget _buildResultCard(Map<String, dynamic> result, int index) {
    return AnimatedBuilder(
      animation: _resultsAnimationController,
      builder: (context, child) {
        final delay = index * 0.1;
        final animation = CurvedAnimation(
          parent: _resultsAnimationController,
          curve: Interval(
            delay.clamp(0.0, 1.0),
            (delay + 0.3).clamp(0.0, 1.0),
            curve: Curves.easeOutQuart,
          ),
        );

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(animation),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre et source
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              result['title'] ?? 'Sans titre',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          _buildSourceChip(result['source'] ?? 'Inconnue'),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Résumé
                      Text(
                        result['summary'] ?? 'Aucun résumé disponible',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Métadonnées
                      Row(
                        children: [
                          _buildMetadataChip(
                            Icons.star,
                            '${(result['relevance'] ?? 0.8 * 100).toInt()}%',
                            Colors.orange[600]!,
                          ),
                          const SizedBox(width: 8),
                          _buildMetadataChip(
                            Icons.calendar_today,
                            result['date'] ?? 'Date inconnue',
                            Colors.grey[600]!,
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => _openResult(result),
                            icon: const Icon(Icons.open_in_new),
                            tooltip: 'Voir le détail',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Chip de source
  Widget _buildSourceChip(String source) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        source,
        style: TextStyle(
          color: Colors.blue[800],
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Chip de métadonnées
  Widget _buildMetadataChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ==================== ACTIONS ====================

  /// Affiche les filtres de recherche
  void _showFilters() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Filtres de recherche',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            // TODO: Implémenter les filtres
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('Période'),
              subtitle: const Text('Dernière année'),
            ),
            
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Langue'),
              subtitle: const Text('Français'),
            ),
            
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Catégorie'),
              subtitle: const Text('Toutes'),
            ),
          ],
        ),
      ),
    );
  }

  /// Ouvre un résultat détaillé
  void _openResult(Map<String, dynamic> result) {
    // TODO: Implémenter l'ouverture du détail
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ouverture de: ${result['title']}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Efface l'historique de recherche
  void _clearHistory() {
    setState(() {
      _searchHistory.clear();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Historique effacé'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Affiche un message d'erreur
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
