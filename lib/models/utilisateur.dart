part of '../main.dart';

class Utilisateur {
  final int id;
  final String login;
  final List<SiteAssociation> sites;
  final List<Role> globalRolesList;

  Utilisateur({
    required this.id,
    required this.login,
    required this.sites,
    this.globalRolesList = const [],
  });

  factory Utilisateur.fromJson(Map<String, dynamic> json) {
    var sitesList = <SiteAssociation>[];
    if (json['sites'] != null) {
      sitesList = (json['sites'] as List)
          .map((siteJson) => SiteAssociation.fromJson(siteJson))
          .toList();
    }

    var globalRolesList = <Role>[];
    // Check for 'global_roles' field first
    if (json['global_roles'] != null) {
      globalRolesList = (json['global_roles'] as List)
          .map((roleJson) => Role.fromJson(roleJson))
          .toList();
    } 
    // If 'global_roles' is null, check for 'roles' field
    else if (json['roles'] != null) {
      // If 'roles' is a list of strings, convert to Role objects
      if (json['roles'] is List && json['roles'].isNotEmpty && json['roles'][0] is String) {
        globalRolesList = (json['roles'] as List)
            .map((roleName) => Role(id: 0, name: roleName as String))
            .toList();
      } 
      // If 'roles' is a list of objects, parse as Role objects
      else {
        globalRolesList = (json['roles'] as List)
            .map((roleJson) => Role.fromJson(roleJson))
            .toList();
      }
    }

    return Utilisateur(
      id: json['id'],
      login: json['login'],
      sites: sitesList,
      globalRolesList: globalRolesList,
    );
  }

  /// Agrège tous les rôles issus de chaque association de site et les rôles globaux.
  Set<String> get globalRoles {
    final rolesSet = <String>{};
    // Add site-specific roles
    for (final site in sites) {
      for (final role in site.roles) {
        rolesSet.add(role.name.toLowerCase());
      }
    }
    // Add global roles
    for (final role in globalRolesList) {
      rolesSet.add(role.name.toLowerCase());
    }
    return rolesSet;
  }
}
