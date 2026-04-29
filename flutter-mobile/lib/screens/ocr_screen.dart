import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import '../models/document_ocr.dart';
import '../services/ia_service.dart';
import '../widgets/animated_card.dart';

class OCRScreen extends StatefulWidget {
  const OCRScreen({Key? key}) : super(key: key);

  @override
  _OCRScreenState createState() => _OCRScreenState();
}

class _OCRScreenState extends State<OCRScreen> with TickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  List<DocumentOCR> _documents = [];
  bool _isLoading = false;
  bool _isProcessing = false;
  String? _selectedImagePath;
  DocumentOCR? _currentDocument;
  
  late AnimationController _fabAnimationController;
  late AnimationController _scanAnimationController;
  late Animation<double> _fabRotationAnimation;
  late Animation<double> _scanProgressAnimation;

  @override
  void initState() {
    super.initState();
    _chargerDocuments();
    _initialiserAnimations();
  }

  void _initialiserAnimations() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scanAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fabRotationAnimation = Tween<double>(
      begin: 0,
      end: 0.25,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    ));

    _scanProgressAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _scanAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _scanAnimationController.dispose();
    super.dispose();
  }

  Future<void> _chargerDocuments() async {
    setState(() => _isLoading = true);
    
    try {
      final documents = await IAService.getDocumentsOCR();
      setState(() {
        _documents = documents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Erreur lors du chargement des documents: $e');
    }
  }

  Future<void> _choisirImage(ImageSource source) async {
    try {
      // Demander les permissions
      if (source == ImageSource.camera) {
        final cameraPermission = await Permission.camera.request();
        if (!cameraPermission.isGranted) {
          _showErrorSnackBar('Permission de caméra requise');
          return;
        }
      }

      final XFile? image = await _imagePicker.pickImage(source: source);
      
      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
          _fabAnimationController.forward();
        });
        
        HapticFeedback.lightImpact();
        _traiterImage(image);
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la sélection de l\'image: $e');
    }
  }

  Future<void> _traiterImage(XFile imageFile) async {
    setState(() => _isProcessing = true);
    _scanAnimationController.repeat();

    try {
      final document = await IAService.traiterImageOCR(
        imageFile: imageFile as File,
        metadonnees: {
          'plateforme': 'mobile',
          'date_scan': DateTime.now().toIso8601String(),
          'type_scan': 'mobile',
        },
      );

      setState(() {
        _currentDocument = document;
        _documents.insert(0, document);
        _isProcessing = false;
        _scanAnimationController.stop();
        _scanAnimationController.reset();
      });

      _montrerResultatsOCR(document);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _scanAnimationController.stop();
        _scanAnimationController.reset();
      });
      _showErrorSnackBar('Erreur lors du traitement OCR: $e');
    }
  }

  void _montrerResultatsOCR(DocumentOCR document) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildResultatsBottomSheet(document),
    );
  }

  Widget _buildResultatsBottomSheet(DocumentOCR document) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildResultHeader(document),
                  const SizedBox(height: 20),
                  _buildConfianceIndicator(document),
                  const SizedBox(height: 20),
                  _buildExtractedText(document),
                  const SizedBox(height: 20),
                  _buildActions(document),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultHeader(DocumentOCR document) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.document_scanner,
            color: Colors.green[800],
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scan OCR réussi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Scanné le ${_formatDate(document.creeLe)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceIndicator(DocumentOCR document) {
    final confiance = document.confiance;
    final couleur = _getConfianceColor(confiance);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: couleur),
              const SizedBox(width: 8),
              Text(
                'Confiance de reconnaissance',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: couleur,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: confiance / 100,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(couleur),
          ),
          const SizedBox(height: 8),
          Text(
            '${confiance.toInt()}% de confiance',
            style: TextStyle(
              color: couleur,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedText(DocumentOCR document) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Texte extrait',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () => _copierTexte(document.texteExtrait),
                  icon: const Icon(Icons.copy),
                ),
                IconButton(
                  onPressed: () => _partagerTexte(document.texteExtrait),
                  icon: const Icon(Icons.share),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            document.texteExtrait,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(DocumentOCR document) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _analyserDocument(document),
                icon: const Icon(Icons.analytics),
                label: const Text('Analyser'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _enregistrerDocument(document),
                icon: const Icon(Icons.save),
                label: const Text('Sauvegarder'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getConfidenceColor(double confiance) {
    if (confiance >= 80) return Colors.green[600]!;
    if (confiance >= 60) return Colors.orange[600]!;
    return Colors.red[600]!;
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
        title: const Text('Scanner OCR'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            onPressed: _chargerDocuments,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedImagePath != null) ...[
            _buildImagePreview(),
          ],
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _documents.isEmpty
                    ? _buildEmptyState()
                    : _buildDocumentsList(),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 200,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_selectedImagePath!),
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _scanProgressAnimation,
                      builder: (context, child) {
                        return CircularProgressIndicator(
                          value: _scanProgressAnimation.value,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Analyse OCR en cours...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedImagePath = null;
                  _fabAnimationController.reverse();
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.document_scanner_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun document scanné',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scannez un document pour commencer',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final document = _documents[index];
        return SlidingCard(
          delayDuration: Duration(milliseconds: index * 100),
          child: _buildDocumentCard(document),
        );
      },
    );
  }

  Widget _buildDocumentCard(DocumentOCR document) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.description,
            color: Colors.blue[800],
            size: 24,
          ),
        ),
        title: Text(
          'Document scanné',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confiance: ${document.confiance.toInt()}%',
              style: TextStyle(
                color: _getConfidenceColor(document.confiance),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              _formatDate(document.creeLe),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _montrerResultatsOCR(document),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return AnimatedBuilder(
      animation: _fabAnimationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _fabRotationAnimation.value * 2 * 3.14159,
          child: FloatingActionButton(
            onPressed: () => _showImageSourceDialog(),
            backgroundColor: Colors.blue[600],
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Scanner un document',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildImageSourceOption(
                      'Camera',
                      Icons.camera_alt,
                      Colors.blue,
                      () {
                        Navigator.pop(context);
                        _choisirImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildImageSourceOption(
                      'Galerie',
                      Icons.photo_library,
                      Colors.green,
                      () {
                        Navigator.pop(context);
                        _choisirImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return 'Il y a ${difference.inHours}h';
    } else {
      return 'Le ${date.day}/${date.month}/${date.year}';
    }
  }

  void _copierTexte(String texte) {
    Clipboard.setData(ClipboardData(text: texte));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Texte copié dans le presse-papiers')),
    );
  }

  void _partagerTexte(String texte) {
    // Implémenter le partage
    print('Partage du texte: $texte');
  }

  void _analyserDocument(DocumentOCR document) {
    // Implémenter l'analyse du document
    print('Analyse du document: ${document.id}');
  }

  void _enregistrerDocument(DocumentOCR document) {
    // Implémenter la sauvegarde
    print('Sauvegarde du document: ${document.id}');
  }
}
