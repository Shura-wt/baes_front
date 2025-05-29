part of "../../main.dart";

class UtilisateurApi {
  static String baseUrl = Config.baseUrl;

  /// Crée un nouvel utilisateur via l'API.
  /// On envoie "login", optionnellement "password",
  /// et optionnellement une liste de rôles et une liste d'IDs de sites.
  /// La réponse doit contenir id, login, et la liste des sites avec leurs rôles.
  ///
  /// Route: POST /users/
  static Future<Utilisateur> createUser({
    required String username,
    String? password,
    List<String>? roles,
    List<int>? sites,
  }) async {
    final url = Uri.parse('$baseUrl/users/');
    final Map<String, dynamic> body = {
      'login': username,
    };
    if (password != null && password.isNotEmpty) {
      body['password'] = password;
    }
    if (roles != null && roles.isNotEmpty) {
      body['roles'] = roles;
    }
    if (sites != null && sites.isNotEmpty) {
      body['sites'] = sites;
    }

    print('Envoi de la requête POST à $url');
    print('Corps de la requête: ${jsonEncode(body)}');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      print('Réponse reçue: Status ${response.statusCode}');
      print('Corps de la réponse: ${response.body}');

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return Utilisateur.fromJson(json);
      } else {
        throw Exception(
            'Erreur lors de la création de l\'utilisateur. Code HTTP: ${response.statusCode}, Réponse: ${response.body}');
      }
    } catch (e) {
      print('Exception lors de l\'envoi de la requête: $e');
      rethrow;
    }
  }

  /// Crée un nouvel utilisateur avec des relations site-rôle via l'API.
  /// On envoie "login", "password", et un objet "rolesBySite" qui mappe les IDs de site aux IDs de rôle.
  /// Exemple de rolesBySite: {"1": 2, "3": 1} où 1 et 3 sont des IDs de site, et 2 et 1 sont des IDs de rôle.
  /// La réponse doit contenir id, login, et la liste des sites avec leurs rôles.
  static Future<Utilisateur> createUserWithRelations({
    required String username,
    required String password,
    required Map<int, int> rolesBySite,
    List<String>? globalRoles,
  }) async {
    final url = Uri.parse('$baseUrl/users/create-with-relations');

    // Convertir les clés int en String pour le format JSON attendu par l'API
    final Map<String, int> rolesBySiteString =
        rolesBySite.map((key, value) => MapEntry(key.toString(), value));

    final Map<String, dynamic> body = {
      'login': username,
      'password': password,
      'rolesBySite': rolesBySiteString,
    };

    if (globalRoles != null && globalRoles.isNotEmpty) {
      body['roles'] = globalRoles;
    }

    print('Envoi de la requête POST à $url');
    print('Corps de la requête: ${jsonEncode(body)}');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      print('Réponse reçue: Status ${response.statusCode}');
      print('Corps de la réponse: ${response.body}');

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return Utilisateur.fromJson(json);
      } else {
        throw Exception(
            'Erreur lors de la création de l\'utilisateur avec relations. Code HTTP: ${response.statusCode}, Réponse: ${response.body}');
      }
    } catch (e) {
      print('Exception lors de l\'envoi de la requête: $e');
      rethrow;
    }
  }

  /// Met à jour un utilisateur existant via l'API.
  /// On envoie le nouvel "login", une liste de rôles, optionnellement "password",
  /// et optionnellement une liste d'IDs de sites.
  static Future<Utilisateur> updateUser(
    int id, {
    required String username,
    required List<String> roles,
    String? password,
    List<int>? sites,
  }) async {
    final url = Uri.parse('$baseUrl/users/$id');
    final Map<String, dynamic> body = {
      'login': username,
      'roles': roles,
    };
    if (password != null && password.isNotEmpty) {
      body['password'] = password;
    }
    if (sites != null && sites.isNotEmpty) {
      body['sites'] = sites;
    }

    // Log the API call

    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    // Log the API response

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return Utilisateur.fromJson(json);
    } else {
      throw Exception(
          'Erreur lors de la mise à jour de l\'utilisateur. Code HTTP: ${response.statusCode}');
    }
  }

  /// Met à jour un utilisateur existant avec ses relations site-rôle via l'API.
  /// On envoie optionnellement "login", "password", et un objet "rolesBySite" qui mappe les IDs de site aux IDs de rôle.
  /// On peut aussi spécifier si on veut remplacer toutes les relations existantes avec "replaceExistingRelations".
  /// Exemple de rolesBySite: {"1": 2, "3": 1} où 1 et 3 sont des IDs de site, et 2 et 1 sont des IDs de rôle.
  /// La réponse contient l'utilisateur mis à jour avec ses relations.
  static Future<Utilisateur> updateUserWithRelations({
    required int userId,
    String? username,
    String? password,
    Map<int, int>? rolesBySite,
    List<String>? globalRoles,
    bool replaceExistingRelations = false,
  }) async {
    final url = Uri.parse('$baseUrl/users/$userId/update-with-relations');

    // Préparer le corps de la requête
    final Map<String, dynamic> body = {};

    // Ajouter les champs optionnels s'ils sont fournis
    if (username != null) {
      body['login'] = username;
    }

    if (password != null && password.isNotEmpty) {
      body['password'] = password;
    }

    if (rolesBySite != null && rolesBySite.isNotEmpty) {
      // Convertir les clés int en String pour le format JSON attendu par l'API
      final Map<String, int> rolesBySiteString =
          rolesBySite.map((key, value) => MapEntry(key.toString(), value));
      body['rolesBySite'] = rolesBySiteString;
    }

    if (globalRoles != null && globalRoles.isNotEmpty) {
      body['roles'] = globalRoles;
    }

    // Ajouter le paramètre replaceExistingRelations si différent de la valeur par défaut
    if (replaceExistingRelations) {
      body['replaceExistingRelations'] = true;
    }

    print('Envoi de la requête PUT à $url');
    print('Corps de la requête: ${jsonEncode(body)}');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      print('Réponse reçue: Status ${response.statusCode}');
      print('Corps de la réponse: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Utilisateur.fromJson(json);
      } else {
        throw Exception(
            'Erreur lors de la mise à jour de l\'utilisateur avec relations. Code HTTP: ${response.statusCode}, Réponse: ${response.body}');
      }
    } catch (e) {
      print('Exception lors de l\'envoi de la requête: $e');
      rethrow;
    }
  }

  /// Supprime un utilisateur via l'API.
  static Future<void> deleteUser(int id) async {
    final url = Uri.parse('$baseUrl/users/$id');

    // Log the API call

    final response = await http.delete(url);

    // Log the API response

    if (response.statusCode != 200) {
      throw Exception(
          'Erreur lors de la suppression de l\'utilisateur. Code HTTP: ${response.statusCode}');
    }
  }

  /// Récupère la liste de tous les utilisateurs depuis l'API.
  /// Le JSON doit contenir pour chaque utilisateur : id, login, et la liste des sites avec leurs rôles.
  static Future<List<Utilisateur>> getAllUsers() async {
    final url = Uri.parse('$baseUrl/users/');

    final response = await http.get(url);

    // Log the API response

    if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == 'null') {
        return [];
      }
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map<Utilisateur>((data) => Utilisateur.fromJson(data))
            .toList();
      } else {
        throw Exception(
            "Format de données invalide : une liste était attendue.");
      }
    } else {
      throw Exception(
          'Erreur lors de la récupération des utilisateurs. Code: ${response.statusCode}');
    }
  }

  /// Associe un site à un utilisateur via l'API.
  /// Utilise l'endpoint POST /user-site-role/ pour créer une association entre un utilisateur, un site et un rôle.
  static Future<String> associateSiteToUser({
    required int userId,
    required int siteId,
  }) async {
    final url = Uri.parse('$baseUrl/user-site-role/');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'site_id': siteId,
        'role_id': 2
      }), // Ajout du role_id requis par l'API
    );

    // Log the API response

    if (response.statusCode == 201) {
      // Code 201 pour création réussie selon la doc
      final data = jsonDecode(response.body);
      return data['id'].toString(); // Retourne l'ID de l'association créée
    } else if (response.statusCode == 404) {
      throw Exception('Utilisateur ou site non trouvé.');
    } else {
      throw Exception('Erreur interne. Code HTTP: ${response.statusCode}');
    }
  }

  /// Récupère un utilisateur par son id.
  /// Récupère un utilisateur par son id (avec ses sites + rôles)
  static Future<Utilisateur> getUserById(int id) async {
    final url = Uri.parse('$baseUrl/users/$id');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return Utilisateur.fromJson(json);
    } else {
      throw Exception(
          'Erreur lors de la récupération de l\'utilisateur. Code: ${response.statusCode}');
    }
  }

  /// Ajoute un site à un utilisateur avec un rôle spécifique.
  /// Utilise l'endpoint POST /user-site-role/
  static Future<Map<String, dynamic>> addUserSiteRole({
    required int userId,
    required int siteId,
    required int roleId,
  }) async {
    final url = Uri.parse('$baseUrl/user-site-role/');
    final requestBody = {
      'user_id': userId,
      'site_id': siteId,
      'role_id': roleId,
    };

    print('Envoi de la requête POST à $url');
    print('Corps de la requête: ${jsonEncode(requestBody)}');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('Réponse reçue: Status ${response.statusCode}');
      print('Corps de la réponse: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('Utilisateur, site ou rôle non trouvé.');
      } else {
        throw Exception(
            'Erreur lors de l\'ajout du rôle au site pour l\'utilisateur. Code HTTP: ${response.statusCode}, Réponse: ${response.body}');
      }
    } catch (e) {
      print('Exception lors de l\'envoi de la requête: $e');
      rethrow;
    }
  }

  /// Ajoute un rôle global à un utilisateur (sans site spécifique).
  /// Utilise l'endpoint POST /user-site-role/user-role
  static Future<Map<String, dynamic>> addUserGlobalRole({
    required int userId,
    required int roleId,
  }) async {
    final url = Uri.parse('$baseUrl/user-site-role/user-role');
    final requestBody = {
      'user_id': userId,
      'role_id': roleId,
    };

    print('Envoi de la requête POST à $url');
    print('Corps de la requête: ${jsonEncode(requestBody)}');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('Réponse reçue: Status ${response.statusCode}');
      print('Corps de la réponse: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('Utilisateur ou rôle non trouvé.');
      } else {
        throw Exception(
            'Erreur lors de l\'ajout du rôle global à l\'utilisateur. Code HTTP: ${response.statusCode}, Réponse: ${response.body}');
      }
    } catch (e) {
      print('Exception lors de l\'envoi de la requête: $e');
      rethrow;
    }
  }

  /// Supprime une association utilisateur-site-rôle.
  /// Utilise l'endpoint DELETE /user-site-role/{user_id}/{site_id}/{role_id}
  /// Vérifie d'abord que l'utilisateur existe et que l'association existe
  static Future<void> deleteUserSiteRole({
    required int userId,
    required int siteId,
    required int roleId,
  }) async {
    print('Vérification de l\'existence de l\'utilisateur ID: $userId');

    try {
      // Vérifier que l'utilisateur existe
      final user = await getUserById(userId);
      print('Utilisateur trouvé: ${user.login} (ID: ${user.id})');

      // Vérifier que l'association existe
      final associations = await getUserSiteRoles(userId);
      print(
          'Récupération des associations pour l\'utilisateur: ${associations.length} associations trouvées');

      bool associationExists = false;
      for (final association in associations) {
        if (association['site_id'] != null) {
          // Utiliser des conversions sécurisées pour éviter les erreurs de type
          final assocSiteId = association['site_id'] is int
              ? association['site_id'] as int
              : int.tryParse(association['site_id'].toString()) ?? 0;

          if (assocSiteId == siteId) {
            // Vérifier les rôles pour ce site
            if (association['roles'] != null && association['roles'] is List) {
              final rolesList = association['roles'] as List<dynamic>;
              for (final roleInfo in rolesList) {
                if (roleInfo is Map<String, dynamic> &&
                    roleInfo['role_id'] != null) {
                  final assocRoleId = roleInfo['role_id'] is int
                      ? roleInfo['role_id'] as int
                      : int.tryParse(roleInfo['role_id'].toString()) ?? 0;

                  if (assocRoleId == roleId) {
                    associationExists = true;
                    print(
                        'Association trouvée: user_id=$userId, site_id=$siteId, role_id=$roleId');
                    break;
                  }
                }
              }
            }
          }
        }
        if (associationExists) break;
      }

      if (!associationExists) {
        print(
            'Association non trouvée pour user_id=$userId, site_id=$siteId, role_id=$roleId');
        throw Exception('Association utilisateur-site-rôle non trouvée');
      }

      // Procéder à la suppression
      final url = Uri.parse('$baseUrl/user-site-role/$userId/$siteId/$roleId');
      print('Envoi de la requête DELETE à $url');

      final response = await http.delete(url);
      print('Réponse reçue: Status ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception(
            'Erreur lors de la suppression de l\'association utilisateur-site-rôle. Code HTTP: ${response.statusCode}');
      }

      print('Association supprimée avec succès');
    } catch (e) {
      print('Erreur lors de la suppression de l\'association: $e');
      rethrow;
    }
  }

  /// Supprime un rôle global d'un utilisateur (sans site spécifique).
  /// Utilise l'endpoint DELETE /user-site-role/user-role/{user_id}/{role_id}
  /// Vérifie d'abord que l'utilisateur existe et que l'association existe
  static Future<void> deleteUserGlobalRole({
    required int userId,
    required int roleId,
  }) async {
    print('Vérification de l\'existence de l\'utilisateur ID: $userId');

    try {
      // Vérifier que l'utilisateur existe
      final user = await getUserById(userId);
      print('Utilisateur trouvé: ${user.login} (ID: ${user.id})');

      // Vérifier que l'association existe
      final associations = await getUserSiteRoles(userId);
      print(
          'Récupération des associations pour l\'utilisateur: ${associations.length} associations trouvées');

      bool associationExists = false;
      for (final association in associations) {
        // Les rôles globaux ont site_id à null
        if (association['site_id'] == null &&
            association['is_global'] == true) {
          if (association['roles'] != null && association['roles'] is List) {
            final rolesList = association['roles'] as List<dynamic>;
            for (final roleInfo in rolesList) {
              if (roleInfo is Map<String, dynamic> &&
                  roleInfo['role_id'] != null) {
                final assocRoleId = roleInfo['role_id'] is int
                    ? roleInfo['role_id'] as int
                    : int.tryParse(roleInfo['role_id'].toString()) ?? 0;

                if (assocRoleId == roleId) {
                  associationExists = true;
                  print(
                      'Association de rôle global trouvée: user_id=$userId, role_id=$roleId');
                  break;
                }
              }
            }
          }
        }
        if (associationExists) break;
      }

      if (!associationExists) {
        print(
            'Association de rôle global non trouvée pour user_id=$userId, role_id=$roleId');
        throw Exception('Association utilisateur-rôle global non trouvée');
      }

      // Procéder à la suppression
      final url =
          Uri.parse('$baseUrl/user-site-role/user-role/$userId/$roleId');
      print('Envoi de la requête DELETE à $url');

      final response = await http.delete(url);
      print('Réponse reçue: Status ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception(
            'Erreur lors de la suppression du rôle global de l\'utilisateur. Code HTTP: ${response.statusCode}');
      }

      print('Rôle global supprimé avec succès');
    } catch (e) {
      print('Erreur lors de la suppression du rôle global: $e');
      rethrow;
    }
  }

  /// Consulte les sites et rôles d'un utilisateur.
  /// Utilise l'endpoint GET /user-site-role/user/{user_id}
  /// Consulte les sites et rôles d'un utilisateur.
  /// Utilise l'endpoint GET /user-site-role/user/{user_id}
  static Future<List<Map<String, dynamic>>> getUserSiteRoles(int userId) async {
    final url = Uri.parse('$baseUrl/user-site-role/user/$userId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    } else {
      throw Exception(
          'Erreur récupération user-site-role: ${response.statusCode}');
    }
  }

  /// Récupère tous les rôles depuis l'API.
  static Future<List<Role>> getAllRoles() async {
    final url = Uri.parse('$baseUrl/roles/');

    print('Envoi de la requête GET à $url');

    try {
      final response = await http.get(url);

      print('Réponse reçue: Status ${response.statusCode}');
      print('Corps de la réponse: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('Récupération de tous les rôles réussie : $data');
        return data.map<Role>((json) => Role.fromJson(json)).toList();
      } else {
        throw Exception(
            'Erreur lors de la récupération des rôles. Code HTTP: ${response.statusCode}, Réponse: ${response.body}');
      }
    } catch (e) {
      print('Exception lors de l\'envoi de la requête: $e');
      rethrow;
    }
  }

  /// Récupère l'ID d'un rôle à partir de son nom.
  /// Cette méthode fait une requête à l'API pour récupérer tous les rôles
  /// et trouve l'ID correspondant au nom fourni.
  /// Si la récupération échoue, elle utilise un dictionnaire prédéfini.
  static Future<int?> getRoleIdByName(String roleName) async {
    try {
      final roles = await getAllRoles();
      final role = roles.firstWhere(
        (role) => role.name.toLowerCase() == roleName.toLowerCase(),
        orElse: () => Role(id: -1, name: ''),
      );
      return role.id != -1 ? role.id : null;
    } catch (e) {
      // Fallback avec les IDs de rôles prédéfinis si la récupération échoue
      print(
          'Erreur lors de la récupération des rôles, utilisation des IDs prédéfinis: $e');
      final Map<String, int> predefinedRoles = {
        'user': 1,
        'technicien': 2,
        'admin': 3,
        'super-admin': 4
      };
      return predefinedRoles[roleName.toLowerCase()];
    }
  }

  /// Modifie un rôle d'un utilisateur pour un site spécifique.
  /// Utilise l'endpoint PUT /user-site-role/{user_id}/{site_id}/{role_id}
  static Future<Map<String, dynamic>> updateUserSiteRole({
    required int userId,
    required int siteId,
    required int roleId,
    required int newRoleId,
  }) async {
    final url = Uri.parse('$baseUrl/user-site-role/$userId/$siteId/$roleId');

    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'new_role_id': newRoleId,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else if (response.statusCode == 404) {
      throw Exception('Utilisateur, site ou rôle non trouvé.');
    } else {
      throw Exception(
          'Erreur lors de la modification du rôle pour le site. Code HTTP: ${response.statusCode}');
    }
  }

  /// Modifie un rôle global d'un utilisateur.
  /// Utilise l'endpoint PUT /user-site-role/user-role/{user_id}/{role_id}
  static Future<Map<String, dynamic>> updateUserGlobalRole({
    required int userId,
    required int roleId,
    required int newRoleId,
  }) async {
    final url = Uri.parse('$baseUrl/user-site-role/user-role/$userId/$roleId');

    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'new_role_id': newRoleId,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else if (response.statusCode == 404) {
      throw Exception('Utilisateur ou rôle non trouvé.');
    } else {
      throw Exception(
          'Erreur lors de la modification du rôle global. Code HTTP: ${response.statusCode}');
    }
  }

  /// Crée ou met à jour une relation utilisateur-site-rôle.
  /// Utilise l'endpoint PUT /user-site-role/create-or-update
  static Future<Map<String, dynamic>> createOrUpdateUserSiteRole({
    required int userId,
    required int siteId,
    required int roleId,
  }) async {
    final url = Uri.parse('$baseUrl/user-site-role/create-or-update');
    final requestBody = {
      'user_id': userId,
      'site_id': siteId,
      'role_id': roleId,
    };

    print('Envoi de la requête PUT à $url');
    print('Corps de la requête: ${jsonEncode(requestBody)}');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('Réponse reçue: Status ${response.statusCode}');
      print('Corps de la réponse: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('Utilisateur, site ou rôle non trouvé.');
      } else {
        throw Exception(
            'Erreur lors de la création ou mise à jour de la relation utilisateur-site-rôle. Code HTTP: ${response.statusCode}, Réponse: ${response.body}');
      }
    } catch (e) {
      print('Exception lors de l\'envoi de la requête: $e');
      rethrow;
    }
  }

  /// Associe un utilisateur à plusieurs sites avec un rôle spécifique.
  /// Utilise l'endpoint PUT /user-site-role/<user_id>/multiple-sites
  static Future<Map<String, dynamic>> assignMultipleSitesToUser({
    required int userId,
    required List<int> siteIds,
    required int roleId,
  }) async {
    final url = Uri.parse('$baseUrl/user-site-role/$userId/multiple-sites');
    final requestBody = {
      'site_ids': siteIds,
      'role_id': roleId,
    };

    print('Envoi de la requête PUT à $url');
    print('Corps de la requête: ${jsonEncode(requestBody)}');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('Réponse reçue: Status ${response.statusCode}');
      print('Corps de la réponse: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('Utilisateur ou rôle non trouvé.');
      } else {
        throw Exception(
            'Erreur lors de l\'association de sites à l\'utilisateur. Code HTTP: ${response.statusCode}, Réponse: ${response.body}');
      }
    } catch (e) {
      print('Exception lors de l\'envoi de la requête: $e');
      rethrow;
    }
  }

  /// Associe un utilisateur à un site avec plusieurs rôles.
  /// Utilise l'endpoint PUT /user-site-role/create-or-update pour chaque rôle
  /// car l'endpoint /user-site-role/multiple-roles n'est pas disponible.
  static Future<Map<String, dynamic>> assignMultipleRolesToUserSite({
    required int userId,
    required int siteId,
    required List<int> roleIds,
  }) async {
    print(
        'Assignation de plusieurs rôles ($roleIds) au site $siteId pour l\'utilisateur $userId');

    // Résultats de l'opération
    final results = <String, dynamic>{
      'message': 'Rôles assignés avec succès',
      'results': <Map<String, dynamic>>[],
    };

    // Pour chaque rôle, créer ou mettre à jour la relation utilisateur-site-rôle
    for (final roleId in roleIds) {
      try {
        final result = await createOrUpdateUserSiteRole(
          userId: userId,
          siteId: siteId,
          roleId: roleId,
        );

        // Ajouter le résultat à la liste des résultats
        results['results'].add({
          'role_id': roleId,
          'status': 'success',
          'message': 'Rôle assigné avec succès',
          'details': result,
        });

        print(
            'Rôle $roleId assigné avec succès au site $siteId pour l\'utilisateur $userId');
      } catch (e) {
        // En cas d'erreur, ajouter l'erreur à la liste des résultats
        results['results'].add({
          'role_id': roleId,
          'status': 'error',
          'message': 'Erreur lors de l\'assignation du rôle: $e',
        });

        print(
            'Erreur lors de l\'assignation du rôle $roleId au site $siteId pour l\'utilisateur $userId: $e');
      }
    }

    // Si aucun rôle n'a été assigné avec succès, lancer une exception
    final successCount =
        results['results'].where((r) => r['status'] == 'success').length;
    if (successCount == 0 && roleIds.isNotEmpty) {
      throw Exception(
          'Aucun rôle n\'a pu être assigné au site $siteId pour l\'utilisateur $userId');
    }

    return results;
  }

  /// Récupère tous les sites et rôles associés à un utilisateur.
  /// Utilise l'endpoint GET /user-site-role/user/<user_id>
  static Future<List<Map<String, dynamic>>> getUserSitesRoles(
      int userId) async {
    final url = Uri.parse('$baseUrl/user-site-role/user/$userId');

    print('Envoi de la requête GET à $url');

    try {
      final response = await http.get(url);

      print('Réponse reçue: Status ${response.statusCode}');
      print('Corps de la réponse: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print(
            'Récupération des sites et rôles de l\'utilisateur réussie: $data');
        return data.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 404) {
        throw Exception('Utilisateur non trouvé.');
      } else {
        throw Exception(
            'Erreur lors de la récupération des sites et rôles de l\'utilisateur. Code HTTP: ${response.statusCode}, Réponse: ${response.body}');
      }
    } catch (e) {
      print('Exception lors de l\'envoi de la requête: $e');
      rethrow;
    }
  }
}
