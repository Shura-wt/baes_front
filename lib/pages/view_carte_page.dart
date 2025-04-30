part of '../main.dart';

/// Page permettant uniquement la visualisation des cartes, bâtiments, étages et BAES.
/// Cette page est en lecture seule et ne permet pas de modifier les données.
class ViewCartePage extends StatefulWidget {
  const ViewCartePage({super.key});

  @override
  State<ViewCartePage> createState() => _ViewCartePageState();
}

class _ViewCartePageState extends State<ViewCartePage> {
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

  @override
  void initState() {
    super.initState();
    _loadApiData();
  }

  /// Charge les données depuis l'API
  Future<void> _loadApiData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Récupérer les données générales de l'utilisateur
      userSites = await getGeneralInfos(context);

      if (userSites.isNotEmpty) {
        // Sélectionner le premier site par défaut
        currentSite = userSites.first;

        // Préparer les données du site pour l'affichage
        _prepareSiteData();

        // Charger la carte du site
        await _loadSiteMap();
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors du chargement des données: $e");
      }
      setState(() {
        isLoading = false;
      });
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
          baesData[baes.id.toString()] = {
            'lat': baes.position['latitude'],
            'lng': baes.position['longitude'],
            'status_connection': baes.position['status_connection'] ?? false,
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
          _mapController.move(siteCenter, siteZoom);
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
        List<LatLng> polygonPoints = pointsData
            .map((point) => LatLng((point['lat'] as num).toDouble(),
                (point['lng'] as num).toDouble()))
            .toList();
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

          _mapController.move(floorCenter, floorZoom);

          // Charger les markers
          List<Marker> markers = [];
          if (floorData['baes'] != null) {
            Map baes = floorData['baes'];
            baes.forEach((key, bae) {
              double mLat = (bae['lat'] as num).toDouble();
              double mLng = (bae['lng'] as num).toDouble();
              bool statusConnection = bae['status_connection'] ?? false;

              // Pour tester, nous utilisons directement les valeurs enregistrées
              double displayLat = mLat;
              double displayLng = mLng;

              markers.add(
                Marker(
                  point: LatLng(displayLat, displayLng),
                  width: 30,
                  height: 30,
                  child: Icon(
                    Icons.location_on,
                    color: statusConnection ? Colors.green : Colors.red,
                    size: 30,
                  ),
                ),
              );
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
    _mapController.move(siteCenter, siteZoom);
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
              double lat = (point['lat'] as num).toDouble();
              double lng = (point['lng'] as num).toDouble();
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
                double lat = (point['lat'] as num).toDouble();
                double lng = (point['lng'] as num).toDouble();

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
                  color: Colors.green.withOpacity(0.5),
                  borderColor: Colors.green,
                  borderStrokeWidth: 4,
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

    // Si nous sommes en mode site et qu'aucune image n'est disponible, on affiche un message.
    if (!isFloorView && siteImage == null) {
      return GradiantBackground.getSafeAreaGradiant(
        context,
        Center(
          child: Text(
            "Aucune carte disponible pour le site",
            style: Theme.of(context).textTheme.titleLarge,
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
              top: 16,
              left: 16,
              child: Container(
                width: 150, // Largeur réduite
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
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
                            _loadFloorView(
                                currentBuilding, newValue, etages[newValue]);
                          }
                        }
                      }
                    }
                  },
                ),
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
      ),
      floatingActionButton: isFloorView
          ? FloatingActionButton(
              onPressed: _backToSiteView,
              child: const Icon(Icons.arrow_back),
            )
          : null,
    );
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
