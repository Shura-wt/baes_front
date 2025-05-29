part of '../main.dart';

class LeftDrawer extends StatefulWidget {
  const LeftDrawer({super.key});

  @override
  State<LeftDrawer> createState() => _LeftDrawerState();
}

class _LeftDrawerState extends State<LeftDrawer> {
  // On peut supprimer la variable _selectedSite locale si l'on utilise le provider
  // String _selectedSite = "";

  // Variables pour les filtres
  bool _showConnectionError = true;
  bool _showBatteryError = true;

  // Variables pour stocker les versions
  String _apiVersion = 'Chargement...';
  String _appVersion = 'Chargement...';

  // Variables pour le cache des versions
  bool _apiVersionLoaded = false;
  bool _appVersionLoaded = false;

  // Static reference to the current instance
  static _LeftDrawerState? _instance;

  // Add these new variables for error polling
  Timer? _errorPollingTimer;
  int _lastKnownErrorId = 0;
  HistoriqueErreur? _latestKnownError;
  bool _isUpdatingErrors = false;

  @override
  void initState() {
    super.initState();
    // Set the static reference to this instance
    _instance = this;
    if (!_apiVersionLoaded) _loadApiVersion();
    if (!_appVersionLoaded) _loadAppVersion();

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

  /// Static method to refresh the drawer UI
  static void refreshDrawer() {
    if (_instance != null && _instance!.mounted) {
      // Fetch all errors to ensure UI is updated with the latest data
      ErreurApi.getAllErrors().then((errors) {
        if (errors.isNotEmpty) {
          // Update all BAES with their errors
          for (var error in errors) {
            final baesIndex =
                Baes.allBaes.indexWhere((b) => b.id == error.baesId);
            if (baesIndex >= 0) {
              final baes = Baes.allBaes[baesIndex];

              // Get all errors for this BAES
              final baesErrors =
                  errors.where((e) => e.baesId == baes.id).toList();

              // Create a new BAES with updated errors
              final updatedBaes = Baes(
                id: baes.id,
                name: baes.name,
                position: baes.position,
                etageId: baes.etageId,
                erreurs: baesErrors,
              );

              // Replace the old BAES in the static list
              Baes.allBaes[baesIndex] = updatedBaes;
            }
          }

          // Trigger a rebuild of the drawer with the updated data
          if (_instance != null && _instance!.mounted) {
            _instance!.setState(() {
              // This empty setState will trigger a rebuild of the drawer
              // with the updated error data
            });
          }
        }
      });
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
        // Get the highest error ID
        _lastKnownErrorId =
            errors.map((e) => e.id).reduce((a, b) => a > b ? a : b);

        // Find the latest error by timestamp
        _latestKnownError =
            errors.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);
      });

