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

  List<String> _selectedRoles = [];
  List<String> _selectedSites = [];

  final List<String> _availableRoles = [
    'user',
    'admin',
    'super-admin',
    'technicien'
  ];

  @override
  void initState() {
    super.initState();

    // Si on modifie un utilisateur existant, on pré-remplit les champs
    if (widget.initialUser != null) {
      _usernameController.text = widget.initialUser!.login;
      _selectedRoles = widget.initialUser!.globalRoles.toList();
      _selectedSites =
          widget.initialUser!.sites.map((site) => site.name).toList();
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final siteProvider = Provider.of<SiteProvider>(context);

    // Liste des sites disponibles
    final availableSites =
        siteProvider.completeSites.map((site) => site.name).toList();

    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Champ pour le nom d'utilisateur
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

              // Champ pour le mot de passe (optionnel lors de la modification)
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

              // Sélection des rôles
              const Text('Rôles:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8.0,
                children: _availableRoles.map((role) {
                  return FilterChip(
                    label: Text(role),
                    selected: _selectedRoles.contains(role),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedRoles.add(role);
                        } else {
                          _selectedRoles.remove(role);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Sélection des sites
              const Text('Sites:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (availableSites.isEmpty)
                const Text('Aucun site disponible')
              else
                Wrap(
                  spacing: 8.0,
                  children: availableSites.map((site) {
                    return FilterChip(
                      label: Text(site),
                      selected: _selectedSites.contains(site),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSites.add(site);
                          } else {
                            _selectedSites.remove(site);
                          }
                        });
                      },
                    );
                  }).toList(),
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
              if (_selectedRoles.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Veuillez sélectionner au moins un rôle')),
                );
                return;
              }

              Navigator.pop(context, {
                'username': _usernameController.text,
                'password': _passwordController.text.isNotEmpty
                    ? _passwordController.text
                    : null,
                'roles': _selectedRoles,
                'sites': _selectedSites,
              });
            }
          },
          child: Text(widget.confirmButtonText),
        ),
      ],
    );
  }
}
