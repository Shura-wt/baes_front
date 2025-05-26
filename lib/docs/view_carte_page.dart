part of '../main.dart';

/// Page permettant uniquement la visualisation des cartes, bâtiments, étages et BAES.
/// Cette page est en lecture seule et ne permet pas de modifier les données.
class ViewCartePage extends StatefulWidget {
  const ViewCartePage({super.key});

  @override
  State<ViewCartePage> createState() => _ViewCartePageState();
}

class _ViewCartePageState extends State<ViewCartePage> {
  // Static reference to the current instance of this state
  static _ViewCartePageState? _instance;

  final MapController _mapController = MapController();

  // Paramètres pour la vue globale du site
  double siteZoom = 13.0;

  // Dans CrsSimple, le centre est exprimé en "pixels". On initialise avec des valeurs sûres.
  LatLng siteCenter = const LatLng(45, 90); // milieu de 90x180
  Uint8List? uploadedSiteImage;
  ImageProvider? siteImage;

  // Valeurs par défaut adaptées aux bornes autorisées : hauteur ≤ 90, largeur ≤ 180.
  double siteEffectiveWidth = 180;
  double siteEffectiveHeight = 90;
  Map<String, dynamic> siteData = {};

  // Liste des sites disponibles pour l'utilisateur
  List<Site> userSites = [];

  // Site actuellement sélectionné
  Site? currentSite;
  bool isLoading = true;
  bool isDataLoading = false;

  // Paramètres pour la vue d'étage
  bool isFloorView = false;
  String currentBuilding = '';
  String currentFloor = '';
  double floorZoom = 13.0;
  LatLng floorCenter = const LatLng(45, 90);
  Uint8List? uploadedFloorImage;
  ImageProvider? floorImage;
  double floorEffectiveWidth = 180;
  double floorEffectiveHeight = 90;
  List<Marker> floorMarkers = [];

  // Add these new variables for error polling
  Timer? _errorPollingTimer;
  int _lastKnownErrorId = 0;
  List<HistoriqueErreur> _allErrors = [];

  @override
  void initState() {
    super.initState();

    // Set the static reference to this instance
    _instance = this;

    // Charger les données depuis l'API si aucune donnée n'est déjà chargée et qu'aucun chargement n'est en cours
    if (userSites.isEmpty && !isDataLoading) {
      _loadApiData();
    } else {
      // Préparer les données du site pour l'affichage
      _prepareSiteData();
    }

    // Initialize error polling
    _initializeErrorPolling();
  }

  @override
  void dispose() {
    // Cancel the timer when the widget is disposed
    _errorPollingTimer?.cancel();

    // Clear the static reference if it's this instance
    if (_instance == this) {
      _instance = null;
    }

    super.dispose();
  }

  /// Static method to refresh the map view
  static void refreshMapView() {
    if (_instance != null && _instance!.mounted) {
      // Update siteData with the latest error statuses
      _instance!._prepareSiteData();

      // Force UI refresh regardless of the current view
      _instance!.setState(() {
        // This empty setState will trigger a rebuild with the updated data
      });

      // If in floor view, also refresh the floor map
      if (_instance!.isFloorView) {
        _instance!
            ._loadFloorMap(_instance!.currentBuilding, _instance!.currentFloor);
      }
    }
  }

