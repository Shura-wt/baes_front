part of '../main.dart';

class Utilisateur {
  final int id;
  final String login;
  final List<SiteAssociation> sites;

  Utilisateur({
    required this.id,
    required this.login,
    required this.sites,
  });

  factory Utilisateur.fromJson(Map<String, dynamic> json) {
    var sitesList = <SiteAssociation>[];
    if (json['sites'] != null) {
      sitesList = (json['sites'] as List)
          .map((siteJson) => SiteAssociation.fromJson(siteJson))
          .toList();
    }
    return Utilisateur(
      id: json['id'],
      login: json['login'],
      sites: sitesList,
    );
  }

  /// Agrège tous les rôles issus de chaque association de site.
  Set<String> get globalRoles {
    final rolesSet = <String>{};
    for (final site in sites) {
      for (final role in site.roles) {
        rolesSet.add(role.name.toLowerCase());
      }
    }
    return rolesSet;
  }
}
