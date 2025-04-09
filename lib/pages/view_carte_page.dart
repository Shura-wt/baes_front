part of '../main.dart';

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
  Map<String, dynamic>? siteData;

  // Paramètres pour la vue d’étage
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
    _loadSiteData();
  }

  /// Charge les données du site depuis SharedPreferences.
  Future<void> _loadSiteData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      siteZoom = prefs.getDouble("savedSiteZoom") ?? 13.0;
      // Pour CrsSimple, on place le centre au milieu de l'image.
      double centerX =
          prefs.getDouble("savedSiteCenterLat") ?? (siteEffectiveHeight / 2);
      double centerY =
          prefs.getDouble("savedSiteCenterLng") ?? (siteEffectiveWidth / 2);
      siteCenter = LatLng(centerX, centerY);

      String? base64Image = prefs.getString("uploadedSiteImage");
      if (base64Image != null) {
        uploadedSiteImage = base64Decode(base64Image);
        siteImage = MemoryImage(uploadedSiteImage!);
        // Décodage de l'image pour obtenir ses dimensions originales et appliquer un scaleFactor.
        ui.decodeImageFromList(uploadedSiteImage!, (ui.Image img) {
          double originalWidth = img.width.toDouble();
          double originalHeight = img.height.toDouble();
          // On choisit un scaleFactor pour que la hauteur effective ne dépasse pas 90 et la largeur 180.
          double scaleFactor = min(90 / originalHeight, 180 / originalWidth);
          setState(() {
            siteEffectiveWidth = originalWidth * scaleFactor;
            siteEffectiveHeight = originalHeight * scaleFactor;
            siteCenter =
                LatLng(siteEffectiveHeight / 2, siteEffectiveWidth / 2);
          });
          _mapController.move(siteCenter, siteZoom);
        });
      }
      String? jsonData = prefs.getString("siteData");
      if (jsonData != null) {
        siteData = json.decode(jsonData);
      }
    });
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
  /// En mode site, si le point tapé est dans un polygone, on charge la vue d’un étage.
  void _onMapTap(TapPosition tapPosition, LatLng latlng) {
    if (!isFloorView && siteData != null && siteData!['batiments'] != null) {
      Map batiments = siteData!['batiments'];
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

  /// Charge la vue d’un étage (zoom, centre, image et markers) depuis SharedPreferences et le JSON.
  Future<void> _loadFloorView(
      String buildingName, String floorName, Map floorData) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currentBuilding = buildingName;
      currentFloor = floorName;
      floorZoom = prefs.getDouble("savedFloorZoom_$floorName") ?? 13.0;
      double centerX = prefs.getDouble("savedFloorCenterLat_$floorName") ??
          (floorEffectiveHeight / 2);
      double centerY = prefs.getDouble("savedFloorCenterLng_$floorName") ??
          (floorEffectiveWidth / 2);
      floorCenter = LatLng(centerX, centerY);
    });
    String? base64Floor = prefs.getString("uploadedFloorImage_$floorName");
    if (base64Floor != null) {
      uploadedFloorImage = base64Decode(base64Floor);
      floorImage = MemoryImage(uploadedFloorImage!);
      ui.decodeImageFromList(uploadedFloorImage!, (ui.Image img) {
        double originalWidth = img.width.toDouble();
        double originalHeight = img.height.toDouble();
        double scaleFactor = min(90 / originalHeight, 180 / originalWidth);
        setState(() {
          floorEffectiveWidth = originalWidth * scaleFactor;
          floorEffectiveHeight = originalHeight * scaleFactor;
          floorCenter =
              LatLng(floorEffectiveHeight / 2, floorEffectiveWidth / 2);
        });
        _mapController.move(floorCenter, floorZoom);
        if (kDebugMode) {
          print("FloorView Updated:");
          print("  floorEffectiveWidth: $floorEffectiveWidth");
          print("  floorEffectiveHeight: $floorEffectiveHeight");
          print("  floorCenter: $floorCenter");
        }

        // Charger les markers
        List<Marker> markers = [];
        if (floorData['baes'] != null) {
          Map baes = floorData['baes'];
          baes.forEach((key, bae) {
            double mLat = (bae['lat'] as num).toDouble();
            double mLng = (bae['lng'] as num).toDouble();
            bool statusConnection = bae['status_connection'] ?? false;
            // Vérifiez ici si vos données de marker sont déjà à l'échelle effective.
            // Si c'est le cas, n'appliquez pas la conversion. Sinon, décommentez la ligne ci-dessous.
            // double scaledLat = mLat * scaleFactor;
            // double scaledLng = mLng * scaleFactor;
            // Pour tester, nous utilisons directement les valeurs enregistrées :
            double displayLat = mLat; // ou scaledLat
            double displayLng = mLng; // ou scaledLng

            if (kDebugMode) {
              print("Marker $key:");
              print(
                  "  original: ($mLat, $mLng)  display: ($displayLat, $displayLng)");
              print("  status_connection: $statusConnection");
            }
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
    setState(() {
      isFloorView = true;
    });
    print("isFloorView set to true");
  }

  /// Retour à la vue globale du site.
  void _backToSiteView() {
    setState(() {
      isFloorView = false;
    });
    _mapController.move(siteCenter, siteZoom);
    print("isFloorView set to false");
  }

  /// Construit la liste des polygones à partir du JSON.
  List<Polygon> _buildPolygones() {
    List<Polygon> polygons = [];
    if (siteData != null && siteData!['batiments'] != null) {
      Map batiments = siteData!['batiments'];
      batiments.forEach((buildingName, buildingData) {
        List<dynamic> pointsData = buildingData['polygonPoints'];
        List<LatLng> points = pointsData
            .map((point) => LatLng((point['lat'] as num).toDouble(),
                (point['lng'] as num).toDouble()))
            .toList();
        polygons.add(
          Polygon(
            points: points,
            color: Colors.blue.withOpacity(0.3),
            borderColor: Colors.blue,
            borderStrokeWidth: 2,
          ),
        );
      });
    }
    return polygons;
  }

  @override
  Widget build(BuildContext context) {
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
                ),
              // En vue d'étage, affichage des markers (BAES)
              if (isFloorView)
                MarkerLayer(
                  markers: floorMarkers,
                ),
            ],
          ),
          // Menu déroulant pour la sélection d'étage (affiché uniquement en mode étage)
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
                      if (siteData != null &&
                          siteData!['batiments'] != null &&
                          currentBuilding.isNotEmpty) {
                        Map buildingData =
                            siteData!['batiments'][currentBuilding];
                        if (buildingData != null &&
                            buildingData['etages'] != null) {
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
    if (siteData != null && currentBuilding.isNotEmpty) {
      Map buildingData = siteData!['batiments'][currentBuilding];
      if (buildingData != null && buildingData['etages'] != null) {
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
