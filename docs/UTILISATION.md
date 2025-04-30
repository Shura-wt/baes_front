# Guide d'Utilisation des Nouvelles Classes

Ce document fournit des exemples d'utilisation des nouvelles classes utilitaires et de service créées pour améliorer l'organisation et la maintenabilité du code.

## Logger

Le `Logger` permet de journaliser les messages de manière structurée et configurable.

```dart
// Créer un logger avec un tag
final logger = Logger('MonTag');

// Journaliser des messages à différents niveaux
logger.d('Message de débogage');
logger.i('Message d'information');
logger.w('Message d'avertissement');
logger.e('Message d'erreur', erreur, stackTrace);

// Journaliser le début et la fin des opérations
logger.start('nomOperation');
// ... code de l'opération ...
logger.end('nomOperation', success: true);
```

## ApiUtils

`ApiUtils` standardise les appels API avec une gestion appropriée des erreurs.

```dart
// Faire une requête GET
final data = await ApiUtils.get('https://api.example.com/endpoint');

// Faire une requête POST
final response = await ApiUtils.post('https://api.example.com/endpoint', {'cle': 'valeur'});

// Faire une requête PUT
final donneesMisesAJour = await ApiUtils.put('https://api.example.com/endpoint/123', {'cle': 'nouvelleValeur'});

// Faire une requête DELETE
final succes = await ApiUtils.delete('https://api.example.com/endpoint/123');
```

## MapUtils

`MapUtils` fournit des utilitaires communs liés aux cartes.

```dart
// Normaliser les dimensions d'une image
final normalise = MapUtils.normalizeImageDimensions(hauteur, largeur);

// Vérifier si un point est à l'intérieur d'un polygone
final estDedans = MapUtils.isPointInPolygon(point, pointsPolygone);

// Créer un marqueur
final marqueur = MapUtils.createCircleMarker(
  point: LatLng(0, 0),
  color: Colors.red,
  label: '1',
);

// Créer un marqueur BAES
final marqueurBaes = MapUtils.createBaesMarker(LatLng(0, 0));
```

## UiUtils

`UiUtils` fournit des composants UI et des dialogues réutilisables.

```dart
// Afficher une snackbar
UiUtils.showSnackBar(context, 'Message');

// Afficher un dialogue de chargement
await UiUtils.showLoadingDialog(context, 'Chargement...');

// Afficher un dialogue de confirmation
final confirme = await UiUtils.showConfirmationDialog(
  context,
  title: 'Confirmation',
  content: 'Êtes-vous sûr ?',
);

// Afficher un dialogue de saisie de texte
final texte = await UiUtils.showTextInputDialog(
  context,
  title: 'Entrez du texte',
  hintText: 'Texte',
);

// Créer un conteneur avec un dropdown
final dropdown = UiUtils.createDropdownContainer(
  value: valeurSelectionnee,
  items: items,
  onChanged: (valeur) => setState(() => valeurSelectionnee = valeur),
  hintText: 'Sélectionnez une option',
);
```

## BaesService

`BaesService` gère les opérations liées aux BAES.

```dart
// Créer un BAES
final baes = await BaesService.createBaes('BAES 1', LatLng(0, 0), idEtage);

// Charger les BAES d'un étage
final listeBaes = await BaesService.loadBaesForFloor(idEtage);

// Convertir les BAES en marqueurs
final marqueurs = BaesService.convertBaesToMarkers(listeBaes);

// Créer un étage
final etage = await BaesService.createFloor('Étage 1', idBatiment);

// Mettre à jour un étage
final etageMisAJour = await BaesService.updateFloor(idEtage, 'Nouveau Nom d\'Étage');

// Supprimer un étage
final succes = await BaesService.deleteFloor(idEtage);
```

## MapService

`MapService` gère les opérations liées aux cartes.

