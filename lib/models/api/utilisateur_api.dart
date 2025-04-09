part of "../../main.dart";

class UtilisateurApi {
  static const String baseUrl = 'http://localhost:5000';

  /// Crée un nouvel utilisateur via l'API.
  /// On envoie "login", une liste de rôles (par exemple, ['user']) et optionnellement "password".
  /// La réponse doit contenir id, login, et la liste des sites avec leurs rôles.
  static Future<Utilisateur> createUser({
    required String username,
    required List<String> roles,
    String? password,
  }) async {
    final url = Uri.parse('$baseUrl/users');
    final Map<String, dynamic> body = {
      'login': username,
      'roles': roles,
    };
    if (password != null && password.isNotEmpty) {
      body['password'] = password;
    }
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return Utilisateur.fromJson(json);
    } else {
      throw Exception(
          'Erreur lors de la création de l\'utilisateur. Code HTTP: ${response.statusCode}');
    }
  }

  /// Met à jour un utilisateur existant via l'API.
  /// On envoie le nouvel "login", une liste de rôles et optionnellement "password".
  static Future<Utilisateur> updateUser(
    int id, {
    required String username,
    required List<String> roles,
    String? password,
  }) async {
    final url = Uri.parse('$baseUrl/users/$id');
    final Map<String, dynamic> body = {
      'login': username,
      'roles': roles,
    };
    if (password != null && password.isNotEmpty) {
      body['password'] = password;
    }
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return Utilisateur.fromJson(json);
    } else {
      throw Exception(
          'Erreur lors de la mise à jour de l\'utilisateur. Code HTTP: ${response.statusCode}');
    }
  }

  /// Supprime un utilisateur via l'API.
  static Future<void> deleteUser(int id) async {
    final url = Uri.parse('$baseUrl/users/$id');
    final response = await http.delete(url);
    if (response.statusCode != 200) {
      throw Exception(
          'Erreur lors de la suppression de l\'utilisateur. Code HTTP: ${response.statusCode}');
    }
  }

  /// Récupère la liste de tous les utilisateurs depuis l'API.
  /// Le JSON doit contenir pour chaque utilisateur : id, login, et la liste des sites avec leurs rôles.
  static Future<List<Utilisateur>> getAllUsers() async {
    final url = Uri.parse('$baseUrl/users');
    final response = await http.get(url);

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
  static Future<String> associateSiteToUser({
    required int userId,
    required int siteId,
  }) async {
    final url = Uri.parse('$baseUrl/users/sites/$userId/sites');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'site_id': siteId}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['message'] as String;
    } else if (response.statusCode == 404) {
      throw Exception('Utilisateur ou site non trouvé.');
    } else {
      throw Exception('Erreur interne. Code HTTP: ${response.statusCode}');
    }
  }

  /// Récupère un utilisateur par son id.
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
}