  /// Initialize error polling system
  Future<void> _initializeErrorPolling() async {
    // First, get all errors
    await _fetchAllErrors();

    // Then set up a timer to poll for new errors every 5 seconds
    _errorPollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchNewErrors();
    });
  }

  /// Fetch all errors at startup
  Future<void> _fetchAllErrors() async {
    final errors = await ErreurApi.getAllErrors();

    if (errors.isNotEmpty) {
      setState(() {
        _allErrors = errors;
        // Get the highest error ID
        _lastKnownErrorId =
            errors.map((e) => e.id).reduce((a, b) => a > b ? a : b);
      });

      // Update BAES status with these errors
      _updateBaesStatus(errors);
    }
  }

  // Store the latest known error for comparison
  HistoriqueErreur? _latestKnownError;

  // Flag to prevent multiple concurrent updates
  bool _isUpdatingErrors = false;

  /// Fetch the latest error and check if it's different from what we know
  Future<void> _fetchNewErrors() async {
    // If already updating, skip this cycle to prevent overlapping updates
    if (_isUpdatingErrors) {
      if (kDebugMode) {
        print("Skipping error update cycle - update already in progress");
      }
      return;
    }

    _isUpdatingErrors = true;

    try {
      // Get the latest error from the server
      final latestError = await ErreurApi.getLatestError();

      // If there's no latest error, nothing to do
      if (latestError == null) {
        if (kDebugMode) {
          print("No latest error found");
        }
        _isUpdatingErrors = false;
        return;
      }

      if (kDebugMode) {
        print(
            "Latest error: ID=${latestError.id}, solved=${latestError.isSolved}, ignored=${latestError.isIgnored}");
        if (_latestKnownError != null) {
          print(
              "Last known error: ID=${_latestKnownError!.id}, solved=${_latestKnownError!.isSolved}, ignored=${_latestKnownError!.isIgnored}");
        } else {
          print("No last known error");
        }
      }

      // Check if we need to fetch new errors
      bool needToFetchNewErrors = false;

      // If we don't have a latest known error yet, or if the latest error ID is different
      if (_latestKnownError == null ||
          _latestKnownError!.id != latestError.id) {
        needToFetchNewErrors = true;
        if (kDebugMode) {
          print("Need to fetch new errors: new error or different ID");
        }
      }
      // If the IDs are the same but the status has changed
      else if (_latestKnownError!.isSolved != latestError.isSolved ||
          _latestKnownError!.isIgnored != latestError.isIgnored) {
        needToFetchNewErrors = true;
        if (kDebugMode) {
          print("Need to fetch new errors: status changed");
        }
      }

      // Update our reference to the latest error
      _latestKnownError = latestError;

      // If we need to fetch new errors, do so
      if (needToFetchNewErrors) {
        // If we don't have a last known error ID yet, fetch all errors
        if (_lastKnownErrorId <= 0) {
          if (kDebugMode) {
            print("Fetching all errors (no last known ID)");
          }
          await _fetchAllErrors();
          return;
        }

        // Handle case where latest error ID is less than our last known ID
        // (this could happen if errors were deleted or if the server was reset)
        if (latestError.id < _lastKnownErrorId) {
          if (kDebugMode) {
            print(
                "Latest error ID (${latestError.id}) is less than last known ID ($_lastKnownErrorId). Fetching all errors.");
          }
          await _fetchAllErrors();
          return;
        }

        // Fetch all errors after the last known ID
        if (kDebugMode) {
          print("Fetching errors after ID $_lastKnownErrorId");
        }
        final newErrors = await ErreurApi.getErrorsAfter(_lastKnownErrorId);

        if (newErrors.isNotEmpty) {
          if (kDebugMode) {
            print("Found ${newErrors.length} new errors");
          }

          // Add the new errors to our list
          setState(() {
            _allErrors.addAll(newErrors);
            // Update the last known error ID
            _lastKnownErrorId =
                newErrors.map((e) => e.id).reduce((a, b) => a > b ? a : b);
          });

          // Update BAES status with the new errors
          _updateBaesStatus(newErrors);
        } else {
          if (kDebugMode) {
            print("No new errors found after ID $_lastKnownErrorId");
          }
        }
      } else {
        if (kDebugMode) {
          print("No need to fetch new errors");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error in _fetchNewErrors: $e");
      }
    } finally {
      // Always reset the flag when done, even if there was an error
      _isUpdatingErrors = false;
    }
  }

  // Flag to prevent multiple concurrent updates to BAES status
  bool _isUpdatingBaesStatus = false;

  /// Update BAES status based on errors
  void _updateBaesStatus(List<HistoriqueErreur> errors) {
    // If already updating, skip this update to prevent overlapping updates
    if (_isUpdatingBaesStatus) {
      if (kDebugMode) {
        print("Skipping BAES status update - update already in progress");
      }
      return;
    }

    _isUpdatingBaesStatus = true;

    try {
      // Group errors by BAES ID
      final Map<int, List<HistoriqueErreur>> errorsByBaes = {};

      for (var error in errors) {
        if (!errorsByBaes.containsKey(error.baesId)) {
          errorsByBaes[error.baesId] = [];
        }
        errorsByBaes[error.baesId]!.add(error);
      }

      // Update each BAES with its errors
      for (var baesId in errorsByBaes.keys) {
        // Find the BAES in the allBaes list
        final baesIndex = Baes.allBaes.indexWhere((b) => b.id == baesId);

        if (baesIndex >= 0) {
          // Create a new BAES with updated errors
          final baes = Baes.allBaes[baesIndex];
          final updatedBaes = Baes(
            id: baes.id,
            name: baes.name,
            position: baes.position,
            etageId: baes.etageId,
            erreurs: errorsByBaes[baesId]!,
          );

          // Replace the old BAES with the updated one
          Baes.allBaes[baesIndex] = updatedBaes;
        }
      }

      // Update siteData with the latest error information
      _prepareSiteData();

      // Force UI refresh regardless of the current view
      setState(() {
        // This empty setState will trigger a rebuild with the updated data
      });

      // Refresh the UI if we're in floor view
      if (isFloorView) {
        _loadFloorMap(currentBuilding, currentFloor);
      }

      // Refresh the drawer UI to show the updated errors
      _LeftDrawerState.refreshDrawer();
    } finally {
      // Always reset the flag when done, even if there was an error
      _isUpdatingBaesStatus = false;
    }
  }

  // Flag to prevent multiple concurrent updates to floor map
  bool _isLoadingFloorMap = false;

  /// Charge la carte d'un étage en utilisant les données du site actuel
  Future<void> _loadFloorMap(String buildingName, String floorName) async {
    // If already loading, skip this update to prevent overlapping updates
    if (_isLoadingFloorMap) {
      if (kDebugMode) {
        print("Skipping floor map load - load already in progress");
      }
      return;
    }

    _isLoadingFloorMap = true;

    try {
      if (siteData.isNotEmpty &&
          siteData['batiments'] != null &&
          siteData['batiments'][buildingName] != null &&
          siteData['batiments'][buildingName]['etages'] != null &&
          siteData['batiments'][buildingName]['etages'][floorName] != null) {
        Map floorData =
            siteData['batiments'][buildingName]['etages'][floorName];
        await _loadFloorView(buildingName, floorName, floorData);
      } else {
        if (kDebugMode) {
          print(
              "Impossible de charger la carte: données manquantes pour $buildingName/$floorName");
        }
      }
    } finally {
      // Always reset the flag when done, even if there was an error
      _isLoadingFloorMap = false;
    }
  }

  /// Charge les données depuis l'API
  Future<void> _loadApiData() async {
    // Marquer le début du chargement des données
    setState(() {
      isLoading = true;
      isDataLoading = true;
    });

    try {
      // Récupérer les données générales de l'utilisateur
      userSites = await getGeneralInfos(context);

      if (userSites.isNotEmpty) {
        // Vérifier s'il y a un site sélectionné dans le SiteProvider
        final siteProvider = Provider.of<SiteProvider>(context, listen: false);
        final selectedSite = siteProvider.selectedSite;

        if (selectedSite != null) {
          // Trouver le site complet correspondant au site sélectionné
          currentSite = userSites.firstWhere(
            (site) => site.id == selectedSite.id,
            orElse: () => userSites.first,
          );
        } else {
          // Sélectionner le premier site par défaut
          currentSite = userSites.first;
          // Mettre à jour le site sélectionné dans le SiteProvider
          if (currentSite != null) {
            final siteAssociation = SiteAssociation(
              id: currentSite!.id,
              name: currentSite!.name,
              roles: [],
            );
            siteProvider.setSelectedSite(siteAssociation);
          }
        }

        // Préparer les données du site pour l'affichage
        _prepareSiteData();

        // Charger la carte du site
        await _loadSiteMap();
      } else {
        // L'utilisateur n'a pas de sites, ne pas créer de site par défaut
        currentSite = null;
      }

      // Marquer la fin du chargement des données
      if (mounted) {
        setState(() {
          isLoading = false;
          isDataLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors du chargement des données: $e");
      }
      // Marquer la fin du chargement même en cas d'erreur
      if (mounted) {
        setState(() {
          isLoading = false;
          isDataLoading = false;
        });
      }
    }
  }

  /// Prépare les données du site pour l'affichage
  void _prepareSiteData() {
    if (currentSite == null) return;

    // Créer une structure de données similaire à celle utilisée précédemment
    Map<String, dynamic> batimentsData = {};

    for (var batiment in currentSite!.batiments) {
      // Préparer les données des étages
      Map<String, dynamic> etagesData = {};

      for (var etage in batiment.etages) {
        // Préparer les données des BAES
        Map<String, dynamic> baesData = {};

        for (var baes in etage.baes) {
          // Debug: Print the position data for each BAES
          print("BAES ID: ${baes.id}, Position: ${baes.position}");

          // Check if position contains lat/lng directly or under latitude/longitude keys
          var lat = baes.position['lat'] ?? baes.position['latitude'];
          var lng = baes.position['lng'] ?? baes.position['longitude'];

          // Debug: Print the extracted lat/lng values
          print("Extracted lat: $lat, lng: $lng");

          baesData[baes.id.toString()] = {
            'lat': lat,
            'lng': lng,
            // Check for connection errors in both ways:
            // 1. Direct boolean field in BAES position data
            // 2. Error type "connection" or "erreur_connexion" in erreurs list (only active errors)
            'status_connection':
                (baes.position['status_connection'] ?? false) ||
                    baes.erreurs.any((e) =>
                        (e.typeErreur == 'connection' ||
                            e.typeErreur == 'erreur_connexion') &&
                        !e.isSolved &&
                        !e.isIgnored),
            // Add erreurs to the baesData so they can be accessed in the UI
            'erreurs': baes.erreurs.map((e) => e.toJson()).toList(),
            // Add erreur_batterie field based on battery errors in erreurs list (only active errors)
            'erreur_batterie': baes.erreurs.any((e) =>
                (e.typeErreur == 'battery' ||
                    e.typeErreur == 'erreur_batterie') &&
                !e.isSolved &&
                !e.isIgnored),
            // Add fields to track if any errors are ignored or all are solved
            'any_error_ignored':
                !baes.erreurs.any((e) => !e.isSolved && !e.isIgnored) &&
                    baes.erreurs.any((e) => e.isIgnored),
            'all_errors_solved':
                baes.erreurs.isEmpty || baes.erreurs.every((e) => e.isSolved),

            'conection_error_ignored': baes.erreurs.any((e) =>
                (e.typeErreur == 'connection' ||
                    e.typeErreur == 'erreur_connexion') &&
                e.isIgnored),
            'battery_error_ignored': baes.erreurs.any((e) =>
                (e.typeErreur == 'battery' ||
                    e.typeErreur == 'erreur_batterie') &&
                e.isIgnored),

            'evryErrorIgnored':
                baes.erreurs.isEmpty || baes.erreurs.every((e) => e.isSolved),
          };
        }

        etagesData[etage.name] = {
          'id': etage.id,
          'baes': baesData,
        };
      }

      // Préparer les points du polygone du bâtiment
      List<Map<String, dynamic>> polygonPoints = [];

      // Traiter les points du polygone en fonction de leur type
      if (batiment.polygonPoints is List) {
        // Cas où polygonPoints est une liste

        for (var point in batiment.polygonPoints) {
          if (point is Map &&
              point.containsKey('latitude') &&
              point.containsKey('longitude')) {
            polygonPoints.add({
              'lat': point['latitude'],
              'lng': point['longitude'],
            });
          }
        }
      } else if (batiment.polygonPoints is Map) {
        // Cas où polygonPoints est une map

        // Vérifier si la map contient une liste de points
        if (batiment.polygonPoints.containsKey('points') &&
            batiment.polygonPoints['points'] is List) {
          List pointsList = batiment.polygonPoints['points'];

          for (var point in pointsList) {
            if (point is Map &&
                point.containsKey('latitude') &&
                point.containsKey('longitude')) {
              polygonPoints.add({
                'lat': point['latitude'],
                'lng': point['longitude'],
              });
            } else if (point is List && point.length >= 2) {
              // Format [latitude, longitude]
              polygonPoints.add({
                'lat': point[0],
                'lng': point[1],
              });
            }
          }
        } else {
          // Essayer de trouver des coordonnées directement dans la map
          Map<String, dynamic> polygonMap =
              batiment.polygonPoints as Map<String, dynamic>;
          List<Map<String, dynamic>> extractedPoints = [];

          // Parcourir toutes les clés de la map pour trouver des paires de coordonnées
          polygonMap.forEach((key, value) {
            if (key.startsWith('point') && value is Map) {
              if (value.containsKey('latitude') &&
                  value.containsKey('longitude')) {
                extractedPoints.add({
                  'lat': value['latitude'],
                  'lng': value['longitude'],
                });
              }
            }
          });

          // Si on a trouvé des points, les ajouter à polygonPoints
          if (extractedPoints.isNotEmpty) {
            polygonPoints.addAll(extractedPoints);
          } else {
            // Afficher les clés de la map pour le débogage
            // Essayer d'extraire des coordonnées de la structure de la map
            if (polygonMap.containsKey('coordinates') &&
                polygonMap['coordinates'] is List) {
              List coords = polygonMap['coordinates'];

              for (var coord in coords) {
                if (coord is List && coord.length >= 2) {
                  // Format [longitude, latitude]
                  polygonPoints.add({
                    'lat': coord[1],
                    'lng': coord[0],
                  });
                }
              }
            }
          }
        }
      } else {
        // Essayer de convertir en chaîne et analyser
        try {
          String pointsStr = batiment.polygonPoints.toString();
          if (pointsStr.contains('latitude') &&
              pointsStr.contains('longitude')) {}
        } catch (e) {
          if (kDebugMode) {
            print("Erreur lors de la tentative d'analyse de polygonPoints: $e");
          }
        }
      }

      batimentsData[batiment.name] = {
        'id': batiment.id,
        'polygonPoints': polygonPoints,
        'etages': etagesData,
      };
    }

    siteData = {
      'id': currentSite!.id,
      'nom': currentSite!.name,
      'batiments': batimentsData,
    };
  }

  /// Charge la carte du site depuis l'API
  Future<void> _loadSiteMap() async {
    if (currentSite == null) return;

    try {
      // Chercher la carte du site dans la liste statique
      Carte? siteCarte = Carte.allCartes.firstWhere(
        (carte) => carte.siteId == currentSite!.id,
        orElse: () => throw Exception("Carte non trouvée"),
      );

      // Récupérer l'image de la carte depuis l'URL
      // Vérifier si le chemin contient déjà l'URL de base pour éviter la duplication
      final String url = siteCarte.chemin.startsWith('http')
          ? siteCarte.chemin
          : Config.baseUrl + siteCarte.chemin;

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        uploadedSiteImage = response.bodyBytes;
        siteImage = MemoryImage(uploadedSiteImage!);

        // Mettre à jour les paramètres de la carte
        siteZoom = siteCarte.zoom;
        siteCenter = LatLng(siteCarte.centerLat, siteCarte.centerLng);

        // Décodage de l'image pour obtenir ses dimensions
        ui.decodeImageFromList(uploadedSiteImage!, (ui.Image img) {
          double originalWidth = img.width.toDouble();
          double originalHeight = img.height.toDouble();
          // On choisit un scaleFactor pour que la hauteur effective ne dépasse pas 90 et la largeur 180.
          double scaleFactor = min(90 / originalHeight, 180 / originalWidth);
          setState(() {
            siteEffectiveWidth = originalWidth * scaleFactor;
            siteEffectiveHeight = originalHeight * scaleFactor;
            siteCenter = LatLng(siteCarte.centerLat, siteCarte.centerLng);
          });
          // Wrap the move call in a try-catch block to handle the case where the map isn't ready yet
          try {
            // Check if the map controller is ready before using it
            _mapController.move(siteCenter, siteZoom);
          } catch (e) {
            if (kDebugMode) {
              print("Error moving map: $e");
            }
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors du chargement de la carte du site: $e");
      }
    }
  }

  /// Vérifie si un point se trouve dans un polygone.
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersectCount = 0;
    for (int j = 0; j < polygon.length; j++) {
      LatLng vertex1 = polygon[j];
      LatLng vertex2 = polygon[(j + 1) % polygon.length];
      if ((vertex1.longitude > point.longitude) !=
          (vertex2.longitude > point.longitude)) {
        double slope = (vertex2.latitude - vertex1.latitude) /
            (vertex2.longitude - vertex1.longitude);
        double intersectLat =
            vertex1.latitude + slope * (point.longitude - vertex1.longitude);
        if (point.latitude < intersectLat) {
          intersectCount++;
        }
      }
    }
    return (intersectCount % 2) == 1;
  }

  /// Gère le tap sur la carte.
  /// En mode site, si le point tapé est dans un polygone, on charge la vue d'un étage.
  void _onMapTap(TapPosition tapPosition, LatLng latlng) {
    if (!isFloorView && siteData.isNotEmpty && siteData['batiments'] != null) {
      Map batiments = siteData['batiments'];
      batiments.forEach((buildingName, buildingData) {
        List<dynamic> pointsData = buildingData['polygonPoints'];
        List<LatLng> polygonPoints = pointsData.map((point) {
          // Add null checks for lat and lng values
          num? latValue = point['lat'] as num?;
          num? lngValue = point['lng'] as num?;

          // Use default values (0.0) if lat or lng is null
          double lat = latValue?.toDouble() ?? 0.0;
          double lng = lngValue?.toDouble() ?? 0.0;

          return LatLng(lat, lng);
        }).toList();
        if (_isPointInPolygon(latlng, polygonPoints)) {
          // Pour cet exemple, on charge le premier étage disponible du bâtiment.
          Map etages = buildingData['etages'];
          if (etages.isNotEmpty) {
            String floorName = etages.keys.first;
            _loadFloorView(buildingName, floorName, etages[floorName]);
          }
        }
      });
    }
  }

  /// Charge la vue d'un étage (zoom, centre, image et markers) depuis l'API.
  Future<void> _loadFloorView(
      String buildingName, String floorName, Map floorData) async {
    setState(() {
      currentBuilding = buildingName;
      currentFloor = floorName;
      isFloorView = true;
    });

    // We don't need to fetch errors here as it creates a circular dependency
    // _fetchAllErrors() -> _updateBaesStatus() -> _loadFloorMap() -> _loadFloorView() -> _fetchAllErrors()

    try {
      // Récupérer l'ID de l'étage
      int etageId = floorData['id'];

      // Chercher la carte de l'étage dans la liste statique
      Carte? etageCarte = Carte.allCartes.firstWhere(
        (carte) => carte.etageId == etageId,
        orElse: () => throw Exception("Carte d'étage non trouvée"),
      );

      // Mettre à jour les paramètres de la carte
      floorZoom = etageCarte.zoom;
      floorCenter = LatLng(etageCarte.centerLat, etageCarte.centerLng);

      // Récupérer l'image de la carte depuis l'URL
      // Vérifier si le chemin contient déjà l'URL de base pour éviter la duplication
      final String url = etageCarte.chemin.startsWith('http')
          ? etageCarte.chemin
          : Config.baseUrl + etageCarte.chemin;

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        uploadedFloorImage = response.bodyBytes;
        floorImage = MemoryImage(uploadedFloorImage!);

        // Décodage de l'image pour obtenir ses dimensions
        ui.decodeImageFromList(uploadedFloorImage!, (ui.Image img) {
          double originalWidth = img.width.toDouble();
          double originalHeight = img.height.toDouble();
          double scaleFactor = min(90 / originalHeight, 180 / originalWidth);

          setState(() {
            floorEffectiveWidth = originalWidth * scaleFactor;
            floorEffectiveHeight = originalHeight * scaleFactor;
          });

          // Wrap the move call in a try-catch block to handle the case where the map isn't ready yet
          try {
            // Check if the map controller is ready before using it
            if (_mapController.camera != null) {
              _mapController.move(floorCenter, floorZoom);
            } else {
              if (kDebugMode) {
                print(
                    "MapController not ready yet, skipping move call in floor view");
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print("Error moving map in floor view: $e");
            }
          }

          // Charger les markers
          List<Marker> markers = [];
          if (floorData['baes'] != null) {
            Map baes = floorData['baes'];

            // Debug: Print the BAES data
            print("BAES data in _loadFloorView: $baes");

            baes.forEach((key, bae) {
              // Debug: Print individual BAES data
              print("Processing BAES $key: $bae");

              // Add null checks for lat and lng values
              num? latValue = bae['lat'] as num?;
              num? lngValue = bae['lng'] as num?;

              // If lat/lng are null, try latitude/longitude
              if (latValue == null && bae['latitude'] != null) {
                latValue = bae['latitude'] as num?;
              }
              if (lngValue == null && bae['longitude'] != null) {
                lngValue = bae['longitude'] as num?;
              }

              // Use default values (0.0) if lat or lng is null
              double mLat = latValue?.toDouble() ?? 0.0;
              double mLng = lngValue?.toDouble() ?? 0.0;
              // Check for connection errors in both ways:
              // 1. Direct boolean field in BAES data
              // 2. Error type "connection" or "erreur_connexion" in erreurs list
              bool statusConnection = (bae['status_connection'] ?? false) ||
                  (bae['erreurs'] != null &&
                      (bae['erreurs'] as List).any((e) =>
                          (e['type_erreur'] == 'connection' ||
                              e['type_erreur'] == 'erreur_connexion') &&
                          !(e['is_solved'] == true ||
                              e['is_ignored'] == true)));

              // Check for battery errors in both ways:
              // 1. Direct boolean field in BAES data
              // 2. Error type "battery" or "erreur_batterie" in erreurs list
              bool batteryError = bae['erreur_batterie'] == true ||
                  (bae['erreurs'] != null &&
                      (bae['erreurs'] as List).any((e) =>
                          (e['type_erreur'] == 'battery' ||
                              e['type_erreur'] == 'erreur_batterie') &&
                          !(e['is_solved'] == true ||
                              e['is_ignored'] == true)));

              // Use the pre-calculated values from _prepareSiteData
              bool evryErrorIgnored = bae['any_error_ignored'] ?? false;
              bool allErrorsSolved = bae['all_errors_solved'] ?? true;
              bool conectionErrorIgnored =
                  bae['conection_error_ignored'] ?? false;
              bool batteryErrorIgnored = bae['battery_error_ignored'] ?? false;

              // Debug: Print the coordinates
              print("BAES $key coordinates: lat=$mLat, lng=$mLng");

              // Skip BAES with zero coordinates (likely missing data)
              if (mLat == 0.0 && mLng == 0.0) {
                print("Skipping BAES $key due to zero coordinates");
                return; // Skip this iteration
              }

              // Pour tester, nous utilisons directement les valeurs enregistrées
              double displayLat = mLat;
              double displayLng = mLng;

              markers.add(
                Marker(
                  point: LatLng(displayLat, displayLng),
                  width: 30,
                  height: 30,
                  child: GestureDetector(
                    onTap: () {
                      // Show a dialog with BAES information
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Information du bloc'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Site: ${currentSite!.name}'),
                                Text('Bâtiment: $buildingName'),
                                Text('Étage: $floorName'),
                                Text('ID du bloc: $key'),
                                Row(
                                  children: [
                                    const Text(
                                      'Statut: ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    Tooltip(
                                      message: "Connexion",
                                      child: Icon(
                                        Icons.wifi,
                                        color: statusConnection
                                            ? Colors.red
                                            : conectionErrorIgnored
                                                ? Colors.orange
                                                : Colors.green,
                                        size: 16,
                                      ),
                                    ),
                                    Text(statusConnection
                                        ? ' Déconnecté'
                                        : ' Connecté'),
                                    const SizedBox(width: 8),
                                    Tooltip(
                                      message: "Etat batterie",
                                      child: Icon(
                                        // Check for battery errors in both ways:
                                        // 1. Direct boolean field in BAES data
                                        // 2. Error type "battery" or "erreur_batterie" in erreurs list
                                        batteryError
                                            ? Icons.battery_unknown_outlined
                                            : Icons.battery_full,
                                        color: batteryError
                                            ? Colors.red
                                            : batteryErrorIgnored
                                                ? Colors.orange
                                                : Colors.green,
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Fermer'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Icon(
                      Icons.lightbulb,
                      color: (statusConnection || batteryError)
                          ? Colors.red
                          : evryErrorIgnored
                              ? Colors.orange
                              : Colors.green,
                      size: 30,
                    ),
                  ),
                ),
              );
              // Debug: Print marker added
              print(
                  "Added marker for BAES $key at lat=$displayLat, lng=$displayLng");
            });
          }

          setState(() {
            floorMarkers = markers;
          });
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors du chargement de la carte d'étage: $e");
      }
    }
  }

  /// Retour à la vue globale du site.
  void _backToSiteView() {
    setState(() {
      isFloorView = false;
    });

    // Wrap the move call in a try-catch block to handle the case where the map isn't ready yet
    try {
      // Check if the map controller is ready before using it
      if (_mapController.camera != null) {
        _mapController.move(siteCenter, siteZoom);
      } else {
        if (kDebugMode) {
          print(
              "MapController not ready yet, skipping move call in back to site view");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error moving map in back to site view: $e");
      }
    }
  }

  /// Construit la liste des polygones à partir du JSON.
  List<Polygon> _buildPolygones() {
    List<Polygon> polygons = [];

    if (siteData.isNotEmpty && siteData['batiments'] != null) {
      Map batiments = siteData['batiments'];

      batiments.forEach((buildingName, buildingData) {
        List<dynamic> pointsData = buildingData['polygonPoints'] ?? [];

        // Vérifier que pointsData n'est pas vide avant de créer un polygon
        if (pointsData.isNotEmpty) {
          // Transformation des coordonnées pour les adapter au système de coordonnées de la carte

          // Calculer les valeurs min et max pour normaliser les coordonnées
          double minLat = double.infinity;
          double maxLat = double.negativeInfinity;
          double minLng = double.infinity;
          double maxLng = double.negativeInfinity;

          for (var point in pointsData) {
            if (point is Map &&
                point.containsKey('lat') &&
                point.containsKey('lng')) {
              // Add null checks for lat and lng values
              num? latValue = point['lat'] as num?;
              num? lngValue = point['lng'] as num?;

              // Use default values (0.0) if lat or lng is null
              double lat = latValue?.toDouble() ?? 0.0;
              double lng = lngValue?.toDouble() ?? 0.0;

              minLat = min(minLat, lat);
              maxLat = max(maxLat, lat);
              minLng = min(minLng, lng);
              maxLng = max(maxLng, lng);
            }
          }

          // Si nous avons des valeurs valides, normaliser les coordonnées
          if (minLat != double.infinity &&
              maxLat != double.negativeInfinity &&
              minLng != double.infinity &&
              maxLng != double.negativeInfinity) {
            // Créer trois versions des points avec différentes approches de normalisation
            List<LatLng> originalPoints = [];
            List<LatLng> normalizedPoints = [];
            List<LatLng> fixedPoints = [];

            for (var point in pointsData) {
              if (point is Map &&
                  point.containsKey('lat') &&
                  point.containsKey('lng')) {
                // Add null checks for lat and lng values
                num? latValue = point['lat'] as num?;
                num? lngValue = point['lng'] as num?;

                // Use default values (0.0) if lat or lng is null
                double lat = latValue?.toDouble() ?? 0.0;
                double lng = lngValue?.toDouble() ?? 0.0;

                // Points originaux
                originalPoints.add(LatLng(lat, lng));

                // Points normalisés (0-100% de la taille de l'image)
                double normalizedLat =
                    (lat - minLat) / (maxLat - minLat) * siteEffectiveHeight;
                double normalizedLng =
                    (lng - minLng) / (maxLng - minLng) * siteEffectiveWidth;
                normalizedPoints.add(LatLng(normalizedLat, normalizedLng));

                // Approche fixe: utiliser des coordonnées dans une plage visible
                // Utiliser une plage de 10-80 pour s'assurer que les polygones sont visibles
                double fixedLat =
                    10 + (70 * (lat - minLat) / (maxLat - minLat));
                double fixedLng =
                    10 + (70 * (lng - minLng) / (maxLng - minLng));
                fixedPoints.add(LatLng(fixedLat, fixedLng));
              }
            }

            // Ajouter uniquement la version rouge des polygones (originale)
            if (originalPoints.isNotEmpty) {
              // Version avec coordonnées originales (en rouge)
              polygons.add(
                Polygon(
                  points: originalPoints,
                  color: Colors.green.withOpacity(0.3),
                  borderColor: Colors.green,
                  borderStrokeWidth: 2,
                ),
              );
            }
          }
        }
      });
    }

    return polygons;
  }

  @override
  Widget build(BuildContext context) {
    // Si nous sommes en chargement, afficher un indicateur de progression
    if (isLoading) {
      return GradiantBackground.getSafeAreaGradiant(
        context,
        const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Si nous sommes en mode site et qu'aucun site n'est sélectionné ou qu'aucune image n'est disponible, on affiche un message.
    if (!isFloorView && (currentSite == null || siteImage == null)) {
      return GradiantBackground.getSafeAreaGradiant(
        context,
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                currentSite == null
                    ? "Vous n'avez pas de site. Veuillez en créer un."
                    : "Aucune carte disponible pour le site",
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              if (currentSite == null &&
                  (Provider.of<AuthProvider>(context).isAdmin ||
                      Provider.of<AuthProvider>(context).isSuperAdmin))
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: ElevatedButton(
                    onPressed: () {
                      // Afficher la boîte de dialogue pour créer un nouveau site
                      final TextEditingController siteController =
                          TextEditingController();
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text("Créer un nouveau site"),
                            content: TextField(
                              controller: siteController,
                              decoration: const InputDecoration(
                                  labelText: "Nom du site"),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Annuler"),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  String newSiteName =
                                      siteController.text.trim();
                                  if (newSiteName.isNotEmpty) {
                                    try {
                                      final siteProvider =
                                          Provider.of<SiteProvider>(context,
                                              listen: false);
                                      final newSite = await siteProvider
                                          .createSite(newSiteName);
                                      // Sélectionner le nouveau site
                                      siteProvider.setSelectedSite(newSite);
                                      // Recharger les données
                                      _loadApiData();
                                    } catch (e) {
                                      // Erreur lors de la création du site
                                      if (kDebugMode) {
                                        print(
                                            "Erreur lors de la création du site: $e");
                                      }
                                    }
                                    Navigator.pop(context);
                                  }
                                },
                                child: const Text("Créer"),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: const Text("Créer un site"),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
        // Drawer removed temporarily due to class not found error
        // drawer: const LeftDrawer(),
        body: Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            // Utilisation de CrsSimple pour un repère "pixelisé".
            crs: const CrsSimple(),
            initialCenter: isFloorView ? floorCenter : siteCenter,
            initialZoom: isFloorView ? floorZoom : siteZoom,
            maxZoom: isFloorView ? floorZoom + 10 : siteZoom + 10,
            minZoom: isFloorView ? floorZoom - 10 : siteZoom - 10,
            onTap: _onMapTap,
          ),
          children: [
            // Affichage de l'image de fond (site ou étage)
            if (isFloorView && floorImage != null)
              OverlayImageLayer(
                overlayImages: [
                  OverlayImage(
                    bounds: LatLngBounds(
                      const LatLng(0, 0),
                      LatLng(floorEffectiveHeight, floorEffectiveWidth),
                    ),
                    opacity: 1.0,
                    imageProvider: floorImage!,
                  ),
                ],
              )
            else if (!isFloorView && siteImage != null)
              OverlayImageLayer(
                overlayImages: [
                  OverlayImage(
                    bounds: LatLngBounds(
                      const LatLng(0, 0),
                      LatLng(siteEffectiveHeight, siteEffectiveWidth),
                    ),
                    opacity: 1.0,
                    imageProvider: siteImage!,
                  ),
                ],
              ),
            // En vue globale, affichage des polygones (bâtiments)
            if (!isFloorView)
              PolygonLayer(
                polygons: _buildPolygones(),
                // Assurer que les polygones sont bien visibles
                polygonCulling:
                    false, // Désactiver le culling pour s'assurer que tous les polygones sont rendus
              ),
            // En vue d'étage, affichage des markers (BAES)
            if (isFloorView)
              MarkerLayer(
                markers: floorMarkers,
              ),
          ],
        ),
        // Menu déroulant pour la sélection d'étage (affiché uniquement en mode étage)
        if (isFloorView)
          Positioned(
            top: 20,
            right: 20,
            left: 20,
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _backToSiteView,
                    tooltip: "Retour à la vue site",
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: currentFloor.isNotEmpty ? currentFloor : null,
                        hint: const Text("Sélectionner un étage"),
                        items: _buildFloorDropdownItems(),
                        onChanged: (newValue) {
                          if (newValue != null && newValue != currentFloor) {
                            // Lorsque l'utilisateur change d'étage, recharger la vue d'étage pour le bâtiment courant.
                            if (siteData.isNotEmpty &&
                                siteData['batiments'] != null &&
                                currentBuilding.isNotEmpty) {
                              Map buildingData =
                                  siteData['batiments'][currentBuilding];
                              if (buildingData['etages'] != null) {
                                Map etages = buildingData['etages'];
                                if (etages.containsKey(newValue)) {
                                  _loadFloorView(currentBuilding, newValue,
                                      etages[newValue]);
                                }
                              }
                            }
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Menu déroulant pour la sélection de site (affiché uniquement en mode site)
        if (!isFloorView && userSites.length > 1)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              width: 150, // Largeur réduite
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<int>(
                isExpanded: true,
                value: currentSite?.id,
                hint: const Text("Sélectionner un site"),
                items: userSites.map((site) {
                  return DropdownMenuItem<int>(
                    value: site.id,
                    child: Text(site.name),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null && newValue != currentSite?.id) {
                    // Changer de site
                    setState(() {
                      currentSite =
                          userSites.firstWhere((site) => site.id == newValue);
                      _prepareSiteData();
                      _loadSiteMap();
                    });
                  }
                },
              ),
            ),
          ),
      ],
    ));
  }

  /// Construit la liste des étages disponibles pour le bâtiment courant.
  List<DropdownMenuItem<String>> _buildFloorDropdownItems() {
    List<DropdownMenuItem<String>> items = [];
    if (siteData.isNotEmpty && currentBuilding.isNotEmpty) {
      Map buildingData = siteData['batiments'][currentBuilding];
      if (buildingData['etages'] != null) {
        Map etages = buildingData['etages'];
        etages.forEach((key, value) {
          items.add(DropdownMenuItem(
            value: key,
            child: Text(key),
          ));
        });
      }
    }
    return items;
  }
}
