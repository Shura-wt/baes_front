part of '../main.dart';

class UtilisateurDialog extends StatefulWidget {
  final String title;
  final String confirmButtonText;
  final Utilisateur? initialUser;

  const UtilisateurDialog({
    super.key,
    required this.title,
    required this.confirmButtonText,
    this.initialUser,
  });

  @override
  State<UtilisateurDialog> createState() => _UtilisateurDialogState();
}

class _UtilisateurDialogState extends State<UtilisateurDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // Tous les rôles disponibles
  List<Role> _availableRoles = [];
  bool _isLoadingRoles = true;

  // Map pour stocker les relations site-rôle
  // Clé: siteId, Valeur: Liste des roleIds
  Map<int, List<int>> _siteRolesMap = {};

  // Sites sélectionnés pour l'attribution de rôles
  Set<int> _selectedSites = {};

  /// Charge tous les sites depuis l'API
  Future<void> _loadAllSites() async {
    try {
      print('UtilisateurDialog: Début du chargement des sites');
      final siteProvider = Provider.of<SiteProvider>(context, listen: false);
      await siteProvider.loadAllSites();
      print(
          'UtilisateurDialog: Sites chargés, nombre de sites: ${siteProvider.completeSites.length}');

      // Forcer la mise à jour de l'interface utilisateur
      if (mounted) {
        setState(() {
          // Mise à jour de l'état pour forcer le rebuild
          print('UtilisateurDialog: Mise à jour de l\'interface utilisateur');
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des sites: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    // Si on modifie un utilisateur existant, on pré-remplit les champs
    if (widget.initialUser != null) {
      _usernameController.text = widget.initialUser!.login;

      // Initialiser la map des rôles par site
      for (var siteAssoc in widget.initialUser!.sites) {
        _siteRolesMap[siteAssoc.id] =
            siteAssoc.roles.map((role) => role.id).toList();
      }

      // Si l'utilisateur a des sites, les ajouter aux sites sélectionnés
      if (widget.initialUser!.sites.isNotEmpty) {
        _selectedSites =
            widget.initialUser!.sites.map((site) => site.id).toSet();
      }
    }

    // Charger les rôles disponibles depuis l'API
    _loadAvailableRoles();

    // S'assurer que tous les sites sont chargés
    _loadAllSites();
  }

  /// Charge la liste des rôles disponibles depuis l'API
  Future<void> _loadAvailableRoles() async {
    try {
      final roles = await UtilisateurApi.getAllRoles();
      setState(() {
        _availableRoles = roles;
        _isLoadingRoles = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des rôles: $e');
      // Fallback avec les rôles prédéfinis si la récupération échoue
      setState(() {
        _availableRoles = [
          Role(id: 1, name: 'user'),
          Role(id: 2, name: 'technicien'),
          Role(id: 3, name: 'admin'),
          Role(id: 4, name: 'super-admin'),
        ];
        _isLoadingRoles = false;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Définit ou supprime un rôle pour un site spécifique
  /// Si selected est true, remplace tous les rôles existants par le nouveau rôle
  /// Si selected est false, supprime le rôle
  void _toggleRoleForSite(int siteId, int roleId, bool selected) {
    setState(() {
      if (selected) {
        // Remplacer tous les rôles existants par le nouveau rôle
        _siteRolesMap[siteId] = [roleId];
      } else {
        // Si on désélectionne le rôle, on le supprime
        if (_siteRolesMap.containsKey(siteId)) {
          _siteRolesMap[siteId]!.remove(roleId);
        }
      }
    });
  }

  /// Vérifie si un site a un rôle spécifique
  bool _siteHasRole(int siteId, int roleId) {
    return _siteRolesMap.containsKey(siteId) &&
        _siteRolesMap[siteId]!.contains(roleId);
  }

  /// Ajoute ou supprime un site de la liste des sites sélectionnés
  void _toggleSiteSelection(int siteId, bool selected) {
    setState(() {
      if (selected) {
        _selectedSites.add(siteId);
      } else {
        _selectedSites.remove(siteId);
        // Si on retire un site, on supprime aussi ses rôles
        _siteRolesMap.remove(siteId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final siteProvider = Provider.of<SiteProvider>(context);
    final availableSites = siteProvider.completeSites;

    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Champs pour le nom d'utilisateur et mot de passe
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Nom d\'utilisateur',
                  hintText: 'Entrez le nom d\'utilisateur',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un nom d\'utilisateur';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  hintText: widget.initialUser == null
                      ? 'Entrez le mot de passe'
                      : 'Laissez vide pour ne pas modifier',
                ),
                obscureText: true,
                validator: (value) {
                  if (widget.initialUser == null &&
                      (value == null || value.isEmpty)) {
                    return 'Veuillez entrer un mot de passe';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Section pour la gestion des rôles par site
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Sélectionnez les sites et assignez des rôles:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),

                      // Liste des sites disponibles
                      if (availableSites.isEmpty)
                        const Text('Aucun site disponible')
                      else
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: availableSites.map((site) {
                            return FilterChip(
                              label: Text(site.name),
                              selected: _selectedSites.contains(site.id),
                              onSelected: (selected) {
                                _toggleSiteSelection(site.id, selected);
                              },
                            );
                          }).toList(),
                        ),

                      const SizedBox(height: 16),

                      // Section pour assigner des rôles à chaque site sélectionné
                      if (_selectedSites.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Assignation des rôles par site:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),

                            // Carte pour chaque site sélectionné
                            ...availableSites
                                .where(
                                    (site) => _selectedSites.contains(site.id))
                                .map((site) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16.0),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // En-tête de la carte avec le nom du site et bouton de suppression
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            site.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed: () {
                                              _toggleSiteSelection(
                                                  site.id, false);
                                            },
                                            tooltip: 'Retirer ce site',
                                          ),
                                        ],
                                      ),

                                      const Divider(),

                                      // Sélection des rôles pour ce site
                                      const Text(
                                        'Sélectionnez un rôle pour ce site:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      // Affichage des rôles disponibles
                                      if (_isLoadingRoles)
                                        const Center(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 8.0),
                                            child: CircularProgressIndicator(),
                                          ),
                                        )
                                      else
                                        Wrap(
                                          spacing: 8.0,
                                          runSpacing: 8.0,
                                          children: _availableRoles.map((role) {
                                            return FilterChip(
                                              label: Text(role.name),
                                              selected: _siteHasRole(
                                                  site.id, role.id),
                                              onSelected: (selected) {
                                                // On bascule simplement l’état : plusieurs rôles possibles
                                                _toggleRoleForSite(
                                                    site.id, role.id, selected);
                                              },
                                              selectedColor:
                                                  Colors.blue.shade100,
                                              checkmarkColor:
                                                  Colors.blue.shade700,
                                              showCheckmark: true,
                                            );
                                          }).toList(),
                                        ),

                                      // Affichage du rôle sélectionné
                                      if (_siteRolesMap.containsKey(site.id) &&
                                          _siteRolesMap[site.id]!.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8.0),
                                          child: Container(
                                            padding: const EdgeInsets.all(8.0),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4.0),
                                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.check_circle, color: Colors.blue, size: 16),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Rôle assigné: ${_availableRoles.firstWhere(
                                                    (r) => r.id == _siteRolesMap[site.id]!.first,
                                                    orElse: () => Role(id: 0, name: 'Inconnu')
                                                  ).name}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              // Vérifier qu'au moins un site a un rôle assigné
              if (_siteRolesMap.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Veuillez attribuer au moins un rôle à un site'),
                  ),
                );
                return;
              }

              // Préparer les données à retourner
              final Map<String, dynamic> result = {
                'username': _usernameController.text,
                'password': _passwordController.text.isNotEmpty
                    ? _passwordController.text
                    : null,
                'globalRoles': <String>[], // Liste vide pour la compatibilité
                'siteRoles': _siteRolesMap,
              };

              Navigator.pop(context, result);
            }
          },
          child: Text(widget.confirmButtonText),
        ),
      ],
    );
  }
}