      // Update BAES status with these errors
      _updateBaesStatus(errors);
    }
  }

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

          // Update the last known error ID
          setState(() {
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

  /// Update BAES status based on errors
  void _updateBaesStatus(List<HistoriqueErreur> errors) {
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

      // Refresh the UI
      if (mounted) {
        setState(() {
          // This empty setState will trigger a rebuild of the drawer
        });
      }

      // Refresh the map view if it's open
    } catch (e) {
      if (kDebugMode) {
        print("Error in _updateBaesStatus: $e");
      }
    }
  }

  // Méthode pour charger la version de l'API
  Future<void> _loadApiVersion() async {
    try {
      final version = await getApiVersion();
      if (mounted) {
        setState(() {
          _apiVersion = version;
          _apiVersionLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _apiVersion = 'Erreur';
          _apiVersionLoaded = true; // Marquer comme chargé même en cas d'erreur
        });
      }
    }
  }

  // Méthode pour charger la version de l'application
  Future<void> _loadAppVersion() async {
    try {
      final version = await getAppVersion();
      if (mounted) {
        setState(() {
          _appVersion = version;
          _appVersionLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appVersion = 'Erreur';
          _appVersionLoaded = true; // Marquer comme chargé même en cas d'erreur
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final siteProvider = Provider.of<SiteProvider>(context);

    // Utiliser la liste de sites du SiteProvider (qui est mise à jour lors de la création)
    final List<SiteAssociation> sites = siteProvider.sites;

    // Utiliser l'ID du site pour la correspondance
    // Ne pas sélectionner automatiquement le premier site si aucun site n'est sélectionné
    final int? currentSiteId = siteProvider.selectedSite?.id;

    // Déterminer si l'utilisateur peut changer de site
    final bool canChangeSite =
        authProvider.isAdmin || authProvider.isSuperAdmin;

    // Récupérer le site complet avec ses bâtiments
    final Site? completeSite = currentSiteId != null
        ? siteProvider.getCompleteSiteById(currentSiteId)
        : null;

    // Récupérer tous les bâtiments du site
    final List<Batiment> batiments = completeSite?.batiments ?? [];

    return SafeArea(
      child: Drawer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF98a069),
                Color(0xFF045f78),
                Color(0xFF1c2d41),
              ],
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 50),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Site :  ",
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    if (canChangeSite)
                      Expanded(
                        child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF045f78),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: sites.isEmpty
                                ? const Text(
                                    "Aucun site",
                                    style: TextStyle(color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : DropdownButton<int>(
                                    isExpanded: true,
                                    // Ajout de cette propriété
                                    value: currentSiteId,
                                    icon: const Icon(Icons.arrow_drop_down,
                                        color: Colors.white),
                                    dropdownColor: const Color(0xFF045f78),
                                    underline: Container(),
                                    onChanged: (int? newSiteId) {
                                      if (newSiteId != null) {
                                        final selected = sites.firstWhere(
                                          (site) => site.id == newSiteId,
                                          orElse: () => sites.first,
                                        );
                                        siteProvider.setSelectedSite(selected);
                                      }
                                    },
                                    items: sites.map((site) {
                                      return DropdownMenuItem<int>(
                                        value: site.id,
                                        child: Text(
                                          site.name,
                                          // Possibilité de tronquer le texte si besoin
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                      );
                                    }).toList(),
                                  )),
                      )
                    else
                      Text(
                        // Affiche le nom du site sélectionné ou un message si aucun site n'est disponible
                        sites.isEmpty
                            ? "Aucun site disponible"
                            : (siteProvider.selectedSite?.name ?? ""),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 20),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (canChangeSite)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Toujours afficher le bouton d'ajout si l'utilisateur est admin/superadmin
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            onPressed: _showNewSiteDialog,
                            tooltip: 'Ajouter un site',
                          ),
                          // Afficher le bouton de suppression uniquement s'il y a un site sélectionné
                          if (currentSiteId != null)
                            IconButton(
                              icon:
                                  const Icon(Icons.delete, color: Colors.white),
                              onPressed: () =>
                                  _showDeleteSiteConfirmationDialog(
                                      currentSiteId),
                              tooltip: 'Supprimer le site',
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              _buildHeader(authProvider),
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: "Bâtiments"),
                          Tab(text: "Erreurs"),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Onglet 1 : Liste des bâtiments
                            ListView.builder(
                              padding: const EdgeInsets.all(16.0),
                              itemCount: batiments.length,
                              itemBuilder: (context, index) {
                                final batiment = batiments[index];
                                return BuildingTile(
                                  batiment: batiment,
                                  showConnectionError: _showConnectionError,
                                  showBatteryError: _showBatteryError,
                                );
                              },
                            ),
                            // Onglet 2 : Liste des BAES en erreur
                            _buildErrorTab(batiments),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Affichage des versions en bas du drawer
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Version de l'application
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Version App : ",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          _appVersion,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Version de l'API
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Version API : ",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          _apiVersion,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget pour le header (filtres).
  Widget _buildHeader(AuthProvider authProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Filtres.
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Afficher erreurs de connexion",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              Checkbox(
                value: _showConnectionError,
                onChanged: (value) {
                  setState(() {
                    _showConnectionError = value ?? false;
                  });
                },
              ),
            ],
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Afficher erreurs de batterie",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              Checkbox(
                value: _showBatteryError,
                onChanged: (value) {
                  setState(() {
                    _showBatteryError = value ?? false;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Widget pour l'onglet "Erreurs".
  Widget _buildErrorTab(List<Batiment> batiments) {
    // Collecter tous les BAES en erreur
    List<Baes> errorBaes = [];

    for (var batiment in batiments) {
      for (var etage in batiment.etages) {
        // Utiliser la méthode statique Baes.getBaesForFloor au lieu d'accéder directement à Baes.allBaes
        for (var baes in Baes.getBaesForFloor(etage.id)) {
          // Vérifier si le BAES a des erreurs actives (non résolues et non ignorées)
          bool hasActiveErrors = baes.erreurs.any((e) =>
              !e.isSolved &&
              !e.isIgnored &&
              ((_showConnectionError &&
                      (e.typeErreur == 'connection' ||
                          e.typeErreur == 'erreur_connexion')) ||
                  (_showBatteryError &&
                      (e.typeErreur == 'battery' ||
                          e.typeErreur == 'erreur_batterie'))));

          // Vérifier si le BAES a des erreurs ignorées (mais pas d'erreurs actives)
          bool hasIgnoredErrors = !hasActiveErrors &&
              baes.erreurs.any((e) =>
                  e.isIgnored &&
                  ((_showConnectionError &&
                          (e.typeErreur == 'connection' ||
                              e.typeErreur == 'erreur_connexion')) ||
                      (_showBatteryError &&
                          (e.typeErreur == 'battery' ||
                              e.typeErreur == 'erreur_batterie'))));

          // Ajouter le BAES à la liste s'il a des erreurs actives ou ignorées
          if (hasActiveErrors || hasIgnoredErrors) {
            errorBaes.add(baes);
          }
        }
      }
    }

    if (errorBaes.isEmpty) {
      return const Center(
        child: Text(
          "Aucune erreur détectée (selon votre filtre)",
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: errorBaes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final baes = errorBaes[index];
        return ErrorBAESTile(baes: baes);
      },
    );
  }

  /// Affiche une boîte de dialogue pour créer un nouveau site.
  void _showNewSiteDialog() {
    final TextEditingController siteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Créer un nouveau site"),
          content: TextField(
            controller: siteController,
            decoration: const InputDecoration(labelText: "Nom du site"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () async {
                String newSiteName = siteController.text.trim();
                if (newSiteName.isNotEmpty) {
                  try {
                    final siteProvider =
                        Provider.of<SiteProvider>(context, listen: false);
                    final newSite = await siteProvider.createSite(newSiteName);
                    // On met à jour directement le provider, pas besoin d'une variable locale ici
                  } catch (e) {
                    // Erreur lors de la création du site
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
  }

  /// Affiche une boîte de dialogue de confirmation pour supprimer un site.
  void _showDeleteSiteConfirmationDialog(int siteId) {
    // Récupérer le nom du site à partir de son ID
    final siteProvider = Provider.of<SiteProvider>(context, listen: false);
    final site = siteProvider.sites.firstWhere(
      (site) => site.id == siteId,
      orElse: () =>
          SiteAssociation(id: siteId, name: "Site inconnu", roles: []),
    );

    showDialog(
      context: context,
      barrierDismissible:
          false, // Empêche la fermeture en cliquant à l'extérieur
      builder: (dialogContext) {
        // Variable pour suivre l'état de la suppression
        bool isDeleting = false;

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text("Confirmation de suppression"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    "Êtes-vous sûr de vouloir supprimer le site '${site.name}' ?"),
                const SizedBox(height: 10),
                const Text("Cette action est irréversible."),
                if (isDeleting) ...[
                  const SizedBox(height: 20),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text("Suppression en cours..."),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDeleting
                    ? null // Désactiver le bouton pendant la suppression
                    : () => Navigator.pop(dialogContext),
                child: const Text("Annuler"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: isDeleting
                    ? null // Désactiver le bouton pendant la suppression
                    : () async {
                        // Marquer comme en cours de suppression
                        setState(() {
                          isDeleting = true;
                        });

                        try {
                          // Appeler la méthode de suppression du site
                          final success = await siteProvider.deleteSite(siteId);

                          // Fermer la boîte de dialogue uniquement si la suppression a réussi
                          if (success && dialogContext.mounted) {
                            Navigator.pop(dialogContext);

                            // Afficher un message de confirmation
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    "Le site '${site.name}' a été supprimé avec succès."),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else if (dialogContext.mounted) {
                            // En cas d'échec, réactiver les boutons
                            setState(() {
                              isDeleting = false;
                            });

                            // Afficher un message d'erreur
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text("Échec de la suppression du site."),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          // En cas d'erreur, réactiver les boutons si le contexte est toujours valide
                          if (dialogContext.mounted) {
                            setState(() {
                              isDeleting = false;
                            });

                            // Afficher un message d'erreur
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    "Erreur lors de la suppression du site: $e"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: const Text("Supprimer"),
              ),
            ],
          );
        });
      },
    );
  }
}

class BuildingTile extends StatelessWidget {
  final Batiment batiment;
  final bool showConnectionError;
  final bool showBatteryError;

  const BuildingTile({
    super.key,
    required this.batiment,
    required this.showConnectionError,
    required this.showBatteryError,
  });

  @override
  Widget build(BuildContext context) {
    // Récupérer tous les BAES pour ce bâtiment en utilisant la méthode statique
    List<Baes> allBaesInBuilding = Baes.getBaesForBuilding(batiment.etages);

    final total = allBaesInBuilding.length;

    // Compter les erreurs actives selon les filtres
    int activeErrors = 0;
    int ignoredErrors = 0;
    for (var baes in allBaesInBuilding) {
      // Vérifier les erreurs actives (non résolues et non ignorées)
      bool hasActiveConnectionError = baes.erreurs.any((e) =>
          (e.typeErreur == 'connection' ||
              e.typeErreur == 'erreur_connexion') &&
          !e.isSolved &&
          !e.isIgnored);
      bool hasActiveBatteryError = baes.erreurs.any((e) =>
          (e.typeErreur == 'erreur_batterie') && !e.isSolved && !e.isIgnored);

      // Vérifier les erreurs ignorées
      bool hasIgnoredConnectionError = baes.erreurs.any((e) =>
          (e.typeErreur == 'connection' ||
              e.typeErreur == 'erreur_connexion') &&
          e.isIgnored);
      bool hasIgnoredBatteryError = baes.erreurs
          .any((e) => (e.typeErreur == 'erreur_batterie') && e.isIgnored);

      if ((showConnectionError && hasActiveConnectionError) ||
          (showBatteryError && hasActiveBatteryError)) {
        activeErrors++;
      } else if ((showConnectionError && hasIgnoredConnectionError) ||
          (showBatteryError && hasIgnoredBatteryError)) {
        ignoredErrors++;
      }
    }

    // Déterminer la couleur du chip d'erreur
    final Color errorChipColor;
    if (activeErrors > 0) {
      errorChipColor = Colors.red;
    } else if (ignoredErrors > 0) {
      errorChipColor = Colors.orange;
    } else {
      errorChipColor = Colors.green;
    }

    // Total des erreurs à afficher (actives + ignorées)
    final errors = activeErrors + ignoredErrors;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Tooltip(
                message: "Bâtiment ${batiment.name}",
                child: Text(
                  "Bâtiment ${batiment.name}",
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(maxWidth: 40),
              child: Tooltip(
                message: "BAES dans le batiment",
                child: Chip(
                  padding: EdgeInsets.zero,
                  shape:
                      CircleBorder(side: BorderSide(color: Colors.grey[300]!)),
                  label: Text("$total",
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black)),
                  backgroundColor: Colors.grey[300],
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(maxWidth: 40),
              child: Tooltip(
                message: "Erreurs dans le batiment",
                child: Chip(
                  padding: EdgeInsets.zero,
                  shape: CircleBorder(side: BorderSide(color: errorChipColor)),
                  label: Text("$errors",
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white)),
                  backgroundColor: errorChipColor,
                ),
              ),
            ),
          ],
        ),
        children: batiment.etages.map((etage) {
          return Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: FloorTile(
              etage: etage,
              showConnectionError: showConnectionError,
              showBatteryError: showBatteryError,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class FloorTile extends StatelessWidget {
  final Etage etage;
  final bool showConnectionError;
  final bool showBatteryError;

  const FloorTile({
    super.key,
    required this.etage,
    required this.showConnectionError,
    required this.showBatteryError,
  });

  @override
  Widget build(BuildContext context) {
    // Récupérer tous les BAES pour cet étage en utilisant la méthode statique
    final List<Baes> baesInFloor = Baes.getBaesForFloor(etage.id);

    final total = baesInFloor.length;

    // Compter les erreurs actives selon les filtres
    int activeErrors = 0;
    int ignoredErrors = 0;
    for (var baes in baesInFloor) {
      // Vérifier les erreurs actives (non résolues et non ignorées)
      bool hasActiveConnectionError = baes.erreurs.any((e) =>
          (e.typeErreur == 'connection' ||
              e.typeErreur == 'erreur_connexion') &&
          !e.isSolved &&
          !e.isIgnored);
      bool hasActiveBatteryError = baes.erreurs.any((e) =>
          (e.typeErreur == 'battery' || e.typeErreur == 'erreur_batterie') &&
          !e.isSolved &&
          !e.isIgnored);

      // Vérifier les erreurs ignorées
      bool hasIgnoredConnectionError = baes.erreurs.any((e) =>
          (e.typeErreur == 'connection' ||
              e.typeErreur == 'erreur_connexion') &&
          e.isIgnored);
      bool hasIgnoredBatteryError = baes.erreurs.any((e) =>
          (e.typeErreur == 'battery' || e.typeErreur == 'erreur_batterie') &&
          e.isIgnored);

      if ((showConnectionError && hasActiveConnectionError) ||
          (showBatteryError && hasActiveBatteryError)) {
        activeErrors++;
      } else if ((showConnectionError && hasIgnoredConnectionError) ||
          (showBatteryError && hasIgnoredBatteryError)) {
        ignoredErrors++;
      }
    }

    // Déterminer la couleur du chip d'erreur
    final Color errorChipColor;
    if (activeErrors > 0) {
      errorChipColor = Colors.red;
    } else if (ignoredErrors > 0) {
      errorChipColor = Colors.orange;
    } else {
      errorChipColor = Colors.green;
    }

    // Total des erreurs à afficher (actives + ignorées)
    final errors = activeErrors + ignoredErrors;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Tooltip(
                message: "Étage ${etage.name}",
                child: Text(
                  "Étage ${etage.name}",
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(maxWidth: 40),
              child: Tooltip(
                message: "BAES dans l'étage",
                child: Chip(
                  padding: EdgeInsets.zero,
                  shape:
                      CircleBorder(side: BorderSide(color: Colors.grey[300]!)),
                  label: Text("$total",
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black)),
                  backgroundColor: Colors.grey[300],
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(maxWidth: 40),
              child: Tooltip(
                message: "Erreurs dans l'étage",
                child: Chip(
                  padding: EdgeInsets.zero,
                  shape: CircleBorder(side: BorderSide(color: errorChipColor)),
                  label: Text("$errors",
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white)),
                  backgroundColor: errorChipColor,
                ),
              ),
            ),
          ],
        ),
        children: baesInFloor
            .map((baes) => Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: BAESTile(
                    baes: baes,
                    showConnectionError: showConnectionError,
                    showBatteryError: showBatteryError,
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class BAESTile extends StatelessWidget {
  final Baes baes;
  final bool showConnectionError;
  final bool showBatteryError;

  const BAESTile({
    super.key,
    required this.baes,
    required this.showConnectionError,
    required this.showBatteryError,
  });

  @override
  Widget build(BuildContext context) {
    // Vérifier les erreurs actives (non résolues et non ignorées)
    bool hasConnectionError = baes.erreurs.any((e) =>
        (e.typeErreur == 'connection' || e.typeErreur == 'erreur_connexion') &&
        !e.isSolved &&
        !e.isIgnored);
    bool hasBatteryError = baes.erreurs.any((e) =>
        e.typeErreur == 'erreur_batterie' && !e.isSolved && !e.isIgnored);

    // Vérifier si des erreurs sont ignorées (et aucune active)
    bool anyErrorIgnored = false;
    bool allErrorsSolved = true;

    if (baes.erreurs.isNotEmpty) {
      // Vérifier si toutes les erreurs sont soit résolues soit ignorées
      bool allErrorsHandled =
          baes.erreurs.every((e) => e.isSolved || e.isIgnored);

      // Si toutes les erreurs sont traitées, vérifier si certaines sont ignorées
      if (allErrorsHandled) {
        anyErrorIgnored = baes.erreurs.any((e) => e.isIgnored);
        allErrorsSolved = baes.erreurs.every((e) => e.isSolved);
      } else {
        // Si toutes les erreurs ne sont pas traitées, alors toutes ne sont pas résolues
        allErrorsSolved = false;
      }
    }

    return ListTile(
      title: Tooltip(
        message: "BAES ID: ${baes.id} - ${baes.name}",
        child: Text(
          "BAES ID: ${baes.id} - ${baes.name}",
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Colors.black),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: SizedBox(
        width: 70, // Fixed width to prevent overflow
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: "Connexion",
              child: Icon(
                Icons.wifi,
                color: hasConnectionError
                    ? Colors.red
                    : anyErrorIgnored &&
                            baes.erreurs.any((e) =>
                                (e.typeErreur == 'connection' ||
                                    e.typeErreur == 'erreur_connexion') &&
                                e.isIgnored)
                        ? Colors.orange
                        : Colors.green,
                size: 20, // Smaller icon
              ),
            ),
            const SizedBox(width: 4), // Reduced spacing
            Tooltip(
              message: "Erreur batterie",
              child: Icon(
                Icons.battery_unknown_outlined,
                color: hasBatteryError
                    ? Colors.red
                    : anyErrorIgnored &&
                            baes.erreurs.any((e) =>
                                e.typeErreur == 'erreur_batterie' &&
                                e.isIgnored)
                        ? Colors.orange
                        : Colors.green,
                size: 20, // Smaller icon
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorBAESTile extends StatelessWidget {
  final Baes baes;

  const ErrorBAESTile({super.key, required this.baes});

  @override
  Widget build(BuildContext context) {
    // Trouver l'étage et le bâtiment pour ce BAES
    final etage = Etage.allEtages.firstWhere(
      (e) => e.id == baes.etageId,
      orElse: () => Etage(id: 0, name: "Inconnu", batimentId: 0, baes: []),
    );

    final batiment = Batiment.allBatiments.firstWhere(
      (b) => b.id == etage.batimentId,
      orElse: () =>
          Batiment(id: 0, name: "Inconnu", polygonPoints: {}, etages: []),
    );

    return Card(
      color: Colors.red.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "BAES: ${baes.name} (ID: ${baes.id})",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "Bâtiment: ${batiment.name} - Étage: ${etage.name}",
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...baes.erreurs
                .map((error) => _buildErrorItem(context, error))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorItem(BuildContext context, HistoriqueErreur error) {
    // Get the AuthProvider to check user roles
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Check if the user has permission to acknowledge errors
    // Only technicians, admins, and super-admins can acknowledge errors
    final bool canAcknowledgeErrors = authProvider.isTech ||
        authProvider.isAdmin ||
        authProvider.isSuperAdmin;

    String errorType = error.typeErreur == 'connection' ||
            error.typeErreur == 'erreur_connexion'
        ? 'Erreur de connexion'
        : error.typeErreur == 'erreur_batterie'
            ? 'Erreur de batterie'
            : 'Erreur inconnue';

    String status = error.isSolved
        ? 'Résolu'
        : error.isIgnored
            ? 'Ignoré'
            : 'Non traité';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Type: $errorType"),
                Text("Date: ${error.timestamp.toString().substring(0, 16)}"),
                Text("Statut: $status"),
                if (error.acknowledgedBy != null)
                  Text("Acquitté par: ${error.acknowledgedBy}"),
              ],
            ),
          ),
          // Only show acknowledgment buttons if the user has permission
          if (!error.isSolved && canAcknowledgeErrors)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () =>
                      _acknowledgeError(context, error, true, false),
                  tooltip: 'Marquer comme résolu',
                ),
                if (!error.isIgnored)
                  IconButton(
                    icon: const Icon(Icons.block, color: Colors.orange),
                    onPressed: () =>
                        _acknowledgeError(context, error, false, true),
                    tooltip: 'Ignorer',
                  ),
                if (error.isIgnored)
                  IconButton(
                    icon: const Icon(Icons.restore, color: Colors.blue),
                    onPressed: () =>
                        _acknowledgeError(context, error, false, false),
                    tooltip: 'Ne plus ignorer',
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _acknowledgeError(BuildContext context, HistoriqueErreur error,
      bool isSolved, bool isIgnored) async {
    final success =
        await ErreurApi.acknowledgeError(error.id, isSolved, isIgnored);

    if (success) {
      // Create a new HistoriqueErreur with updated status
      final updatedError = HistoriqueErreur(
        id: error.id,
        baesId: error.baesId,
        typeErreur: error.typeErreur,
        timestamp: error.timestamp,
        isSolved: isSolved,
        isIgnored: isIgnored,
        acknowledgedBy: error.acknowledgedBy,
        acknowledgedAt: DateTime.now(),
      );

      // Find the BAES in the static list
      final baesIndex = Baes.allBaes.indexWhere((b) => b.id == error.baesId);
      if (baesIndex >= 0) {
        final baes = Baes.allBaes[baesIndex];

        // Create a new list of errors with the updated error
        final updatedErrors = baes.erreurs
            .map((e) => e.id == error.id ? updatedError : e)
            .toList();

        // Create a new BAES with the updated errors list
        final updatedBaes = Baes(
          id: baes.id,
          name: baes.name,
          position: baes.position,
          etageId: baes.etageId,
          erreurs: updatedErrors,
        );

        // Replace the old BAES in the static list
        Baes.allBaes[baesIndex] = updatedBaes;
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSolved
                ? 'Erreur marquée comme résolue'
                : isIgnored
                    ? 'Erreur ignorée'
                    : 'Erreur réactivée',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Find the nearest LeftDrawer ancestor and trigger a rebuild
      final leftDrawerState =
          context.findAncestorStateOfType<_LeftDrawerState>();
      if (leftDrawerState != null && leftDrawerState.mounted) {
        leftDrawerState.setState(() {
          // This empty setState will trigger a rebuild of the LeftDrawer
        });
      } else {
        // Fallback: try to rebuild all children if we can't find the LeftDrawer
        void rebuildAllChildren(BuildContext context) {
          void rebuild(Element el) {
            el.markNeedsBuild();
            el.visitChildren(rebuild);
          }

          (context as Element).visitChildren(rebuild);
        }

        rebuildAllChildren(context);
      }

      // Refresh the map view if it's open

      // Fetch all errors to ensure UI is updated
      ErreurApi.getAllErrors().then((errors) {
        if (errors.isNotEmpty) {
          // Update all BAES with their errors
          for (var error in errors) {
            final baesIndex =
                Baes.allBaes.indexWhere((b) => b.id == error.baesId);
            if (baesIndex >= 0) {
              final baes = Baes.allBaes[baesIndex];

              // Get all errors for this BAES
              final baesErrors =
                  errors.where((e) => e.baesId == baes.id).toList();

              // Create a new BAES with updated errors
              final updatedBaes = Baes(
                id: baes.id,
                name: baes.name,
                position: baes.position,
                etageId: baes.etageId,
                erreurs: baesErrors,
              );

              // Replace the old BAES
              Baes.allBaes[baesIndex] = updatedBaes;
            }
          }

          // Find the nearest LeftDrawer ancestor and trigger a rebuild again
          final leftDrawerState =
              context.findAncestorStateOfType<_LeftDrawerState>();
          if (leftDrawerState != null && leftDrawerState.mounted) {
            leftDrawerState.setState(() {
              // This empty setState will trigger a rebuild of the LeftDrawer
            });
          }

          // Refresh the map view again with the latest data
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Échec de l\'acquittement de l\'erreur'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
