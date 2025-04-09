part of '../../main.dart';

class GestionCartePage extends StatefulWidget {
  const GestionCartePage({super.key});

  @override
  State<GestionCartePage> createState() => _GestionCartePageState();
}

class _GestionCartePageState extends State<GestionCartePage>
    with WidgetsBindingObserver {
  // ========================================================
  // VARIABLES COMMUNES
  // ========================================================
  Site? _site;
  Timer? _floorDebounceTimer;
  bool _floorMapReady =
      false; // Indique si le FlutterMap pour l'étage est rendu
  bool _siteMapReady = false; // Indique si le FlutterMap pour le site est rendu

  /// MapControllers pour le mode site et le mode étage
  final MapController _siteMapController = MapController();
  final MapController _floorMapController = MapController();

  /// Mode affiché : false = vue site (bâtiments, polygones), true = vue étage (markers)
  bool _isFloorMode = false;

  /// Nom du bâtiment sélectionné (pour afficher la carte d'un étage)
  String? _selectedBuilding;

  // ========================================================
  // VARIABLES MODE SITE (affichage du site avec polygones)
  // ========================================================
  Uint8List? _uploadedSiteImage;
  double? _siteEffectiveWidth;
  double? _siteEffectiveHeight;
  LatLng _siteCenter = const LatLng(0, 0);
  double _siteInitialZoom = 0;
  List<Polygon> _batimentPolygons = [];
  final List<LatLng> _currentPolygonPoints = [];
  String _currentSiteMode = ''; // ex. "polygon" pour création de polygones

  // ========================================================
  // VARIABLES MODE ÉTAGE (affichage d'un étage avec markers)
  // ========================================================
  Uint8List? _uploadedFloorImage;
  double? _floorEffectiveWidth;
  double? _floorEffectiveHeight;
  LatLng _floorCenter = const LatLng(0, 0);
  double _floorInitialZoom = 0;
  List<Marker> _markers = [];
  String _currentFloorMode = 'selection'; // ex. "marker" pour ajouter un BAES
  // Gestion des étages disponibles (chaque étage aura sa sauvegarde)
  String? _selectedEtage;

  // Pour la détection des taps sur les polygones dans le mode site
  final LayerHitNotifier _polygonHitNotifier = ValueNotifier(null);

  // Liste des étages disponibles
  List<String> _etages = [];

  // ========================================================
  // INITIALISATION
  // ========================================================
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Charger les données du site (polygones, etc.) et les paramètres de la carte du site
    _loadSiteData().then((_) {
      _loadSiteSettings();
      _loadPolygonsFromSite();
    });

    // Initialisation de la sélection d’étage par défaut
    _selectedEtage = _etages.first;
  }

  @override
  void dispose() {
    _floorDebounceTimer?.cancel();
    // Sauvegarde des paramètres avant de disposer.
    try {
      if (!_isFloorMode) {
        // Sauvegarde de la carte de site (polygones)
        if (_uploadedSiteImage != null) {
          _saveSiteSettings(
            _siteMapController.camera.zoom,
            _siteMapController.camera.center,
          );
        }
      } else {
        // Sauvegarde de la carte d'étage (markers)
        if (_uploadedFloorImage != null) {
          _saveFloorSettings(
            _floorMapController.camera.zoom,
            _floorMapController.camera.center,
          );
        }
      }
    } catch (e) {
      debugPrint("Erreur lors de la sauvegarde dans dispose: $e");
    }
    _saveSiteData();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ========================================================
  // GESTION DES PARAMÈTRES DU SITE (Carte de site avec polygones)
  // ========================================================
  Future<void> _loadSiteSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    double? savedZoom = prefs.getDouble('savedSiteZoom');
    double? savedCenterLat = prefs.getDouble('savedSiteCenterLat');
    double? savedCenterLng = prefs.getDouble('savedSiteCenterLng');
    String? base64Image = prefs.getString('uploadedSiteImage');

    if (savedZoom != null && savedCenterLat != null && savedCenterLng != null) {
      setState(() {
        _siteInitialZoom = savedZoom;
        _siteCenter = LatLng(savedCenterLat, savedCenterLng);
      });
      // On planifie l'appel move() une fois que le widget est rendu
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _siteMapController.move(_siteCenter, _siteInitialZoom);
      });
    }
    if (base64Image != null) {
      Uint8List imageBytes = base64Decode(base64Image);
      ui.decodeImageFromList(imageBytes, (ui.Image img) {
        double originalWidth = img.width.toDouble();
        double originalHeight = img.height.toDouble();
        double scaleFactor = min(90 / originalHeight, 180 / originalWidth);
        setState(() {
          _uploadedSiteImage = imageBytes;
          _siteEffectiveWidth = originalWidth * scaleFactor;
          _siteEffectiveHeight = originalHeight * scaleFactor;
          if (_siteCenter == const LatLng(0, 0)) {
            _siteCenter =
                LatLng(_siteEffectiveHeight! / 2, _siteEffectiveWidth! / 2);
          }
          if (_siteInitialZoom == 0) {
            final Size screenSize = MediaQuery.of(context).size;
            final double scale = min(
              screenSize.width / _siteEffectiveWidth!,
              screenSize.height / _siteEffectiveHeight!,
            );
            _siteInitialZoom = log(scale) / log(2);
            _siteInitialZoom = _siteInitialZoom.clamp(-1.0, 2.0);
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _siteMapController.move(_siteCenter, _siteInitialZoom);
        });
      });
    }
  }

  Future<void> _saveSiteSettings(double zoom, LatLng center) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('savedSiteZoom', zoom);
    await prefs.setDouble('savedSiteCenterLat', center.latitude);
    await prefs.setDouble('savedSiteCenterLng', center.longitude);
    if (_uploadedSiteImage != null) {
      await prefs.setString(
          'uploadedSiteImage', base64Encode(_uploadedSiteImage!));
    }
    debugPrint("Site settings saved: Zoom = $zoom, Center = $center");
  }

  // ========================================================
  // GESTION DES PARAMÈTRES DE L'ÉTAGE (Carte d'étage avec markers)
  // ========================================================
  Future<void> _loadFloorSettings() async {
    if (_selectedEtage == null) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    double? savedZoom = prefs.getDouble('savedFloorZoom_$_selectedEtage');
    double? savedCenterLat =
        prefs.getDouble('savedFloorCenterLat_$_selectedEtage');
    double? savedCenterLng =
        prefs.getDouble('savedFloorCenterLng_$_selectedEtage');
    String? base64Image = prefs.getString('uploadedFloorImage_$_selectedEtage');

    // Ne tenter de déplacer la carte d'étage que si une image est disponible
    if (savedZoom != null &&
        savedCenterLat != null &&
        savedCenterLng != null &&
        base64Image != null) {
      setState(() {
        _floorInitialZoom = savedZoom;
        _floorCenter = LatLng(savedCenterLat, savedCenterLng);
      });
      if (_floorMapReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _floorMapController.move(_floorCenter, _floorInitialZoom);
        });
      } else {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _floorMapReady) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _floorMapController.move(_floorCenter, _floorInitialZoom);
            });
          }
        });
      }
    }

    if (base64Image != null) {
      Uint8List imageBytes = base64Decode(base64Image);
      ui.decodeImageFromList(imageBytes, (ui.Image img) {
        double originalWidth = img.width.toDouble();
        double originalHeight = img.height.toDouble();
        double scaleFactor = min(90 / originalHeight, 180 / originalWidth);
        setState(() {
          _uploadedFloorImage = imageBytes;
          _floorEffectiveWidth = originalWidth * scaleFactor;
          _floorEffectiveHeight = originalHeight * scaleFactor;
          if (_floorCenter == const LatLng(0, 0)) {
            _floorCenter =
                LatLng(_floorEffectiveHeight! / 2, _floorEffectiveWidth! / 2);
          }
          if (_floorInitialZoom == 0) {
            final Size screenSize = MediaQuery.of(context).size;
            final double scale = min(
              screenSize.width / _floorEffectiveWidth!,
              screenSize.height / _floorEffectiveHeight!,
            );
            _floorInitialZoom = log(scale) / log(2);
            _floorInitialZoom = _floorInitialZoom.clamp(-1.0, 2.0);
          }
        });
        if (_floorMapReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _floorMapController.move(_floorCenter, _floorInitialZoom);
          });
        } else {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _floorMapReady) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _floorMapController.move(_floorCenter, _floorInitialZoom);
              });
            }
          });
        }
      });
    } else {
      setState(() {
        _uploadedFloorImage = null;
        _floorEffectiveWidth = null;
        _floorEffectiveHeight = null;
      });
    }
  }

  Future<void> _saveFloorSettings(double zoom, LatLng center) async {
    if (_selectedEtage == null) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('savedFloorZoom_$_selectedEtage', zoom);
    await prefs.setDouble(
        'savedFloorCenterLat_$_selectedEtage', center.latitude);
    await prefs.setDouble(
        'savedFloorCenterLng_$_selectedEtage', center.longitude);
    if (_uploadedFloorImage != null) {
      await prefs.setString('uploadedFloorImage_$_selectedEtage',
          base64Encode(_uploadedFloorImage!));
    }
    debugPrint(
        "Floor settings saved for $_selectedEtage: Zoom = $zoom, Center = $center");
  }

  // ========================================================
  // GESTION DES DONNÉES DU SITE
  // ========================================================
  Future<void> _loadSiteData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? siteJson = prefs.getString('siteData');
    if (siteJson != null) {
      setState(() {
        _site = Site.fromJson(json.decode(siteJson));
      });
    } else {
      setState(() {
        // Ici, on fournit un id par défaut (ici 0) car l'id ne peut être null.
        _site = Site(id: 0, title: "Mon site", carte: "", batiments: {});
      });
    }
  }

  Future<void> _saveSiteData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_site != null) {
      await prefs.setString('siteData', json.encode(_site!.toJson()));
      debugPrint("Site data saved: ${_site!.toJson()}");
    }
  }

  // ========================================================
  // GESTION DES POLYGONES (Mode Site)
  // ========================================================
  void _loadPolygonsFromSite() {
    if (_site != null) {
      List<Polygon> loadedPolygons = [];
      _site!.batiments.forEach((_, batiment) {
        loadedPolygons.add(
          Polygon(
            points: batiment.polygonPoints,
            color: Colors.blue.withOpacity(0.3),
            borderColor: Colors.green,
            borderStrokeWidth: 2,
            isFilled: true,
            hitValue: batiment.name,
          ),
        );
      });
      setState(() {
        _batimentPolygons = loadedPolygons;
      });
    }
  }

  // ========================================================
  // UPLOAD D'IMAGE
  // ========================================================
  // Pour la carte du site
  Future<void> _uploadSiteImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final Uint8List imageBytes = result.files.single.bytes!;
      ui.decodeImageFromList(imageBytes, (ui.Image img) {
        double originalWidth = img.width.toDouble();
        double originalHeight = img.height.toDouble();
        double scaleFactor = min(90 / originalHeight, 180 / originalWidth);
        double effectiveWidth = originalWidth * scaleFactor;
        double effectiveHeight = originalHeight * scaleFactor;
        LatLng center = LatLng(effectiveHeight / 2, effectiveWidth / 2);
        setState(() {
          _uploadedSiteImage = imageBytes;
          _siteEffectiveWidth = effectiveWidth;
          _siteEffectiveHeight = effectiveHeight;
          _siteCenter = center;
          if (_siteInitialZoom == 0) {
            final Size screenSize = MediaQuery.of(context).size;
            final double scale = min(
              screenSize.width / effectiveWidth,
              screenSize.height / effectiveHeight,
            );
            _siteInitialZoom = log(scale) / log(2);
            _siteInitialZoom = _siteInitialZoom.clamp(-1.0, 2.0);
          }
        });
        _saveSiteSettings(_siteInitialZoom, center);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _siteMapController.move(_siteCenter, _siteInitialZoom);
        });
      });
    }
  }

  // Pour la carte de l'étage
  Future<void> _uploadFloorImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final Uint8List imageBytes = result.files.single.bytes!;
      ui.decodeImageFromList(imageBytes, (ui.Image img) {
        double originalWidth = img.width.toDouble();
        double originalHeight = img.height.toDouble();
        double scaleFactor = min(90 / originalHeight, 180 / originalWidth);
        double effectiveWidth = originalWidth * scaleFactor;
        double effectiveHeight = originalHeight * scaleFactor;
        LatLng center = LatLng(effectiveHeight / 2, effectiveWidth / 2);
        setState(() {
          _uploadedFloorImage = imageBytes;
          _floorEffectiveWidth = effectiveWidth;
          _floorEffectiveHeight = effectiveHeight;
          _floorCenter = center;
          if (_floorInitialZoom == 0) {
            final Size screenSize = MediaQuery.of(context).size;
            final double scale = min(
              screenSize.width / effectiveWidth,
              screenSize.height / effectiveHeight,
            );
            _floorInitialZoom = log(scale) / log(2);
            _floorInitialZoom = _floorInitialZoom.clamp(-1.0, 2.0);
          }
        });
        _saveFloorSettings(_floorInitialZoom, center);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _floorMapController.move(_floorCenter, _floorInitialZoom);
        });
      });
    }
  }

  // ========================================================
  // GESTION DES TAP SUR LA CARTE
  // ========================================================
  // Mode Site : ajout progressif d'un polygone pour définir un bâtiment
  void _handleMapTapSite(TapPosition tapPosition, LatLng latlng) {
    if (_currentSiteMode == 'polygon') {
      setState(() {
        _currentPolygonPoints.add(latlng);
      });
      if (_currentPolygonPoints.length == 4) {
        _showPolygonNamingDialog();
      }
    }
  }

  Future<void> _showPolygonNamingDialog() async {
    final TextEditingController nameController = TextEditingController();
    final String? polygonName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nom du polygon (Bâtiment)'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, nameController.text),
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
    setState(() {
      if (polygonName != null && polygonName.isNotEmpty) {
        final polygon = Polygon(
          points: List<LatLng>.from(_currentPolygonPoints),
          color: Colors.blue.withOpacity(0.3),
          borderColor: Colors.blue,
          borderStrokeWidth: 2,
          isFilled: true,
          hitValue: polygonName,
        );
        _batimentPolygons.add(polygon);

        Batiment newBatiment = Batiment(
          polygonPoints: List<LatLng>.from(_currentPolygonPoints),
          name: polygonName,
          etages: {
            "Etage 1": Etage(
              carte: "default_etage.png",
              name: "Etage 1",
              position: 1,
              baes: {},
            )
          },
        );
        // Si _site n'existe pas, on le crée en lui fournissant un id par défaut (ici 0)
        _site ??= Site(id: 0, title: "Mon site", carte: "", batiments: {});
        // Ajout du nouveau bâtiment dans la map des batiments avec pour clé le nom du polygon
        _site!.batiments[polygonName] = newBatiment;
        _saveSiteData();
      }
      _currentPolygonPoints.clear();
    });
  }

  // Mode Étage : Popup pour sélectionner un BAES
  Future<BAES?> _showBaesSelectionDialog() async {
    BAES? selectedBaes;
    return await showDialog<BAES>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sélectionnez un BAES'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return DropdownButton<BAES>(
                isExpanded: true,
                value: selectedBaes,
                hint: const Text('Choisissez un BAES'),
                items: baesList.map((baes) {
                  return DropdownMenuItem<BAES>(
                    value: baes,
                    child: Text(
                        'BAES ${baes.id} (Bâtiment ${baes.idBatiment}, Etage ${baes.idEtage})'),
                  );
                }).toList(),
                onChanged: (BAES? newValue) {
                  setState(() {
                    selectedBaes = newValue;
                  });
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(selectedBaes),
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
  }

  // Mode Étage : ajout d'un marker BAES après sélection
  void _handleMapTapFloor(TapPosition tapPosition, LatLng latlng) async {
    if (_currentFloorMode == 'marker') {
      BAES? selectedBaes = await _showBaesSelectionDialog();
      if (selectedBaes != null) {
        setState(() {
          _markers.add(
            Marker(
              point: latlng,
              child: const Icon(Icons.place, color: Colors.red, size: 30),
            ),
          );
        });
        if (_site != null &&
            _site!.batiments.containsKey(_selectedBuilding!) &&
            _selectedEtage != null) {
          Batiment? batiment = _site!.batiments[_selectedBuilding!];
          if (batiment != null &&
              batiment.etages.containsKey(_selectedEtage!)) {
            Etage etage = batiment.etages[_selectedEtage!]!;
            BAES newBAES = BAES(
              id: selectedBaes.id,
              idBatiment: selectedBaes.idBatiment,
              idEtage: selectedBaes.idEtage,
              lat: latlng.latitude,
              lng: latlng.longitude,
              status_connection: selectedBaes.status_connection,
              status_error: selectedBaes.status_error,
            );
            etage.baes["baes_${selectedBaes.id}"] = newBAES;
            _saveSiteData();
            _loadMarkersFromSite();
          }
        }
      }
    }
  }

  // Recharge les markers pour l'étage sélectionné
  void _loadMarkersFromSite() {
    setState(() {
      _markers.clear();
    });
    if (_site != null &&
        _site!.batiments.containsKey(_selectedBuilding!) &&
        _selectedEtage != null) {
      Etage? etage =
          _site!.batiments[_selectedBuilding!]?.etages[_selectedEtage!];
      if (etage != null) {
        List<Marker> loadedMarkers = [];
        etage.baes.forEach((_, baes) {
          loadedMarkers.add(
            Marker(
              point: LatLng(baes.lat, baes.lng),
              child: const Icon(Icons.place, color: Colors.red, size: 30),
            ),
          );
        });
        setState(() {
          _markers = loadedMarkers;
        });
      }
    }
  }

  // Dialogue pour ajouter un nouvel étage (mode Étage)
  Future<void> _showAddFloorDialog() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController positionController = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Ajouter un étage"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Nom de l'étage"),
              ),
              TextField(
                controller: positionController,
                decoration:
                    const InputDecoration(labelText: "Position dans la liste"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    positionController.text.isNotEmpty) {
                  int? pos = int.tryParse(positionController.text);
                  if (pos != null) {
                    Navigator.pop(context,
                        {"name": nameController.text, "position": pos});
                  }
                }
              },
              child: const Text("Valider"),
            ),
          ],
        );
      },
    );
    if (result != null) {
      setState(() {
        int pos = result["position"];
        String name = result["name"];
        if (pos < 0) pos = 0;
        if (pos > _etages.length) pos = _etages.length;
        _etages.insert(pos, name);
        _selectedEtage = name;
        if (_site != null && _site!.batiments.containsKey(_selectedBuilding!)) {
          Batiment? batiment = _site!.batiments[_selectedBuilding!];
          if (batiment != null) {
            batiment.etages[name] = Etage(
              carte: "default_etage.png",
              name: name,
              position: pos,
              baes: {},
            );
            _saveSiteData();
          }
        }
      });
    }
  }

  // Effacer toutes les données sauvegardées
  Future<void> _clearSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('siteData');
    await prefs.remove('uploadedSiteImage');
    await prefs.remove('savedSiteZoom');
    await prefs.remove('savedSiteCenterLat');
    await prefs.remove('savedSiteCenterLng');
    if (_selectedEtage != null) {
      await prefs.remove('uploadedFloorImage_$_selectedEtage');
      await prefs.remove('savedFloorZoom_$_selectedEtage');
      await prefs.remove('savedFloorCenterLat_$_selectedEtage');
      await prefs.remove('savedFloorCenterLng_$_selectedEtage');
    }
    setState(() {
      // Créer un nouveau Site en spécifiant un id par défaut (ici 0)
      _site = Site(id: 0, title: "Mon site", carte: "", batiments: {});
      _batimentPolygons.clear();
      _currentPolygonPoints.clear();
      _uploadedSiteImage = null;
      _siteEffectiveWidth = null;
      _siteEffectiveHeight = null;
      _siteCenter = const LatLng(0, 0);
      _siteInitialZoom = 0;

      _uploadedFloorImage = null;
      _floorEffectiveWidth = null;
      _floorEffectiveHeight = null;
      _floorCenter = const LatLng(0, 0);
      _floorInitialZoom = 0;
      _markers.clear();
    });
    debugPrint("Toutes les données sauvegardées ont été effacées.");
  }

  // ========================================================
  // CONSTRUCTION DE L'INTERFACE
  // ========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isFloorMode ? _buildFloorView() : _buildSiteView(),
      floatingActionButton: _isFloorMode ? _buildFloorFAB() : _buildSiteFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ========================================================
  // VUE MODE SITE (Affichage du site avec polygones)
  // ========================================================
  Widget _buildSiteView() {
    if (_uploadedSiteImage == null) {
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
    return Builder(
      builder: (context) {
        // Marquer la carte du site comme prête
        if (!_siteMapReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _siteMapReady = true;
            });
            try {
              _siteMapController.move(_siteCenter, _siteInitialZoom);
            } catch (e) {
              debugPrint("Erreur move site map: $e");
            }
          });
        }
        return FlutterMap(
          mapController: _siteMapController,
          options: MapOptions(
            crs: const CrsSimple(),
            initialCenter: _siteCenter,
            initialZoom: _siteInitialZoom,
            maxZoom: _siteInitialZoom + 10,
            minZoom: _siteInitialZoom - 10,
            onTap: (tapPosition, point) {
              _handleMapTapSite(tapPosition, point);
            },
          ),
          children: [
            OverlayImageLayer(
              overlayImages: [
                OverlayImage(
                  bounds: LatLngBounds(
                    const LatLng(0, 0),
                    LatLng(_siteEffectiveHeight ?? 0, _siteEffectiveWidth ?? 0),
                  ),
                  opacity: 1.0,
                  imageProvider: MemoryImage(_uploadedSiteImage!),
                ),
              ],
            ),
            if (_currentPolygonPoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _currentPolygonPoints,
                    color: Colors.blue,
                    strokeWidth: 2,
                  ),
                ],
              ),
            MouseRegion(
              hitTestBehavior: HitTestBehavior.deferToChild,
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  final hitResult = _polygonHitNotifier.value;
                  if (hitResult != null && hitResult.hitValues.isNotEmpty) {
                    String buildingName = hitResult.hitValues.first.toString();
                    debugPrint("Polygone cliqué: $buildingName");
                    setState(() {
                      _isFloorMode = true;
                      _selectedBuilding = buildingName;
                      _selectedEtage = _etages.first;
                      _floorMapReady =
                          false; // Réinitialiser le flag pour le mode étage
                    });
                    // Différer l'appel pour que la vue étage soit rendue
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _loadFloorSettings();
                      _loadMarkersFromSite();
                    });
                  }
                },
                child: PolygonLayer(
                  polygons: _batimentPolygons,
                  hitNotifier: _polygonHitNotifier,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ========================================================
  // VUE MODE ÉTAGE (Affichage d'un étage avec markers)
  // ========================================================
  Widget _buildFloorView() {
    return Stack(
      children: [
        Positioned.fill(
          child: _uploadedFloorImage != null
              ? Builder(
                  builder: (context) {
                    if (!_floorMapReady) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() {
                          _floorMapReady = true;
                        });
                        try {
                          _floorMapController.move(
                              _floorCenter, _floorInitialZoom);
                        } catch (e) {
                          debugPrint("Erreur move floor map: $e");
                        }
                      });
                    }
                    return FlutterMap(
                      mapController: _floorMapController,
                      options: MapOptions(
                        crs: const CrsSimple(),
                        initialCenter: _floorCenter,
                        initialZoom: _floorInitialZoom,
                        maxZoom: _floorInitialZoom + 10,
                        minZoom: _floorInitialZoom - 10,
                        onPositionChanged: (position, hasGesture) {
                          if (hasGesture) {
                            if (_floorDebounceTimer?.isActive ?? false) {
                              _floorDebounceTimer!.cancel();
                            }
                            _floorDebounceTimer =
                                Timer(const Duration(milliseconds: 500), () {
                              _saveFloorSettings(
                                _floorMapController.camera.zoom,
                                _floorMapController.camera.center,
                              );
                            });
                          }
                        },
                        onTap: (tapPosition, point) {
                          _handleMapTapFloor(tapPosition, point);
                        },
                      ),
                      children: [
                        OverlayImageLayer(
                          overlayImages: [
                            OverlayImage(
                              bounds: LatLngBounds(
                                const LatLng(0, 0),
                                LatLng(_floorEffectiveHeight ?? 0,
                                    _floorEffectiveWidth ?? 0),
                              ),
                              opacity: 1.0,
                              imageProvider: MemoryImage(_uploadedFloorImage!),
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: _markers,
                        ),
                      ],
                    );
                  },
                )
              : Container(
                  alignment: Alignment.center,
                  child: Text(
                    "Aucune image d'étage disponible",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedEtage,
                    hint: const Text("Sélectionner un étage"),
                    items: _etages
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedEtage = value;
                      });
                      _loadFloorSettings();
                      _loadMarkersFromSite();
                    },
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _showAddFloorDialog,
                  child: const Text("Ajouter étage"),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ========================================================
  // BOUTONS FLOTTANTS
  // ========================================================
  // Boutons pour le mode site (gestion de la carte du site avec polygones)
  Widget _buildSiteFAB() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'siteModeSelection',
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (BuildContext context) {
                return SafeArea(
                  child: Wrap(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.home),
                        title: const Text('Mode bâtiment (polygon)'),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _currentSiteMode = 'polygon';
                            _currentPolygonPoints.clear();
                          });
                          debugPrint('Mode Polygon activé');
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete_forever),
                        title: const Text('Effacer les données sauvegardées'),
                        onTap: () async {
                          Navigator.pop(context);
                          await _clearSharedPreferences();
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
          tooltip: 'Options',
          child: const Icon(Icons.add),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'siteImageUpload',
          onPressed: _uploadSiteImage,
          tooltip: 'Uploader une image',
          child: const Icon(Icons.file_upload),
        ),
      ],
    );
  }

  // Boutons pour le mode étage (gestion de la carte d'étage avec markers)
  Widget _buildFloorFAB() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'floorModeSelection',
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (BuildContext context) {
                return SafeArea(
                  child: Wrap(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.map),
                        title: const Text('Recharger la carte'),
                        onTap: () {
                          Navigator.pop(context);
                          _loadFloorSettings();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.place),
                        title: const Text('Ajouter un block BAES'),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _currentFloorMode = 'marker';
                          });
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete_forever),
                        title: const Text('Effacer les données sauvegardées'),
                        onTap: () async {
                          Navigator.pop(context);
                          await _clearSharedPreferences();
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
          tooltip: "Options",
          child: const Icon(Icons.add),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'floorImageUpload',
          onPressed: _uploadFloorImage,
          tooltip: "Uploader une image",
          child: const Icon(Icons.file_upload),
        ),
      ],
    );
  }
}