```dart
// Convertir les points de polygone d'un bâtiment
final points = MapService.convertBuildingPolygonPoints(pointsPolygone);

// Obtenir les polygones des bâtiments pour un site
final polygones = MapService.getBuildingPolygons(idSite, batiments);

// Obtenir les dimensions d'une image
final dimensions = await MapService.getImageDimensions(urlImage);

// Créer une carte avec une image superposée
final carte = MapService.createMapWithOverlayImage(
  mapController: controleurCarte,
  center: LatLng(0, 0),
  zoom: 1.0,
  imageUrl: 'https://example.com/image.jpg',
  effectiveWidth: 100,
  effectiveHeight: 100,
  markers: marqueurs,
  polygons: polygones,
  onTap: (position, point) => gererTapCarte(position, point),
);

// Créer une carte avec une image en mémoire
final carte = MapService.createMapWithMemoryImage(
  mapController: controleurCarte,
  center: LatLng(0, 0),
  zoom: 1.0,
  imageBytes: octetsImage,
  effectiveWidth: 100,
  effectiveHeight: 100,
  markers: marqueurs,
  onTap: (position, point) => gererTapCarte(position, point),
);
```

## Exemple Complet

Voici un exemple complet montrant comment utiliser ces classes ensemble :

```dart
class MonWidget extends StatefulWidget {
  @override
  _MonWidgetState createState() => _MonWidgetState();
}

class _MonWidgetState extends State<MonWidget> {
  final Logger _logger = Logger('MonWidget');
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  int _etageId = 1;

  @override
  void initState() {
    super.initState();
    _chargerBaes();
  }

  Future<void> _chargerBaes() async {
    _logger.start('chargerBaes');
    
    try {
      // Charger les BAES de l'étage
      final baes = await BaesService.loadBaesForFloor(_etageId);
      
      // Convertir les BAES en marqueurs
      final markers = BaesService.convertBaesToMarkers(baes);
      
      setState(() {
        _markers = markers;
      });
      
      _logger.end('chargerBaes', success: true);
    } catch (e, stackTrace) {
      _logger.e('Erreur lors du chargement des BAES', e, stackTrace);
      _logger.end('chargerBaes', success: false, message: e.toString());
      
      UiUtils.showSnackBar(context, 'Erreur lors du chargement des BAES', isError: true);
    }
  }

  void _ajouterBaes(LatLng point) async {
    _logger.start('ajouterBaes');
    
    final nom = await UiUtils.showTextInputDialog(
      context,
      title: 'Nouveau BAES',
      hintText: 'Nom du BAES',
    );
    
    if (nom == null || nom.isEmpty) {
      _logger.end('ajouterBaes', success: false, message: 'Nom vide');
      return;
    }
    
    try {
      // Créer un BAES via l'API
      final baes = await BaesService.createBaes(nom, point, _etageId);
      
      if (baes != null) {
        setState(() {
          _markers.add(MapUtils.createBaesMarker(point));
        });
        
        UiUtils.showSnackBar(context, 'BAES "$nom" ajouté avec succès');
        _logger.end('ajouterBaes', success: true);
      } else {
        UiUtils.showSnackBar(context, 'Erreur lors de la création du BAES', isError: true);
        _logger.end('ajouterBaes', success: false, message: 'API a retourné null');
      }
    } catch (e, stackTrace) {
      _logger.e('Erreur lors de la création du BAES', e, stackTrace);
      _logger.end('ajouterBaes', success: false, message: e.toString());
      
      UiUtils.showSnackBar(context, 'Erreur lors de la création du BAES', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapService.createMapWithOverlayImage(
        mapController: _mapController,
        center: LatLng(0, 0),
        zoom: 1.0,
        imageUrl: 'https://example.com/image.jpg',
        effectiveWidth: 100,
        effectiveHeight: 100,
        markers: _markers,
        onTap: (position, point) => _ajouterBaes(point),
      ),
    );
  }
}
```

Ce guide devrait vous aider à comprendre comment utiliser les nouvelles classes dans votre code. N'hésitez pas à consulter la documentation des classes pour plus de détails.