part of "../main.dart";

class SiteAssociation {
  final int id;
  final String name;
  final List<Role> roles;

  SiteAssociation({
    required this.id,
    required this.name,
    required this.roles,
  });

  factory SiteAssociation.fromJson(Map<String, dynamic> json) {
    var rolesList = <Role>[];
    if (json['roles'] != null) {
      rolesList = (json['roles'] as List).map((e) => Role.fromJson(e)).toList();
    }
    return SiteAssociation(
      id: json['id'],
      name: json['name'],
      roles: rolesList,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'roles': roles.map((e) => e.toJson()).toList(),
      };
}
