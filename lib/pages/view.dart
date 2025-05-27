part of '../main.dart';

class VisualisationCartePage extends StatefulWidget {
  const VisualisationCartePage({Key? key}) : super(key: key);

  @override
  _VisualisationCartePageState createState() => _VisualisationCartePageState();
}

class _VisualisationCartePageState extends State<VisualisationCartePage> {
  /**************************************************************************************************/
  HistoriqueErreur? _latestKnownError;
  bool _isUpdatingErrors = false;
  bool _isUpdatingBaesStatus = false;

  // Variables for BAES selection and management
  bool _isAddingBaes = false;
  bool _isFloorMode = false;
  Baes? _selectedBaes;
  int? _selectedBaesIndex;
  List<Etage> _batimentEtages = [];

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
  /**************************************************************************************************/

  final MapController _siteController = MapController();
  final MapController _floorController = MapController();
  SiteProvider? _siteProv;

  bool _isFloor = false;
  Carte? _siteCarte;
  double _siteEffW = 180, _siteEffH = 90;
  ImageProvider? _siteImage;
  List<Polygon> _sitePolys = [];

  Batiment? _selBat;
  int? _selFloorId;
  List<Etage> _floors = [];
  List<Marker> _floorMarkers = [];
  Carte? _floorCarte;
  double _floorEffW = 180, _floorEffH = 90;
  ImageProvider? _floorImage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _siteProv = Provider.of<SiteProvider>(context, listen: false);
      _siteProv!.addListener(_onSiteChanged);
      _loadSite();
    });
    if (userSites.isEmpty && !isDataLoading) {
      _loadApiData();
    } else {
      // Préparer les données du site pour l'affichage
      _prepareSiteData();
    }

    _initializeErrorPolling();
  }

  @override
  void dispose() {
    _siteProv?.removeListener(_onSiteChanged);
    super.dispose();
  }

  Future<void> _initializeErrorPolling() async {
    // First, get all errors
    await _fetchAllErrors();

    // Then set up a timer to poll for new errors every 5 seconds
    _errorPollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchNewErrors();
    });
  }

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

  bool _isLoadingFloorMap = false;

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

  void _onSiteChanged() {
    setState(() {
      _isFloor = false;
      _siteCarte = null;
      _siteImage = null;
      _sitePolys.clear();
      _selBat = null;
      _selFloorId = null;
      _floors.clear();
      _floorMarkers.clear();
      _floorCarte = null;
      _floorImage = null;
    });
    _loadSite();
  }

  Future<void> _loadSite() async {
    final sel = _siteProv!.selectedSite;
    if (sel == null) return;
    final carte = await APICarte.getCarteBySiteId(sel.id);
    if (carte == null) return;

    // Télécharge et décode image
    final bytes = (await http.get(Uri.parse(carte.chemin))).bodyBytes;
    ui.decodeImageFromList(bytes, (img) {
      final w = img.width.toDouble(), h = img.height.toDouble();
      final scale = min(90 / h, 180 / w);
      setState(() {
        _siteEffW = w * scale;
        _siteEffH = h * scale;
        _siteCarte = carte;
        _siteImage = MemoryImage(bytes);
        // Polygones
        final site =
            _siteProv!.getCompleteSiteById(_siteProv!.selectedSite!.id)!;
        _sitePolys = site.batiments.map((bat) {
          final pts = (bat.polygonPoints['points'] as List)
              .map((p) => LatLng(p[0], p[1]))
              .toList();
          return Polygon(
            points: pts,
            color: Colors.green.withOpacity(0.3),
            borderColor: Colors.green,
            borderStrokeWidth: 2,
          );
        }).toList();
      });
    });
  }

  // Met à jour les marqueurs BAES, en mettant en évidence celui qui est sélectionné
  void _updateBaesMarkers() {
    if (_selFloorId == null) return;

    setState(() {
      _floorMarkers =
          Baes.allBaes.where((b) => b.etageId == _selFloorId).map((b) {
        final hasErr = b.erreurs.any((e) => !e.isSolved && !e.isIgnored);
        final hasIgnoredErr = b.erreurs.any((e) => e.isIgnored);
        final isSelected = _selectedBaes != null && _selectedBaes!.id == b.id;

        return Marker(
          point: LatLng(b.position['lat'], b.position['lng']),
          width: 30,
          height: 30,
          child: GestureDetector(
            onTap: () => _handleBaesMarkerTap(b, Baes.allBaes.indexOf(b)),
            child: Icon(
              Icons.lightbulb,
              color: isSelected
                  ? Colors.orange
                  : (hasErr
                      ? Colors.red
                      : (hasIgnoredErr ? Colors.orange : Colors.green)),
            ),
          ),
        );
      }).toList();
    });
  }

  void _handleBaesMarkerTap(Baes baes, int markerIndex) {
    // Si le mode placement BAES est activé
    if (_isAddingBaes && _isFloorMode && _selFloorId != null) {
      setState(() {
        // Si un BAES est déjà sélectionné, le désélectionner
        if (_selectedBaes != null) {
          // Si c'est le même BAES, le désélectionner
          if (_selectedBaes!.id == baes.id) {
            _selectedBaes = null;
            _selectedBaesIndex = null;
            return;
          }
        }

        // Sélectionner le BAES cliqué
        _selectedBaes = baes;
        _selectedBaesIndex = markerIndex;

        // Mettre à jour le marqueur pour le rendre orange (sélectionné)
        _updateBaesMarkers();
      });
    } else if (_isFloorMode && _selFloorId != null && !_isAddingBaes) {
      // Si on n'est pas en mode placement BAES, afficher les informations du BAES
      // Trouver le nom de l'étage actuel
      String floorName = "";
      for (var floor in _batimentEtages) {
        if (floor.id == _selFloorId) {
          floorName = floor.name;
          break;
        }
      }

      // Vérifier s'il y a des erreurs de connexion actives (non résolues et non ignorées)
      bool statusConnection = baes.erreurs.any((e) =>
          (e.typeErreur == 'connection' ||
              e.typeErreur == 'erreur_connexion') &&
          !e.isSolved &&
          !e.isIgnored);

      // Vérifier s'il y a des erreurs de batterie actives (non résolues et non ignorées)
      bool batteryError = baes.erreurs.any((e) =>
          (e.typeErreur == 'battery' || e.typeErreur == 'erreur_batterie') &&
          !e.isSolved &&
          !e.isIgnored);

      // Vérifier si des erreurs de connexion sont ignorées
      bool conectionErrorIgnored = baes.erreurs.any((e) =>
          (e.typeErreur == 'connection' ||
              e.typeErreur == 'erreur_connexion') &&
          e.isIgnored);

      // Vérifier si des erreurs de batterie sont ignorées
      bool batteryErrorIgnored = baes.erreurs.any((e) =>
          (e.typeErreur == 'battery' || e.typeErreur == 'erreur_batterie') &&
          e.isIgnored);

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
                Text('Site: ${_siteProv?.selectedSite?.name ?? ""}'),
                Text('Bâtiment: ${_selBat?.name ?? ""}'),
                Text('Étage: $floorName'),
                Text('ID du bloc: ${baes.id}'),
                Row(
                  children: [
                    const Text(
                      'Statut: ',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                    Text(statusConnection ? ' Déconnecté' : ' Connecté'),
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
    }
  }

  Future<void> _loadFloor(int floorId) async {
    if (_selBat == null) return;
    final data = await APIBatiment.getBuildingAllData(_selBat!.id);
    if (data == null) return;
    setState(() {
      _floors = data.etages;
      _selFloorId = floorId;
      _isFloor = true;
      _batimentEtages = data.etages;
      _isFloorMode = true;
    });

    // Update the markers
    _updateBaesMarkers();

    final carte = Carte.allCartes.firstWhere((c) => c.etageId == floorId);
    final bytes = (await http.get(Uri.parse(carte.chemin))).bodyBytes;
    ui.decodeImageFromList(bytes, (img) {
      final w = img.width.toDouble(), h = img.height.toDouble();
      final scale = min(90 / h, 180 / w);
      setState(() {
        _floorEffW = w * scale;
        _floorEffH = h * scale;
        _floorCarte = carte;
        _floorImage = MemoryImage(bytes);
      });
    });
  }

  void _onSiteTap(TapPosition _, LatLng p) {
    final site = _siteProv!.getCompleteSiteById(_siteProv!.selectedSite!.id)!;
    for (var bat in site.batiments) {
      final poly = (bat.polygonPoints['points'] as List)
          .map((e) => LatLng(e[0], e[1]))
          .toList();
      if (_pointInPoly(p, poly)) {
        _selBat = bat;
        _loadFloor(bat.etages.first.id);
        break;
      }
    }
  }

  bool _pointInPoly(LatLng pt, List<LatLng> poly) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      var xi = poly[i].latitude, yi = poly[i].longitude;
      var xj = poly[j].latitude, yj = poly[j].longitude;
      final intersect = ((yi > pt.longitude) != (yj > pt.longitude)) &&
          (pt.latitude < (xj - xi) * (pt.longitude - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // ─── Site ──────────────────────────────────────────
        if (!_isFloor)
          _siteCarte == null || _siteImage == null
              ? Center(child: CircularProgressIndicator())
              : SiteMapView(
                  key: ValueKey('site_${_siteCarte!.siteId}'),
                  controller: _siteController,
                  carte: _siteCarte!,
                  image: _siteImage!,
                  effH: _siteEffH,
                  effW: _siteEffW,
                  polygons: _sitePolys,
                  onTap: _onSiteTap,
                ),

        // ─── Étage ─────────────────────────────────────────
        if (_isFloor)
          _floorCarte == null || _floorImage == null
              ? Center(child: CircularProgressIndicator())
              : FloorMapView(
                  key: ValueKey('floor_${_selFloorId}'),
                  controller: _floorController,
                  carte: _floorCarte!,
                  image: _floorImage!,
                  effH: _floorEffH,
                  effW: _floorEffW,
                  markers: _floorMarkers,
                ),

        // ─── Dropdown étage ─────────────────────────────────
        if (_isFloor)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Row(children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _isFloor = false),
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
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selFloorId,
                      hint: const Text("Sélectionner un étage"),
                      items: _floors
                          .map((e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(e.name),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null && v != _selFloorId) {
                          _loadFloor(v);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

class SiteMapView extends StatefulWidget {
  final MapController controller;
  final Carte carte;
  final ImageProvider image;
  final double effH, effW;
  final List<Polygon> polygons;
  final void Function(TapPosition, LatLng) onTap;

  const SiteMapView({
    Key? key,
    required this.controller,
    required this.carte,
    required this.image,
    required this.effH,
    required this.effW,
    required this.polygons,
    required this.onTap,
  }) : super(key: key);

  @override
  _SiteMapViewState createState() => _SiteMapViewState();
}

class _SiteMapViewState extends State<SiteMapView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.move(
        LatLng(widget.carte.centerLat, widget.carte.centerLng),
        widget.carte.zoom,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: widget.controller,
      options: MapOptions(
        crs: const CrsSimple(),
        initialCenter: LatLng(widget.carte.centerLat, widget.carte.centerLng),
        initialZoom: widget.carte.zoom,
        maxZoom: widget.carte.zoom + 10,
        minZoom: widget.carte.zoom - 10,
        onTap: widget.onTap,
      ),
      children: [
        OverlayImageLayer(
          overlayImages: [
            OverlayImage(
              bounds: LatLngBounds(
                const LatLng(0, 0),
                LatLng(widget.effH, widget.effW),
              ),
              imageProvider: widget.image,
            ),
          ],
        ),
        if (widget.polygons.isNotEmpty) PolygonLayer(polygons: widget.polygons),
      ],
    );
  }
}

class FloorMapView extends StatefulWidget {
  final MapController controller;
  final Carte carte;
  final ImageProvider image;
  final double effH, effW;
  final List<Marker> markers;

  const FloorMapView({
    Key? key,
    required this.controller,
    required this.carte,
    required this.image,
    required this.effH,
    required this.effW,
    required this.markers,
  }) : super(key: key);

  @override
  _FloorMapViewState createState() => _FloorMapViewState();
}

class _FloorMapViewState extends State<FloorMapView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.move(
        LatLng(widget.carte.centerLat, widget.carte.centerLng),
        widget.carte.zoom,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: widget.controller,
      options: MapOptions(
        crs: const CrsSimple(),
        initialCenter: LatLng(widget.carte.centerLat, widget.carte.centerLng),
        initialZoom: widget.carte.zoom,
        maxZoom: widget.carte.zoom + 10,
        minZoom: widget.carte.zoom - 10,
      ),
      children: [
        OverlayImageLayer(
          overlayImages: [
            OverlayImage(
              bounds: LatLngBounds(
                const LatLng(0, 0),
                LatLng(widget.effH, widget.effW),
              ),
              imageProvider: widget.image,
            ),
          ],
        ),
        if (widget.markers.isNotEmpty) MarkerLayer(markers: widget.markers),
      ],
    );
  }
}
