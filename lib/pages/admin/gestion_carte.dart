part of '../../main.dart';

class GestionCartePage extends StatefulWidget {
  const GestionCartePage({super.key});

  @override
  State<GestionCartePage> createState() => _GestionCartePageState();
}

class _GestionCartePageState extends State<GestionCartePage>
    with WidgetsBindingObserver {
  // Variables pour la vue site (image globale et overlays)
  double? _siteEffectiveWidth;
  double? _siteEffectiveHeight;
  final MapController _siteMapController = MapController();
  Timer? _siteDebounceTimer;
  Carte? _currentSiteCarte;

  // Reference to the SiteProvider
  late SiteProvider _siteProvider;

  // Variables pour la vue étage (image d'étage et markers)
  Uint8List? _uploadedFloorImage;
  double? _floorEffectiveWidth;
  double? _floorEffectiveHeight;
  LatLng _floorCenter = const LatLng(0, 0);
  double _floorInitialZoom = 0;
  final MapController _floorMapController = MapController();
  Timer? _floorDebounceTimer;
  int? _selectedFloorId; // ID de l'étage actuellement sélectionné

  // Mode d'affichage : false = vue site, true = vue étage
  bool _isFloorMode = false;

  // Variables pour le mode étage
  Batiment? _selectedBatiment;
  List<Etage> _batimentEtages = [];

  // Variables pour la création locale d'étages
  List<Etage> _localFloors = [];
  String? _newFloorName;

  // Variables pour la création de bâtiments
  bool _isCreatingBuilding = false;
  final List<LatLng> _buildingPoints = [];
  final List<Marker> _buildingMarkers = [];
  List<Polygon> _sitePolygons = [];

  // Variables pour l'ajout de BAES
  bool _isAddingBaes = false;
  List<Marker> _baesMarkers = [];

  // Méthode pour créer un BAES via l'API
  Future<Baes?> _createBaesViaApi(
      String name, Map<String, dynamic> position, int etageId) async {
    try {
      // Utiliser la méthode consolidée de BaesApi
      return await BaesApi.createBaes(name, position, etageId);
    } catch (e) {
      // Exception handling
      return null;
    }
  }

  // Méthode pour ajouter un BAES sur la carte
  Future<void> _addBaesMarker(LatLng point, String name) async {
    if (_selectedFloorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Aucun étage sélectionné pour ajouter un BAES")),
      );
      return;
    }

    // Préparer les données de position pour l'API
    final Map<String, dynamic> position = {
      'lat': point.latitude,
      'lng': point.longitude,
    };

    // Appeler l'API pour créer un BAES
    final baes = await _createBaesViaApi(name, position, _selectedFloorId!);

    if (baes != null) {
      // Si l'API a réussi, ajouter le marker à la carte
      setState(() {
        _baesMarkers.add(
          Marker(
            point: point,
            width: 30,
            height: 30,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lightbulb,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        );
      });

      // Rafraîchir les données du site pour s'assurer que les bâtiments sont toujours visibles après un rechargement
      _refreshSiteData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("BAES '$name' ajouté à la carte et enregistré")),
      );
    } else {
      // Si l'API a échoué, afficher un message d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la création du BAES '$name'")),
      );
    }
  }

  // Méthode pour rafraîchir les données du site
  Future<void> _refreshSiteData() async {
    try {
      final siteProvider = Provider.of<SiteProvider>(context, listen: false);
      final selectedSite = siteProvider.selectedSite;

      if (selectedSite != null) {
        // Forcer le rechargement des sites
        await siteProvider.loadSites();

        // Recharger les données de la carte du site
        await _loadSiteMapData();
      }
    } catch (e) {
      // Exception handling
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize and store reference to SiteProvider
    _siteProvider = Provider.of<SiteProvider>(context, listen: false);
    // Add listener to SiteProvider to reset map data when site selection changes
    _siteProvider.addListener(_onSiteSelectionChanged);

    // Chargement des données de la carte pour le site sélectionné
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSiteMapData();
      }
    });
  }

  // Method called when site selection changes
  void _onSiteSelectionChanged() {
    if (!mounted) return;

    // Reset site map data to ensure no data persistence
    setState(() {
      _siteEffectiveWidth = null;
      _siteEffectiveHeight = null;
      _currentSiteCarte = null;
    });

    // Reload site map data for the newly selected site
    if (mounted) {
      _loadSiteMapData();
    }
  }

  // Méthode pour charger les données de la carte du site sélectionné
  Future<void> _loadSiteMapData() async {
    if (!mounted) {
      return;
    }

    final siteProvider = Provider.of<SiteProvider>(context, listen: false);
    SiteAssociation? selectedSite = siteProvider.selectedSite;

    if (selectedSite == null) {
      return;
    }

    try {
      // Récupère la carte du site depuis l'API
      final carte = await APICarte.getCarteBySiteId(selectedSite.id);

      if (!mounted) {
        return;
      }

      if (carte != null) {
        // La carte existe, on met à jour l'affichage
        if (mounted) {
          setState(() {
            _currentSiteCarte = carte;
          });
        }

        // Déplace la carte vers les valeurs de la base de données
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _siteMapController.move(
                  LatLng(carte.centerLat, carte.centerLng), carte.zoom);
            }
          });
        }
      } else {
        // Aucune carte trouvée, on propose à l'utilisateur d'en charger une
        if (mounted) {
          setState(() {
            _currentSiteCarte = null;
          });
        }

        // Affiche une boîte de dialogue pour proposer de charger une carte
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text("Aucune carte disponible"),
                content: const Text(
                    "Aucune carte n'est disponible pour ce site. Voulez-vous en charger une?"),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text("Annuler"),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _uploadSiteImage();
                    },
                    child: const Text("Charger une carte"),
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      // Afficher un message d'erreur à l'utilisateur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors du chargement de la carte: $e")),
        );
      }
    }
  }

  // Méthode pour basculer vers la vue d'étage

  // Méthode pour basculer vers la vue site

  // Méthode pour gérer les clics sur la carte
  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    // Vérifie si le point cliqué est à l'intérieur d'un bâtiment existant
    final siteProvider = Provider.of<SiteProvider>(context, listen: false);
    SiteAssociation? selectedSite = siteProvider.selectedSite;

    if (selectedSite != null) {
      Site? site = siteProvider.getCompleteSiteById(selectedSite.id);

      if (site != null) {
        for (var batiment in site.batiments) {
          List<LatLng> polygonPoints =
              _convertBuildingPolygonPoints(batiment.polygonPoints);

          if (polygonPoints.isNotEmpty &&
              _isPointInPolygon(point, polygonPoints)) {
            // Le point est à l'intérieur d'un bâtiment existant, on affiche les informations
            _handlePolygonTap(batiment);
            return;
          }
        }
      }
    }

    // Si on est en mode ajout de BAES et qu'on est en mode étage
    if (_isAddingBaes && _isFloorMode && _selectedFloorId != null) {
      // Ajoute un marqueur BAES à l'emplacement cliqué
      _showBaesNameDialog(point);
      return;
    }

    // Si on n'est pas en mode création de bâtiment, on ne fait rien de plus
    if (!_isCreatingBuilding) return;

    // Si on n'a pas cliqué sur un bâtiment existant, on continue avec la création de bâtiment
    if (_buildingPoints.length < 4) {
      setState(() {
        _buildingPoints.add(point);
        _buildingMarkers.add(
          Marker(
            point: point,
            width: 20,
            height: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text(
                  '${_buildingPoints.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        );

        // Si on a 2 points ou plus, on peut commencer à dessiner des lignes
        if (_buildingPoints.length >= 2) {
          _updateBuildingPolygon();
        }
      });

      // Si on a 4 points, on demande le nom du bâtiment
      if (_buildingPoints.length == 4) {
        _showBuildingNameDialog();
      }
    }
  }

  // Affiche une boîte de dialogue pour demander le nom du BAES
  void _showBaesNameDialog(LatLng point) {
    if (_selectedFloorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun étage sélectionné")),
      );
      return;
    }

    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Nouveau BAES"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Entrez un nom pour ce BAES:"),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: "Nom du BAES"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                Navigator.of(context).pop();
                _addBaesMarker(point, name);
              },
              child: const Text("Créer"),
            ),
          ],
        );
      },
    );
  }

  // Vérifie si un point est à l'intérieur d'un polygone (algorithme du ray casting)
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    // Implémentation de l'algorithme du ray casting
    // https://en.wikipedia.org/wiki/Point_in_polygon

    bool isInside = false;
    int i = 0, j = polygon.length - 1;

    for (i = 0; i < polygon.length; i++) {
      if (((polygon[i].latitude > point.latitude) !=
              (polygon[j].latitude > point.latitude)) &&
          (point.longitude <
              (polygon[j].longitude - polygon[i].longitude) *
                      (point.latitude - polygon[i].latitude) /
                      (polygon[j].latitude - polygon[i].latitude) +
                  polygon[i].longitude)) {
        isInside = !isInside;
      }
      j = i;
    }

    return isInside;
  }

  // Met à jour le polygone du bâtiment en cours de création
  void _updateBuildingPolygon() {
    setState(() {
      _sitePolygons = [
        Polygon(
          points: _buildingPoints,
          color: Colors.blue.withOpacity(0.3),
          borderColor: Colors.blue,
          borderStrokeWidth: 2,
        ),
      ];
    });
  }

  // Affiche une boîte de dialogue pour demander le nom du bâtiment
  void _showBuildingNameDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Nom du bâtiment"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: "Entrez le nom du bâtiment",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Annuler la création du bâtiment
                setState(() {
                  _isCreatingBuilding = false;
                  _buildingPoints.clear();
                  _buildingMarkers.clear();
                  _sitePolygons.clear();
                });
                Navigator.of(context).pop();
              },
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  _saveBuildingToDatabase(nameController.text);
                  Navigator.of(context).pop();
                }
              },
              child: const Text("Valider"),
            ),
          ],
        );
      },
    );
  }

  // Sauvegarde le bâtiment dans la base de données
  Future<void> _saveBuildingToDatabase(String name) async {
    if (!mounted) {
      return;
    }

    final siteProvider = Provider.of<SiteProvider>(context, listen: false);
    SiteAssociation? selectedSite = siteProvider.selectedSite;

    if (selectedSite == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun site sélectionné")),
      );
      return;
    }

    // Affiche un indicateur de chargement
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Création du bâtiment en cours..."),
            ],
          ),
        );
      },
    );

    try {
      // Appelle l'API pour créer le bâtiment
      final batiment = await APIBatiment.createBatiment(
        name,
        _buildingPoints,
        selectedSite.id,
      );

      // Vérifie si le widget est toujours monté après l'opération asynchrone
      if (!mounted) {
        return;
      }

      // Ferme le dialogue de chargement
      Navigator.of(context).pop();

      if (batiment != null) {
        // Le bâtiment a été créé avec succès
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Bâtiment '$name' créé avec succès")),
        );

        // Réinitialise les variables de création de bâtiment
        if (!mounted) return;
        setState(() {
          _isCreatingBuilding = false;
          _buildingPoints.clear();
          _buildingMarkers.clear();
          _sitePolygons.clear();
        });

        // Met à jour le site dans la liste Site.allSites avec le nouveau bâtiment
        _updateSiteWithNewBatiment(selectedSite.id, batiment);

        // Recharge les données du site pour afficher le nouveau bâtiment
        if (!mounted) return;
        _loadSiteMapData();
      } else {
        // Erreur lors de la création du bâtiment
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Erreur lors de la création du bâtiment")),
        );
      }
    } catch (e) {
      // Vérifie si le widget est toujours monté après l'opération asynchrone
      if (!mounted) {
        return;
      }

      // Ferme le dialogue de chargement en cas d'erreur
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e")),
      );
    }
  }

  // Met à jour le site dans la liste Site.allSites avec le nouveau bâtiment
  void _updateSiteWithNewBatiment(int siteId, Batiment newBatiment) {
    // Trouve l'index du site dans la liste Site.allSites
    final siteIndex = Site.allSites.indexWhere((site) => site.id == siteId);

    if (siteIndex >= 0) {
      // Récupère le site existant
      final existingSite = Site.allSites[siteIndex];

      // Crée une nouvelle liste de bâtiments incluant le nouveau bâtiment
      final updatedBatiments = List<Batiment>.from(existingSite.batiments);

      // Vérifie si le bâtiment existe déjà dans la liste
      final existingBatimentIndex =
          updatedBatiments.indexWhere((b) => b.id == newBatiment.id);

      if (existingBatimentIndex >= 0) {
        // Remplace le bâtiment existant
        updatedBatiments[existingBatimentIndex] = newBatiment;
      } else {
        // Ajoute le nouveau bâtiment
        updatedBatiments.add(newBatiment);
      }

      // Crée un nouveau site avec la liste de bâtiments mise à jour
      final updatedSite = Site(
        id: existingSite.id,
        name: existingSite.name,
        batiments: updatedBatiments,
        carte: existingSite.carte,
      );

      // Remplace l'ancien site dans la liste
      Site.allSites[siteIndex] = updatedSite;
    }
  }

  // Méthode pour gérer les clics sur les polygones des bâtiments
  void _handlePolygonTap(Batiment batiment) {
    // Récupère le site sélectionné
    Provider.of<SiteProvider>(context, listen: false);

    // Si on est en mode création de bâtiment, on affiche la popup de modification/suppression
    if (_isCreatingBuilding) {
      _showBuildingEditDialog(batiment);
    } else {
      // Sinon, on passe en mode étage et on charge les étages du bâtiment
      _switchToBuildingMode(batiment);
    }
  }

  // Méthode pour passer en mode bâtiment (affichage des étages)
  Future<void> _switchToBuildingMode(Batiment batiment) async {
    setState(() {
      _selectedBatiment = batiment;
      _isFloorMode = true;
      _batimentEtages = []; // Réinitialise la liste des étages
    });

    try {
      // Récupère toutes les données du bâtiment (étages, cartes, BAES) en une seule requête
      final updatedBatiment = await APIBatiment.getBuildingAllData(batiment.id);

      if (!mounted) {
        return;
      }

      // Si le bâtiment mis à jour est récupéré avec succès, on le met à jour dans _selectedBatiment
      if (updatedBatiment != null) {
        // Conserve le siteId du bâtiment original si celui du bâtiment mis à jour est null
        if (updatedBatiment.siteId == null && batiment.siteId != null) {
          // Crée une nouvelle instance de Batiment avec le siteId du bâtiment original
          _selectedBatiment = Batiment(
            id: updatedBatiment.id,
            name: updatedBatiment.name,
            polygonPoints: updatedBatiment.polygonPoints,
            siteId: batiment.siteId,
            // Utilise le siteId du bâtiment original
            etages: updatedBatiment.etages,
          );
        } else {
          _selectedBatiment = updatedBatiment;
        }
      }

      if (updatedBatiment != null && updatedBatiment.etages.isNotEmpty) {
        setState(() {
          _batimentEtages = updatedBatiment.etages;
          // Sélectionne le premier étage par défaut
          _selectedFloorId = updatedBatiment.etages.first.id;
        });

        // Charge les données de la carte pour l'étage sélectionné
        if (_selectedFloorId != null) {
          _loadFloorMapData(_selectedFloorId!);
        }
      } else {
        // Aucun étage trouvé, affiche un message mais reste en mode étage
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Aucun étage trouvé pour le bâtiment : ${batiment.name}")),
        );
        // Reste en mode étage pour permettre la création d'étages
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      // Erreur lors de la récupération des données du bâtiment, affiche un message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "Erreur lors de la récupération des données du bâtiment: $e")),
      );
      // Reste en mode étage malgré l'erreur
    }
  }

  // Méthode pour revenir en mode site
  void _switchToSiteMode() {
    setState(() {
      _isFloorMode = false;
      _selectedBatiment = null;
      _selectedFloorId = null;
      _batimentEtages = [];
    });
  }

  // Méthode pour charger les BAES d'un étage
  Future<void> _loadBaesForFloor(int etageId) async {
    try {
      // Récupère les BAES de l'étage
      final baes = await BaesApi.getBaesByIdFloor(etageId);

      if (!mounted) {
        return;
      }

      // Créer une liste temporaire pour stocker les nouveaux marqueurs
      List<Marker> newMarkers = [];

      if (baes.isNotEmpty) {
        // Créer des marqueurs pour les BAES récupérés
        for (var baes in baes) {
          // Vérifier que la position est valide
          if (baes.position.containsKey('lat') &&
              baes.position.containsKey('lng')) {
            final lat = baes.position['lat'];
            final lng = baes.position['lng'];

            if (lat != null && lng != null) {
              newMarkers.add(
                Marker(
                  point: LatLng(lat, lng),
                  width: 30,
                  height: 30,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lightbulb,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              );
            }
          }
        }

        // Mettre à jour la liste des marqueurs en conservant les marqueurs existants
        setState(() {
          // Ajouter uniquement les nouveaux marqueurs qui ne sont pas déjà présents
          for (var newMarker in newMarkers) {
            bool markerExists = false;
            for (var existingMarker in _baesMarkers) {
              if (existingMarker.point.latitude == newMarker.point.latitude &&
                  existingMarker.point.longitude == newMarker.point.longitude) {
                markerExists = true;
                break;
              }
            }

            if (!markerExists) {
              _baesMarkers.add(newMarker);
            }
          }
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      // Erreur lors de la récupération des BAES, affiche un message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la récupération des BAES: $e")),
      );
    }
  }

  // Affiche une boîte de dialogue pour modifier ou supprimer un bâtiment
  void _showBuildingEditDialog(Batiment batiment) {
    final TextEditingController nameController =
        TextEditingController(text: batiment.name);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Modifier le bâtiment"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: "Entrez le nouveau nom du bâtiment",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () {
                _showDeleteConfirmationDialog(batiment);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text("Supprimer"),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  _updateBuildingInDatabase(batiment.id, nameController.text);
                  Navigator.of(context).pop();
                }
              },
              child: const Text("Modifier"),
            ),
          ],
        );
      },
    );
  }

  // Affiche une boîte de dialogue de confirmation pour la suppression d'un bâtiment
  void _showDeleteConfirmationDialog(Batiment batiment) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmation de suppression"),
          content: Text(
              "Êtes-vous sûr de vouloir supprimer le bâtiment '${batiment.name}' ?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(); // Ferme la boîte de dialogue de confirmation
                Navigator.of(context)
                    .pop(); // Ferme la boîte de dialogue d'édition
                _deleteBuildingFromDatabase(batiment.id);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text("Supprimer"),
            ),
          ],
        );
      },
    );
  }

  // Met à jour le bâtiment dans la base de données
  Future<void> _updateBuildingInDatabase(int batimentId, String newName) async {
    if (!mounted) return;

    // Affiche un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Mise à jour du bâtiment en cours..."),
            ],
          ),
        );
      },
    );

    try {
      // Appelle l'API pour mettre à jour le bâtiment
      final batiment = await APIBatiment.updateBatiment(
        batimentId,
        newName,
      );

      // Vérifie si le widget est toujours monté après l'opération asynchrone
      if (!mounted) return;

      // Ferme le dialogue de chargement
      Navigator.of(context).pop();

      if (batiment != null) {
        // Le bâtiment a été mis à jour avec succès
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bâtiment mis à jour avec succès")),
        );

        // Met à jour le site dans la liste Site.allSites avec le bâtiment mis à jour
        _updateSiteWithUpdatedBatiment(batiment);

        // Recharge les données du site pour afficher le bâtiment mis à jour
        if (!mounted) return;
        _loadSiteMapData();
      } else {
        // Erreur lors de la mise à jour du bâtiment
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Erreur lors de la mise à jour du bâtiment")),
        );
      }
    } catch (e) {
      // Vérifie si le widget est toujours monté après l'opération asynchrone
      if (!mounted) return;

      // Ferme le dialogue de chargement en cas d'erreur
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e")),
      );
    }
  }

  // Supprime le bâtiment de la base de données
  Future<void> _deleteBuildingFromDatabase(int batimentId) async {
    if (!mounted) return;

    // Affiche un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Suppression du bâtiment en cours..."),
            ],
          ),
        );
      },
    );

    try {
      // Appelle l'API pour supprimer le bâtiment
      final success = await APIBatiment.deleteBatiment(batimentId);

      // Vérifie si le widget est toujours monté après l'opération asynchrone
      if (!mounted) return;

      // Ferme le dialogue de chargement
      Navigator.of(context).pop();

      if (success) {
        // Le bâtiment a été supprimé avec succès
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bâtiment supprimé avec succès")),
        );

        // Recharge toutes les données depuis l'API pour mettre à jour l'affichage
        if (!mounted) return;
        await getGeneralInfos(context);

        // Recharge les données du site pour mettre à jour l'affichage
        if (!mounted) return;
        _loadSiteMapData();
      } else {
        // Erreur lors de la suppression du bâtiment
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Erreur lors de la suppression du bâtiment")),
        );
      }
    } catch (e) {
      // Vérifie si le widget est toujours monté après l'opération asynchrone
      if (!mounted) return;

      // Ferme le dialogue de chargement en cas d'erreur
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e")),
      );
    }
  }

  // Met à jour le site dans la liste Site.allSites avec le bâtiment mis à jour
  void _updateSiteWithUpdatedBatiment(Batiment updatedBatiment) {
    // Trouve le site qui contient ce bâtiment
    for (var site in Site.allSites) {
      final batimentIndex =
          site.batiments.indexWhere((b) => b.id == updatedBatiment.id);
      if (batimentIndex >= 0) {
        // Crée une nouvelle liste de bâtiments avec le bâtiment mis à jour
        final updatedBatiments = List<Batiment>.from(site.batiments);
        updatedBatiments[batimentIndex] = updatedBatiment;

        // Crée un nouveau site avec la liste de bâtiments mise à jour
        final updatedSite = Site(
          id: site.id,
          name: site.name,
          batiments: updatedBatiments,
          carte: site.carte,
        );

        // Remplace l'ancien site dans la liste
        final siteIndex = Site.allSites.indexOf(site);
        Site.allSites[siteIndex] = updatedSite;

        break;
      }
    }
  }

  // Supprime le bâtiment du site dans la liste Site.allSites

  // Convertit les points du polygone d'un bâtiment en liste de LatLng
  List<LatLng> _convertBuildingPolygonPoints(dynamic polygonPoints) {
    if (polygonPoints == null) {
      return [];
    }

    try {
      if (polygonPoints is Map && polygonPoints.containsKey('points')) {
        final List<dynamic> points = polygonPoints['points'];

        return points.map((point) {
          if (point is List && point.length >= 2) {
            return LatLng(point[0].toDouble(), point[1].toDouble());
          }
          return const LatLng(0, 0);
        }).toList();
      } else {
        // polygonPoints is not a Map or doesn't contain the 'points' key
      }
    } catch (e) {
      // Gérer l'erreur ici si nécessaire
    }

    return [];
  }

  // Récupère tous les polygones des bâtiments pour un site donné
  List<Polygon> _getBuildingPolygons(int siteId) {
    List<Polygon> polygons = [];

    try {
      // Récupère le site complet avec ses bâtiments
      final siteProvider = Provider.of<SiteProvider>(context, listen: false);
      Site? site = siteProvider.getCompleteSiteById(siteId);

      if (site != null) {
        // Pour chaque bâtiment du site, crée un polygone
        for (var batiment in site.batiments) {
          List<LatLng> points =
              _convertBuildingPolygonPoints(batiment.polygonPoints);

          if (points.isNotEmpty) {
            polygons.add(
              Polygon(
                points: points,
                color: Colors.green.withOpacity(0.3),
                borderColor: Colors.green,
                borderStrokeWidth: 2,
              ),
            );
          }
        }
      }
    } catch (e) {
      // Gérer l'erreur ici si nécessaire
    }

    return polygons;
  }

  // Méthode pour charger les données de la carte d'un étage
  Future<void> _loadFloorMapData(int floorId) async {
    if (!mounted) {
      return;
    }

    _selectedFloorId = floorId;

    // Load floor map data
    try {
      // Recherche la carte de l'étage dans la liste statique
      Carte? floorCarte;
      for (var carte in Carte.allCartes) {
        if (carte.etageId == floorId) {
          floorCarte = carte;
          print(
              "Carte trouvée dans la liste statique: ID=${carte.id}, chemin=${carte.chemin}");
          break;
        }
      }

      if (floorCarte == null) {
        print(
            "Aucune carte trouvée dans la liste statique pour l'étage ID: $floorId");
      } else if (floorCarte.chemin.isEmpty) {
        print("Carte trouvée dans la liste statique mais le chemin est vide");
      }

      // Si la carte n'est pas trouvée dans la liste statique ou si le chemin est vide,
      // essaie de la récupérer depuis l'API
      if (floorCarte == null || floorCarte.chemin.isEmpty) {
        print(
            "Récupération de la carte depuis l'API pour l'étage ID: $floorId");
        // Récupère la carte depuis l'API
        final apiCarte = await BaesApi.getFloorMapByFloorId(floorId);

        if (apiCarte != null) {
          print(
              "Carte récupérée depuis l'API: ID=${apiCarte.id}, chemin=${apiCarte.chemin}");
          floorCarte = apiCarte;
        } else {
          print(
              "Aucune carte récupérée depuis l'API pour l'étage ID: $floorId");
        }
      }

      if (!mounted) {
        print("Widget non monté après la requête API, abandon du traitement");
        return;
      }

      if (floorCarte != null) {
        print("Carte disponible pour l'affichage: ID=${floorCarte.id}");
        print(
            "Coordonnées: centerLat=${floorCarte.centerLat}, centerLng=${floorCarte.centerLng}, zoom=${floorCarte.zoom}");
        // La carte existe, on met à jour l'affichage
        if (mounted) {
          setState(() {
            print("Mise à jour de l'état avec la carte de l'étage");
            // Stocke les valeurs de centre et zoom pour les réutiliser
            _floorCenter = LatLng(floorCarte!.centerLat, floorCarte.centerLng);
            _floorInitialZoom = floorCarte.zoom;
            print(
                "Valeurs mises à jour: centre=(${_floorCenter.latitude}, ${_floorCenter.longitude}), zoom=$_floorInitialZoom");
          });
        }

        // Déplace la carte vers les valeurs stockées
        if (mounted) {
          print(
              "Déplacement de la carte d'étage vers les coordonnées stockées");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              try {
                _floorMapController.move(_floorCenter, _floorInitialZoom);
                print(
                    "Carte d'étage déplacée aux coordonnées: lat=${_floorCenter.latitude}, lng=${_floorCenter.longitude}, zoom=$_floorInitialZoom");
              } catch (e) {
                // The map controller might not be ready yet
                print("ERREUR: Impossible de déplacer la carte d'étage: $e");
              }
            }
          });
        }

        // Charge les BAES de l'étage
        if (mounted) {
          print("Chargement des BAES pour l'étage ID: $floorId");
          _loadBaesForFloor(floorId);
        }
      } else {
        print("Aucune carte disponible pour l'étage ID: $floorId");
        // Aucune carte trouvée, on propose à l'utilisateur d'en charger une
        if (mounted) {
          setState(() {
            print(
                "Mise à jour de l'état: aucune carte disponible pour l'étage");
          });
        }

        // Affiche une boîte de dialogue pour proposer de charger une carte
        if (mounted) {
          print(
              "Affichage de la boîte de dialogue pour charger une carte d'étage");
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text("Aucune carte disponible"),
                content: const Text(
                    "Aucune carte n'est disponible pour cet étage. Voulez-vous en charger une?"),
                actions: [
                  TextButton(
                    onPressed: () {
                      print(
                          "Utilisateur a annulé le chargement de carte d'étage");
                      Navigator.of(context).pop();
                    },
                    child: const Text("Annuler"),
                  ),
                  TextButton(
                    onPressed: () {
                      print(
                          "Utilisateur a choisi de charger une carte d'étage");
                      Navigator.of(context).pop();
                      _uploadFloorImage();
                    },
                    child: const Text("Charger une carte"),
                  ),
                ],
              );
            },
          );
        }
      }
      print("=== FIN DU CHARGEMENT DES DONNÉES DE CARTE D'ÉTAGE ===");
    } catch (e) {
      print("EXCEPTION lors du chargement des données de carte d'étage: $e");
      // Afficher un message d'erreur à l'utilisateur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text("Erreur lors du chargement de la carte d'étage: $e")),
        );
      }
    }
  }

  // Méthode pour mettre à jour les données de la carte dans la base de données
  Future<void> _updateMapDataInDatabase() async {
    if (!mounted) return;

    if (_currentSiteCarte == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucune carte sélectionnée")),
      );
      return;
    }

    // Récupère le site sélectionné
    final siteProvider = Provider.of<SiteProvider>(context, listen: false);
    SiteAssociation? selectedSite = siteProvider.selectedSite;

    if (selectedSite == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun site sélectionné")),
      );
      return;
    }

    // Récupère la position et le zoom actuels
    final currentCenter = _siteMapController.camera.center;
    final currentZoom = _siteMapController.camera.zoom;

    // Affiche un indicateur de chargement
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Mise à jour de la carte en cours..."),
            ],
          ),
        );
      },
    );

    try {
      // Appelle l'API pour mettre à jour la carte par l'ID du site
      final updatedCarte = await APICarte.updateCarteBySiteId(
        selectedSite.id,
        currentCenter.latitude,
        currentCenter.longitude,
        currentZoom,
      );

      // Vérifie si le widget est toujours monté après l'opération asynchrone
      if (!mounted) return;

      // Ferme le dialogue de chargement
      Navigator.of(context).pop();

      if (updatedCarte != null) {
        // La carte a été mise à jour avec succès
        if (!mounted) return;
        setState(() {
          _currentSiteCarte = updatedCarte;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Carte mise à jour avec succès")),
        );
      } else {
        // Erreur lors de la mise à jour
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Erreur lors de la mise à jour de la carte")),
        );
      }
    } catch (e) {
      // Vérifie si le widget est toujours monté après l'opération asynchrone
      if (!mounted) return;

      // Ferme le dialogue de chargement en cas d'erreur
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e")),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Reset map data when the app is resumed to ensure no data persistence
      if (_isFloorMode) {
        // Reset floor map data
        if (mounted) {
          setState(() {
            _floorEffectiveWidth = null;
            _floorEffectiveHeight = null;
            _floorCenter = const LatLng(0, 0);
            _floorInitialZoom = 0;
            _uploadedFloorImage = null;
          });
        }

        // Si on est en mode étage, on charge les données de l'étage
        if (_selectedFloorId != null && _selectedFloorId! > 0 && mounted) {
          _loadFloorMapData(_selectedFloorId!);
        }
      } else {
        // Reset site map data
        if (mounted) {
          setState(() {
            _siteEffectiveWidth = null;
            _siteEffectiveHeight = null;
            _currentSiteCarte = null;
          });
        }

        if (mounted) {
          _loadSiteMapData();
        }
      }
    }
  }

  // Affiche une boîte de dialogue pour modifier ou supprimer un étage
  void _showFloorEditDialog() {
    if (_selectedFloorId == null || _selectedFloorId! <= 0) return;

    // Trouve l'étage sélectionné
    Etage? selectedFloor;
    for (var floor in _batimentEtages) {
      if (floor.id == _selectedFloorId) {
        selectedFloor = floor;
        break;
      }
    }

    if (selectedFloor == null) return;

    final TextEditingController nameController =
        TextEditingController(text: selectedFloor.name);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Modifier l'étage"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: "Entrez le nouveau nom de l'étage",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () {
                _showFloorDeleteConfirmationDialog(selectedFloor!);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text("Supprimer"),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  _updateFloor(selectedFloor!.id, nameController.text);
                  Navigator.of(context).pop();
                }
              },
              child: const Text("Modifier"),
            ),
          ],
        );
      },
    );
  }

  // Affiche une boîte de dialogue de confirmation pour la suppression d'un étage
  void _showFloorDeleteConfirmationDialog(Etage floor) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmation de suppression"),
          content: Text(
              "Êtes-vous sûr de vouloir supprimer l'étage '${floor.name}' ?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(); // Ferme la boîte de dialogue de confirmation
                Navigator.of(context)
                    .pop(); // Ferme la boîte de dialogue d'édition
                _deleteFloor(floor.id);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text("Supprimer"),
            ),
          ],
        );
      },
    );
  }

  // Met à jour l'étage dans la base de données
  Future<void> _updateFloor(int floorId, String newName) async {
    if (!mounted) return;

    // Affiche un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Mise à jour de l'étage en cours..."),
            ],
          ),
        );
      },
    );

    try {
      // Appelle l'API pour mettre à jour l'étage
      final updatedFloor = await BaesApi.updateFloor(floorId, newName);

      // Vérifie si le widget est toujours monté après l'opération asynchrone
      if (!mounted) return;

      // Ferme le dialogue de chargement
      Navigator.of(context).pop();

      if (updatedFloor != null) {
        // L'étage a été mis à jour avec succès
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Étage mis à jour avec succès")),
        );

        // Met à jour l'étage dans la liste des étages
        setState(() {
          final index =
              _batimentEtages.indexWhere((floor) => floor.id == floorId);
          if (index >= 0) {
            _batimentEtages[index] = updatedFloor;
          }
        });
      } else {
        // Erreur lors de la mise à jour de l'étage
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Erreur lors de la mise à jour de l'étage")),
        );
      }
    } catch (e) {
      // Vérifie si le widget est toujours monté après l'opération asynchrone
      if (!mounted) return;

      // Ferme le dialogue de chargement en cas d'erreur
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e")),
      );
    }
  }

  // Supprime l'étage de la base de données
  Future<void> _deleteFloor(int floorId) async {
    if (!mounted) return;

    // Affiche un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Suppression de l'étage en cours..."),
            ],
          ),
        );
      },
    );

    try {
      // Appelle l'API pour supprimer l'étage
      final success = await BaesApi.deleteFloor(floorId);

      // Vérifie si le widget est toujours monté après l'opération asynchrone
      if (!mounted) return;

      // Ferme le dialogue de chargement
      Navigator.of(context).pop();

      if (success) {
        // L'étage a été supprimé avec succès
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Étage supprimé avec succès")),
        );

        // Supprime l'étage de la liste des étages
        setState(() {
          _batimentEtages.removeWhere((floor) => floor.id == floorId);

          // Si l'étage supprimé était l'étage sélectionné, sélectionne le premier étage de la liste
          if (_selectedFloorId == floorId) {
            _selectedFloorId =
                _batimentEtages.isNotEmpty ? _batimentEtages.first.id : null;

            // Charge les données de la carte pour le nouvel étage sélectionné
            if (_selectedFloorId != null && _selectedFloorId! > 0) {
              _loadFloorMapData(_selectedFloorId!);
            }
          }
        });
      } else {
        // Erreur lors de la suppression de l'étage
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Erreur lors de la suppression de l'étage")),
        );
      }
    } catch (e) {
      // Vérifie si le widget est toujours monté après l'opération asynchrone
      if (!mounted) return;

      // Ferme le dialogue de chargement en cas d'erreur
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e")),
      );
    }
  }

  @override
  void dispose() {
    _floorDebounceTimer?.cancel();
    _siteDebounceTimer?.cancel();

    // Remove listener from SiteProvider using the stored reference
    _siteProvider.removeListener(_onSiteSelectionChanged);

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // --------------------------------------------------------------------
  // Chargement de l'image du site avec calcul du initialZoom et du centre
  // --------------------------------------------------------------------
  Future<void> _uploadSiteImage() async {
    if (!mounted) return;

    // Récupère le site sélectionné
    final siteProvider = Provider.of<SiteProvider>(context, listen: false);
    SiteAssociation? selectedSite = siteProvider.selectedSite;

    if (selectedSite == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun site sélectionné")),
      );
      return;
    }

    // Ouvre le sélecteur de fichiers
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (!mounted) return;

    if (result != null && result.files.single.bytes != null) {
      final Uint8List imageBytes = result.files.single.bytes!;

      // Affiche un indicateur de chargement
      if (!mounted) return;

      // Utiliser une variable pour suivre si le dialog est affiché
      bool isDialogShowing = true;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Téléchargement de l'image en cours..."),
              ],
            ),
          );
        },
      );

      try {
        // Créer un completer pour attendre la fin du décodage de l'image
        Completer<Map<String, dynamic>> imageDataCompleter = Completer();

        // Décode l'image pour obtenir ses dimensions
        ui.decodeImageFromList(imageBytes, (ui.Image img) {
          if (!mounted) {
            if (!imageDataCompleter.isCompleted) {
              imageDataCompleter.completeError("Widget not mounted");
            }
            return;
          }

          double originalWidth = img.width.toDouble();
          double originalHeight = img.height.toDouble();
          // Calcul d'un facteur d'échelle pour obtenir des dimensions raisonnables.
          double scaleFactor = min(90 / originalHeight, 180 / originalWidth);
          double effectiveWidth = originalWidth * scaleFactor;
          double effectiveHeight = originalHeight * scaleFactor;
          // Clamp afin de ne pas dépasser les bornes géographiques autorisées.
          effectiveHeight = min(effectiveHeight, 90.0);
          effectiveWidth = min(effectiveWidth, 180.0);
          // Définition du centre de l'image en prenant le milieu.
          LatLng initialCenter =
              LatLng(effectiveHeight / 2, effectiveWidth / 2);

          // Calcul du initialZoom en fonction de la taille de l'écran.
          if (!mounted) {
            if (!imageDataCompleter.isCompleted) {
              imageDataCompleter.completeError("Widget not mounted");
            }
            return;
          }

          final Size screenSize = MediaQuery.of(context).size;
          double scale = min(screenSize.width / effectiveWidth,
              screenSize.height / effectiveHeight);
          double initialZoom = log(scale) / log(2);
          initialZoom = initialZoom.clamp(-1.0, 2.0);

          // Compléter avec les données de l'image
          if (!imageDataCompleter.isCompleted) {
            imageDataCompleter.complete({
              'effectiveWidth': effectiveWidth,
              'effectiveHeight': effectiveHeight,
              'initialCenter': initialCenter,
              'initialZoom': initialZoom,
            });
          }
        });

        // Attendre les données de l'image avec un timeout
        Map<String, dynamic> imageData;
        try {
          imageData = await imageDataCompleter.future
              .timeout(const Duration(seconds: 10), onTimeout: () {
            throw TimeoutException("Décodage de l'image trop long");
          });
        } catch (e) {
          // Fermer le dialogue si une erreur se produit pendant le décodage
          if (isDialogShowing && mounted) {
            Navigator.of(context).pop();
            isDialogShowing = false;
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      "Erreur lors du décodage de l'image: ${e.toString()}")),
            );
          }
          return;
        }

        // Extraire les données
        double effectiveWidth = imageData['effectiveWidth'];
        double effectiveHeight = imageData['effectiveHeight'];
        LatLng initialCenter = imageData['initialCenter'];
        double initialZoom = imageData['initialZoom'];

        // Télécharge l'image vers l'API
        final carte = await APICarte.uploadSiteImage(
          selectedSite.id,
          imageBytes,
          initialCenter,
          initialZoom,
        );

        // Ferme le dialogue de chargement, qu'importe le résultat
        if (isDialogShowing && mounted) {
          Navigator.of(context).pop();
          isDialogShowing = false;
        }

        // Vérifie si le widget est toujours monté après l'opération asynchrone
        if (!mounted) return;

        if (carte != null) {
          // L'image a été téléchargée avec succès
          setState(() {
            _siteEffectiveWidth = effectiveWidth;
            _siteEffectiveHeight = effectiveHeight;
          });

          // Rafraîchit les données de la carte
          _loadSiteMapData();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Carte téléchargée avec succès")),
          );
        } else {
          // Erreur lors du téléchargement
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Erreur lors du téléchargement de la carte")),
          );
        }
      } catch (e) {
        // Ferme le dialogue en cas d'erreur
        if (isDialogShowing && mounted) {
          Navigator.of(context).pop();
          isDialogShowing = false;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur inattendue: ${e.toString()}")),
          );
        }
      }
    }
  }

  // --------------------------------------------------------------------
  // Chargement de l'image d'un étage avec calcul du initialZoom et du centre
  // --------------------------------------------------------------------
  Future<void> _uploadFloorImage() async {
    if (!mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (!mounted) return;

    if (result != null && result.files.single.bytes != null) {
      final Uint8List imageBytes = result.files.single.bytes!;
      ui.decodeImageFromList(imageBytes, (ui.Image img) {
        if (!mounted) return;

        double originalWidth = img.width.toDouble();
        double originalHeight = img.height.toDouble();
        double scaleFactor = min(90 / originalHeight, 180 / originalWidth);
        double effectiveWidth = originalWidth * scaleFactor;
        double effectiveHeight = originalHeight * scaleFactor;
        // Clamp des dimensions pour éviter d'excéder les valeurs autorisées.
        effectiveHeight = min(effectiveHeight, 90.0);
        effectiveWidth = min(effectiveWidth, 180.0);
        LatLng initialCenter = LatLng(effectiveHeight / 2, effectiveWidth / 2);

        if (!mounted) return;
        final Size screenSize = MediaQuery.of(context).size;
        double scale = min(screenSize.width / effectiveWidth,
            screenSize.height / effectiveHeight);
        double initialZoom = log(scale) / log(2);
        initialZoom = initialZoom.clamp(-1.0, 2.0);

        if (!mounted) return;
        setState(() {
          _uploadedFloorImage = imageBytes;
          _floorEffectiveWidth = effectiveWidth;
          _floorEffectiveHeight = effectiveHeight;
          _floorCenter = initialCenter;
          _floorInitialZoom = initialZoom;
        });

        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            _floorMapController.move(_floorCenter, _floorInitialZoom);
            setState(() {});
          } catch (e) {
            // The map controller might not be ready yet, we'll set the position when the map is rendered
          }
        });

        // Affiche une boîte de dialogue pour demander le nom de l'étage seulement si on n'a pas déjà sélectionné un étage
        // ou si l'étage sélectionné n'a pas encore de nom

        // Vérifie si l'étage sélectionné existe dans _batimentEtages et a déjà un nom
        bool floorHasName = false;
        if (_selectedFloorId != null) {
          // Cherche l'étage dans la liste des étages du bâtiment
          for (var floor in _batimentEtages) {
            if (floor.id == _selectedFloorId && floor.name.isNotEmpty) {
              floorHasName = true;
              break;
            }
          }
        }

        // Si l'étage n'existe pas ou n'a pas de nom, affiche la boîte de dialogue
        if (!floorHasName) {
          _showFloorNameDialog();
        }
      });
    }
  }

  // Affiche une boîte de dialogue pour demander le nom de l'étage
  void _showFloorNameDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Nom de l'étage"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: "Entrez le nom de l'étage",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Annuler la création de l'étage
                setState(() {
                  _uploadedFloorImage = null;
                  _newFloorName = null;
                });
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  _createFloorWithName(nameController.text);
                  Navigator.of(context).pop();
                }
              },
              child: const Text("Valider"),
            ),
          ],
        );
      },
    );
  }

  // Crée un étage local avec le nom donné
  void _createFloorWithName(String name) {
    if (_selectedBatiment == null) return;

    // Crée un ID temporaire négatif pour l'étage local
    // Les IDs négatifs indiquent que l'étage n'existe pas encore dans la base de données
    final int tempId = -(_localFloors.length + 1);

    // Crée un nouvel étage local
    final Etage newFloor = Etage(
      id: tempId,
      name: name,
      batimentId: _selectedBatiment!.id,
      baes: [],
    );

    setState(() {
      _newFloorName = name;
      _localFloors.add(newFloor);
      _batimentEtages
          .add(newFloor); // Ajoute l'étage à la liste des étages affichés
      _selectedFloorId = tempId; // Sélectionne le nouvel étage
    });
  }

  // --------------------------------------------------------------------
  // Vue du site utilisant OverlayImageLayer
  // --------------------------------------------------------------------
  Widget _buildSiteView() {
    // Récupère le provider.
    final siteProvider = Provider.of<SiteProvider>(context);
    SiteAssociation? selectedSite = siteProvider.selectedSite;

    if (selectedSite == null) {
      return Center(
        child: Text(
          "Aucun site sélectionné",
          style: Theme.of(context).textTheme.titleLarge,
        ),
      );
    }

    // Recherche la carte du site dans la liste statique
    Carte? siteCarte;
    for (var carte in Carte.allCartes) {
      if (carte.siteId == selectedSite.id) {
        siteCarte = carte;
        break;
      }
    }

    // Si aucune carte n'est trouvée, propose d'en charger une
    if (siteCarte == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Aucune carte disponible pour le site : ${selectedSite.name}",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploadSiteImage,
              child: const Text("Charger une carte"),
            ),
          ],
        ),
      );
    }

    // Récupère les dimensions de l'image si elles ne sont pas déjà définies
    if (_siteEffectiveHeight == null || _siteEffectiveWidth == null) {
      _getImageDimensions(siteCarte.chemin);

      // Utilise des valeurs par défaut en attendant que les dimensions réelles soient chargées
      _siteEffectiveHeight ??= 775.0;
      _siteEffectiveWidth ??= 1200.0;
    }

    // Normalisation des dimensions pour respecter les contraintes latitude <= 90 et longitude <= 180.
    double effectiveHeight = _siteEffectiveHeight!;
    double effectiveWidth = _siteEffectiveWidth!;
    const double maxValidLat = 90.0;
    const double maxValidLng = 180.0;
    double scaleFactor = 1.0;

    // Calcul du facteur d'échelle pour la latitude
    if (effectiveHeight > maxValidLat) {
      scaleFactor = maxValidLat / effectiveHeight;
    }

    // Calcul du facteur d'échelle pour la longitude
    if (effectiveWidth > maxValidLng) {
      double lngScaleFactor = maxValidLng / effectiveWidth;
      // Utilise le facteur d'échelle le plus restrictif
      scaleFactor = min(scaleFactor, lngScaleFactor);
    }

    double normalizedHeight = effectiveHeight * scaleFactor;
    double normalizedWidth = effectiveWidth * scaleFactor;

    // Utilise les coordonnées de la carte récupérée depuis l'API
    double centerLat = siteCarte.centerLat * scaleFactor;
    double centerLng = siteCarte.centerLng * scaleFactor;
    double zoom = siteCarte.zoom; // Ne pas appliquer le scaleFactor au zoom

    return FlutterMap(
      mapController: _siteMapController,
      options: MapOptions(
        crs: const CrsSimple(),
        initialCenter: LatLng(centerLat, centerLng),
        initialZoom: zoom,
        maxZoom: zoom + 10,
        minZoom: zoom - 10,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onTap: _handleMapTap,
      ),
      children: [
        OverlayImageLayer(
          overlayImages: [
            OverlayImage(
              bounds: LatLngBounds(
                const LatLng(0, 0),
                LatLng(normalizedHeight, normalizedWidth),
              ),
              opacity: 1.0,
              imageProvider: NetworkImage(siteCarte.chemin),
            ),
          ],
        ),
        // Affichage des polygones des bâtiments existants et du polygone en cours de création
        PolygonLayer(
          polygons: _getBuildingPolygons(selectedSite.id) +
              (_sitePolygons.isNotEmpty ? _sitePolygons : []),
        ),
        // Affichage des marqueurs pour les points du bâtiment en cours de création
        if (_buildingMarkers.isNotEmpty)
          MarkerLayer(
            markers: _buildingMarkers,
          ),
      ],
    );
  }

  void _getImageDimensions(String imageUrl) {
    final imageProvider = NetworkImage(imageUrl);
    imageProvider.resolve(const ImageConfiguration()).addListener(
          ImageStreamListener((ImageInfo imageInfo, bool synchronousCall) {
            setState(() {
              _siteEffectiveWidth = imageInfo.image.width.toDouble();
              _siteEffectiveHeight = imageInfo.image.height.toDouble();
            });
          }, onError: (error, stackTrace) {}),
        );
  }

  void _getFloorImageDimensions(String imageUrl) {
    final imageProvider = NetworkImage(imageUrl);
    imageProvider.resolve(const ImageConfiguration()).addListener(
          ImageStreamListener((ImageInfo imageInfo, bool synchronousCall) {
            setState(() {
              _floorEffectiveWidth = imageInfo.image.width.toDouble();
              _floorEffectiveHeight = imageInfo.image.height.toDouble();
            });
          }, onError: (error, stackTrace) {}),
        );
  }

  // --------------------------------------------------------------------
  // Vue de l'étage utilisant OverlayImageLayer
  // --------------------------------------------------------------------
  Widget _buildFloorView() {
    // Si une image a été uploadée mais pas encore sauvegardée
    if (_uploadedFloorImage != null) {
      return Stack(
        children: [
          FlutterMap(
            mapController: _floorMapController,
            options: MapOptions(
              crs: const CrsSimple(),
              initialCenter: _floorCenter,
              initialZoom: _floorInitialZoom,
              maxZoom: 20,
              minZoom: -20,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: _handleMapTap,
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
              // Couche MarkerLayer pour les BAES
              if (_baesMarkers.isNotEmpty)
                MarkerLayer(
                  markers: _baesMarkers,
                ),
            ],
          ),
          _buildFloorControls(),
        ],
      );
    }

    // Recherche la carte de l'étage dans la liste statique
    Carte? floorCarte;
    if (_selectedFloorId != null && _selectedFloorId! > 0) {
      // Vérifie que l'ID n'est pas négatif (local)
      for (var carte in Carte.allCartes) {
        if (carte.etageId == _selectedFloorId) {
          floorCarte = carte;
          break;
        }
      }
    }

    // Si aucune carte n'est trouvée ou si le chemin de la carte est null ou vide, affiche un message
    if (floorCarte == null || floorCarte.chemin.isEmpty) {
      return Stack(
        children: [
          Center(
            child: Text(
              "Aucune carte disponible pour cet étage",
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          _buildFloorControls(),
        ],
      );
    }

    // Récupère les dimensions de l'image si elles ne sont pas déjà définies
    if (_floorEffectiveHeight == null || _floorEffectiveWidth == null) {
      _getFloorImageDimensions(floorCarte.chemin);

      // Utilise des valeurs par défaut en attendant que les dimensions réelles soient chargées
      _floorEffectiveHeight ??= 90.0;
      _floorEffectiveWidth ??= 180.0;
    }

    // Normalisation des dimensions pour respecter les contraintes latitude <= 90 et longitude <= 180.
    double effectiveHeight = _floorEffectiveHeight!;
    double effectiveWidth = _floorEffectiveWidth!;
    const double maxValidLat = 90.0;
    const double maxValidLng = 180.0;
    double scaleFactor = 1.0;

    // Calcul du facteur d'échelle pour la latitude
    if (effectiveHeight > maxValidLat) {
      scaleFactor = maxValidLat / effectiveHeight;
    }

    // Calcul du facteur d'échelle pour la longitude
    if (effectiveWidth > maxValidLng) {
      double lngScaleFactor = maxValidLng / effectiveWidth;
      // Utilise le facteur d'échelle le plus restrictif
      scaleFactor = min(scaleFactor, lngScaleFactor);
    }

    double normalizedHeight = effectiveHeight * scaleFactor;
    double normalizedWidth = effectiveWidth * scaleFactor;

    // Utilise les coordonnées de la carte récupérée depuis l'API
    double centerLat = floorCarte.centerLat * scaleFactor;
    double centerLng = floorCarte.centerLng * scaleFactor;
    double zoom = floorCarte.zoom; // Ne pas appliquer le scaleFactor au zoom

    return Stack(
      children: [
        FlutterMap(
          mapController: _floorMapController,
          options: MapOptions(
            crs: const CrsSimple(),
            initialCenter: LatLng(centerLat, centerLng),
            initialZoom: zoom,
            maxZoom: 20,
            minZoom: -20,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onTap: _handleMapTap,
          ),
          children: [
            OverlayImageLayer(
              overlayImages: [
                OverlayImage(
                  bounds: LatLngBounds(
                    const LatLng(0, 0),
                    LatLng(normalizedHeight, normalizedWidth),
                  ),
                  opacity: 1.0,
                  imageProvider: NetworkImage(floorCarte.chemin),
                ),
              ],
            ),
            // Couche MarkerLayer pour les BAES
            if (_baesMarkers.isNotEmpty)
              MarkerLayer(
                markers: _baesMarkers,
              ),
          ],
        ),
        _buildFloorControls(),
      ],
    );
  }

  // Construit les contrôles pour la vue étage (dropdown et bouton retour)
  Widget _buildFloorControls() {
    return Positioned(
      top: 20,
      right: 20,
      left: 20,
      child: Row(
        children: [
          // Bouton retour
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _switchToSiteMode,
              tooltip: "Retour à la vue site",
            ),
          ),
          const SizedBox(width: 10),
          // Dropdown pour sélectionner l'étage
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedFloorId,
                  hint: const Text("Sélectionner un étage"),
                  isExpanded: true,
                  items: _batimentEtages.map((etage) {
                    return DropdownMenuItem<int>(
                      value: etage.id,
                      child: Text(etage.name),
                    );
                  }).toList(),
                  onChanged: (int? etageId) {
                    if (etageId != null) {
                      setState(() {
                        _selectedFloorId = etageId;
                      });
                      _loadFloorMapData(etageId);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Bouton pour ajouter un étage
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddFloorDialog,
              tooltip: "Ajouter un étage",
            ),
          ),
        ],
      ),
    );
  }

  // Affiche une boîte de dialogue pour ajouter un nouvel étage
  void _showAddFloorDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Ajouter un étage"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: "Entrez le nom de l'étage",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  _createFloorWithName(nameController.text);
                  Navigator.of(context).pop();
                }
              },
              child: const Text("Ajouter"),
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------------------------
  // Construction de l'interface principale et des FABs multiples
  // --------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isFloorMode ? _buildFloorView() : _buildSiteView(),
      floatingActionButton: _isFloorMode
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // FAB : Sauvegarder la carte d'étage (visible si une image est uploadée ou si un étage est sélectionné)
                if (_uploadedFloorImage != null ||
                    (_selectedFloorId != null && _selectedFloorId! > 0))
                  FloatingActionButton(
                    heroTag: 'saveFloorMap',
                    onPressed: _saveFloorMap,
                    tooltip: "Sauvegarder la carte d'étage",
                    child: const Icon(Icons.save),
                  ),
                if (_uploadedFloorImage != null ||
                    (_selectedFloorId != null && _selectedFloorId! > 0))
                  const SizedBox(height: 10),
                // FAB : Modifier/Supprimer l'étage (visible seulement si un étage est sélectionné et n'est pas un étage local)
                if (_selectedFloorId != null && _selectedFloorId! > 0)
                  FloatingActionButton(
                    heroTag: 'editFloor',
                    onPressed: () {
                      // Trouve l'étage sélectionné
                      Etage? selectedFloor;
                      for (var floor in _batimentEtages) {
                        if (floor.id == _selectedFloorId) {
                          selectedFloor = floor;
                          break;
                        }
                      }

                      if (selectedFloor == null) return;

                      final TextEditingController nameController =
                          TextEditingController(text: selectedFloor.name);

                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text("Modifier l'étage"),
                            content: TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                hintText: "Entrez le nouveau nom de l'étage",
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text("Annuler"),
                              ),
                              TextButton(
                                onPressed: () {
                                  // Affiche une boîte de dialogue de confirmation pour la suppression
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text(
                                            "Confirmation de suppression"),
                                        content: Text(
                                            "Êtes-vous sûr de vouloir supprimer l'étage '${selectedFloor?.name}' ?"),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text("Annuler"),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              Navigator.of(context)
                                                  .pop(); // Ferme la boîte de dialogue de confirmation
                                              Navigator.of(context)
                                                  .pop(); // Ferme la boîte de dialogue d'édition

                                              // Affiche un indicateur de chargement
                                              showDialog(
                                                context: context,
                                                barrierDismissible: false,
                                                builder:
                                                    (BuildContext context) {
                                                  return const AlertDialog(
                                                    content: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        CircularProgressIndicator(),
                                                        SizedBox(height: 16),
                                                        Text(
                                                            "Suppression de l'étage en cours..."),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              );

                                              try {
                                                // Appelle l'API pour supprimer l'étage
                                                final success =
                                                    await BaesApi.deleteFloor(
                                                        selectedFloor!.id);

                                                // Vérifie si le widget est toujours monté après l'opération asynchrone
                                                if (!mounted) return;

                                                // Ferme le dialogue de chargement
                                                Navigator.of(context).pop();

                                                if (success) {
                                                  // L'étage a été supprimé avec succès
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            "Étage supprimé avec succès")),
                                                  );

                                                  // Supprime l'étage de la liste des étages
                                                  setState(() {
                                                    _batimentEtages.removeWhere(
                                                        (floor) =>
                                                            floor.id ==
                                                            selectedFloor?.id);

                                                    // Si l'étage supprimé était l'étage sélectionné, sélectionne le premier étage de la liste
                                                    if (_selectedFloorId ==
                                                        selectedFloor?.id) {
                                                      _selectedFloorId =
                                                          _batimentEtages
                                                                  .isNotEmpty
                                                              ? _batimentEtages
                                                                  .first.id
                                                              : null;

                                                      // Charge les données de la carte pour le nouvel étage sélectionné
                                                      if (_selectedFloorId !=
                                                              null &&
                                                          _selectedFloorId! >
                                                              0) {
                                                        _loadFloorMapData(
                                                            _selectedFloorId!);
                                                      }
                                                    }
                                                  });
                                                } else {
                                                  // Erreur lors de la suppression de l'étage
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            "Erreur lors de la suppression de l'étage")),
                                                  );
                                                }
                                              } catch (e) {
                                                // Vérifie si le widget est toujours monté après l'opération asynchrone
                                                if (!mounted) return;

                                                // Ferme le dialogue de chargement en cas d'erreur
                                                Navigator.of(context).pop();

                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content:
                                                          Text("Erreur: $e")),
                                                );
                                              }
                                            },
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.red,
                                            ),
                                            child: const Text("Supprimer"),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text("Supprimer"),
                              ),
                              TextButton(
                                onPressed: () async {
                                  if (nameController.text.isNotEmpty) {
                                    // Affiche un indicateur de chargement
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (BuildContext context) {
                                        return const AlertDialog(
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircularProgressIndicator(),
                                              SizedBox(height: 16),
                                              Text(
                                                  "Mise à jour de l'étage en cours..."),
                                            ],
                                          ),
                                        );
                                      },
                                    );

                                    try {
                                      // Appelle l'API pour mettre à jour l'étage
                                      final updatedFloor =
                                          await BaesApi.updateFloor(
                                              selectedFloor!.id,
                                              nameController.text);

                                      // Vérifie si le widget est toujours monté après l'opération asynchrone
                                      if (!mounted) return;

                                      // Ferme le dialogue de chargement
                                      Navigator.of(context).pop();

                                      if (updatedFloor != null) {
                                        // L'étage a été mis à jour avec succès
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  "Étage mis à jour avec succès")),
                                        );

                                        // Met à jour l'étage dans la liste des étages
                                        setState(() {
                                          final index = _batimentEtages
                                              .indexWhere((floor) =>
                                                  floor.id ==
                                                  selectedFloor?.id);
                                          if (index >= 0) {
                                            _batimentEtages[index] =
                                                updatedFloor;
                                          }
                                        });
                                      } else {
                                        // Erreur lors de la mise à jour de l'étage
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  "Erreur lors de la mise à jour de l'étage")),
                                        );
                                      }
                                    } catch (e) {
                                      // Vérifie si le widget est toujours monté après l'opération asynchrone
                                      if (!mounted) return;

                                      // Ferme le dialogue de chargement en cas d'erreur
                                      Navigator.of(context).pop();

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text("Erreur: $e")),
                                      );
                                    }

                                    Navigator.of(context).pop();
                                  }
                                },
                                child: const Text("Modifier"),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    tooltip: "Modifier ou supprimer l'étage",
                    child: const Icon(Icons.edit),
                  ),
                const SizedBox(
                  height: 10,
                ),
                //floating action button pour ajouter un point BAES
                FloatingActionButton(
                  heroTag: 'addBaesPoint',
                  onPressed: () {
                    print("=== FAB PLACER BAES CLIQUÉ ===");
                    print("État actuel de _isAddingBaes: $_isAddingBaes");
                    setState(() {
                      _isAddingBaes = !_isAddingBaes;
                      print("Nouvel état de _isAddingBaes: $_isAddingBaes");
                    });
                    print("Mode ajout de BAES " +
                        (_isAddingBaes ? "activé" : "désactivé"));
                  },
                  tooltip: _isAddingBaes
                      ? "Désactiver le mode ajout de BAES"
                      : "Ajouter des BAES",
                  backgroundColor: _isAddingBaes ? Colors.red : null,
                  child: Icon(
                      _isAddingBaes ? Icons.close : Icons.add_location_alt),
                ),

                if (_selectedFloorId != null && _selectedFloorId! > 0)
                  const SizedBox(height: 10),
                // FAB : Charger une carte d'étage (toujours visible en mode étage)
                FloatingActionButton(
                  heroTag: 'uploadFloorImage',
                  onPressed: _uploadFloorImage,
                  tooltip: "Charger une carte d'étage",
                  child: const Icon(Icons.upload_file),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1er FAB : Upload
                FloatingActionButton(
                  heroTag: 'uploadImage',
                  onPressed: _uploadSiteImage,
                  tooltip: "Charger une image",
                  child: const Icon(Icons.upload_file),
                ),
                const SizedBox(height: 10),
                // 2ème FAB : Sauvegarder la position et le zoom dans la BDD
                FloatingActionButton(
                  heroTag: 'saveMapState',
                  onPressed: _updateMapDataInDatabase,
                  tooltip: "Sauvegarder la position et le zoom",
                  child: const Icon(Icons.save),
                ),
                const SizedBox(height: 10),
                // 3ème FAB : Créer un bâtiment
                FloatingActionButton(
                  heroTag: 'createBuilding',
                  onPressed: () {
                    setState(() {
                      _isCreatingBuilding = !_isCreatingBuilding;
                      if (!_isCreatingBuilding) {
                        // Si on désactive le mode création, on nettoie les points
                        _buildingPoints.clear();
                        _buildingMarkers.clear();
                        _sitePolygons.clear();
                      }
                    });
                  },
                  tooltip: _isCreatingBuilding
                      ? "Annuler la création"
                      : "Créer un bâtiment",
                  backgroundColor: _isCreatingBuilding ? Colors.red : null,
                  child: Icon(_isCreatingBuilding
                      ? Icons.close
                      : Icons.add_location_alt),
                ),
              ],
            ),
    );
  }

  // Sauvegarde la carte d'étage dans la base de données
  Future<void> _saveFloorMap() async {
    if (!mounted) return;

    // Détermine si on est en mode création ou mise à jour
    bool isUpdatingExistingFloor =
        _selectedFloorId != null && _selectedFloorId! > 0;

    // Capture les valeurs actuelles de zoom et centre pour les utiliser dans l'update
    try {
      final currentCenter = _floorMapController.camera.center;
      final currentZoom = _floorMapController.camera.zoom;

      // Stocke ces valeurs pour les utiliser dans l'update
      _floorCenter = currentCenter;
      _floorInitialZoom = currentZoom;
    } catch (e) {
      // Le contrôleur de carte pourrait ne pas être prêt
      // Dans ce cas, on utilise les valeurs stockées
    }

    // Vérifie que toutes les données nécessaires sont présentes
    // Si on est en mode mise à jour, on peut continuer même sans nouvelle image
    // car on peut vouloir mettre à jour uniquement le zoom et le centre
    if (_uploadedFloorImage == null && !isUpdatingExistingFloor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucune image à sauvegarder")),
      );
      return;
    }

    if (!isUpdatingExistingFloor &&
        (_newFloorName == null || _newFloorName!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez donner un nom à l'étage")),
      );
      return;
    }

    if (_selectedBatiment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun bâtiment sélectionné")),
      );
      return;
    }

    // Vérifie que le bâtiment a un site ID, sinon utilise celui du site sélectionné
    if (_selectedBatiment!.siteId == null) {
      final siteProvider = Provider.of<SiteProvider>(context, listen: false);
      if (siteProvider.selectedSite != null) {
        // Crée une nouvelle instance de Batiment avec le siteId du site sélectionné
        _selectedBatiment = Batiment(
          id: _selectedBatiment!.id,
          name: _selectedBatiment!.name,
          polygonPoints: _selectedBatiment!.polygonPoints,
          siteId: siteProvider.selectedSite!.id,
          etages: _selectedBatiment!.etages,
        );
      }
    }

    // Utiliser une variable pour suivre si le dialog est affiché
    bool isDialogShowing = true;

    // Affiche un indicateur de chargement
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(isUpdatingExistingFloor
                  ? "Mise à jour de la carte en cours..."
                  : "Sauvegarde de la carte en cours..."),
            ],
          ),
        );
      },
    );

    try {
      Carte? carte;

      // Mode 1: Création d'un nouvel étage + upload de carte
      if (!isUpdatingExistingFloor) {
        // Crée l'étage dans la base de données
        Etage? createdFloor;

        // Trouve l'étage local correspondant
        Etage? localFloor;
        for (var floor in _localFloors) {
          if (floor.id == _selectedFloorId) {
            localFloor = floor;
            break;
          }
        }

        if (localFloor != null) {
          // Crée l'étage dans la base de données
          createdFloor =
              await BaesApi.createFloor(localFloor.name, _selectedBatiment!.id);
        } else if (_newFloorName != null) {
          // Crée l'étage avec le nom saisi
          createdFloor =
              await BaesApi.createFloor(_newFloorName!, _selectedBatiment!.id);
        }

        if (!mounted) return;

        if (createdFloor == null) {
          // Ferme le dialogue de chargement
          if (isDialogShowing && mounted) {
            Navigator.of(context).pop();
            isDialogShowing = false;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Erreur lors de la création de l'étage")),
          );
          return;
        }

        // Télécharge la carte pour l'étage créé
        carte = await BaesApi.uploadFloorMap(
          createdFloor.id,
          _uploadedFloorImage!,
          _floorCenter,
          _floorInitialZoom,
        );

        // Vérifie si le widget est toujours monté après l'opération asynchrone
        if (!mounted) return;

        if (carte != null) {
          setState(() {
            // Remplace l'étage local par l'étage créé
            final localFloorIndex =
                _localFloors.indexWhere((f) => f.id == _selectedFloorId);
            if (localFloorIndex >= 0) {
              _localFloors.removeAt(localFloorIndex);
            }

            // Remplace l'étage dans la liste des étages affichés
            final floorIndex =
                _batimentEtages.indexWhere((f) => f.id == _selectedFloorId);
            if (floorIndex >= 0) {
              _batimentEtages[floorIndex] = createdFloor!;
            } else {
              _batimentEtages.add(createdFloor!);
            }

            _selectedFloorId = createdFloor.id;
          });

          // Recharge les données de l'étage avec l'ID de l'étage créé
          _loadFloorMapData(createdFloor.id);
        }
      }
      // Mode 2: Mise à jour d'un étage existant
      else {
        // Recherche la carte associée à l'étage
        for (var c in Carte.allCartes) {
          if (c.etageId == _selectedFloorId) {
            break;
          }
        }

        // Le bâtiment a déjà été vérifié pour s'assurer qu'il a un site ID au début de la méthode

        // Utilise la nouvelle méthode qui met à jour la carte par site ID et étage ID
        carte = await APICarte.updateCarteByFloorAndSiteId(
          Provider.of<SiteProvider>(context, listen: false)._selectedSite!.id,
          _selectedFloorId!,
          _floorCenter.latitude,
          _floorCenter.longitude,
          _floorInitialZoom,
          imageBytes: _uploadedFloorImage,
        );

        // Si la mise à jour a échoué et qu'on a une image, essaie de créer une nouvelle carte
        if (carte == null && _uploadedFloorImage != null) {
          // Si aucune carte n'est trouvée mais qu'on a une image, crée une nouvelle carte pour l'étage
          carte = await BaesApi.uploadFloorMap(
            _selectedFloorId!,
            _uploadedFloorImage!,
            _floorCenter,
            _floorInitialZoom,
          );
        } else {
          // Si aucune carte n'est trouvée et qu'on n'a pas d'image, affiche une erreur
          // Ferme le dialogue de chargement
          if (isDialogShowing && mounted) {
            Navigator.of(context).pop();
            isDialogShowing = false;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    "Aucune carte trouvée pour cet étage et aucune image à sauvegarder")),
          );
          return;
        }

        // Vérifie si le widget est toujours monté après l'opération asynchrone
        if (!mounted) return;
      }

      // Ferme le dialogue de chargement
      if (isDialogShowing && mounted) {
        Navigator.of(context).pop();
        isDialogShowing = false;
      }

      if (carte != null) {
        // La carte a été téléchargée ou mise à jour avec succès
        setState(() {
          _uploadedFloorImage = null;
          _newFloorName = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isUpdatingExistingFloor
                  ? "Carte mise à jour avec succès"
                  : "Carte sauvegardée avec succès")),
        );

        // Les valeurs actuelles de zoom et centre ont déjà été capturées au début de la méthode

        // Recharge les données de l'étage
        if (_selectedFloorId != null) {
          _loadFloorMapData(_selectedFloorId!);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isUpdatingExistingFloor
                  ? "Erreur lors de la mise à jour de la carte"
                  : "Erreur lors du téléchargement de la carte")),
        );
      }
    } catch (e) {
      // Vérifie si le widget est toujours monté après l'opération asynchrone
      if (!mounted) return;

      // Ferme le dialogue de chargement en cas d'erreur
      if (isDialogShowing && mounted) {
        Navigator.of(context).pop();
        isDialogShowing = false;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e")),
      );
    }
  }
}
