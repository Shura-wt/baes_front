part of '../../main.dart';

class APICarte {
  static String baseUrl = Config.baseUrl;

  static Future<Carte?> getCarte(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/cartes/carte/$id'));

    if (response.statusCode == 200) {
      return Carte.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load carte');
    }
  }

  static Future<List<Carte>> getAllCartes() async {
    final response = await http.get(Uri.parse('$baseUrl/cartes'));

    if (response.statusCode == 200) {
      List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => Carte.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load cartes');
    }
  }

  /// Télécharge une image de carte pour un site
  /// Retourne la carte créée si le téléchargement réussit, null sinon
  static Future<Carte?> uploadSiteImage(
      int siteId, Uint8List imageBytes, LatLng center, double zoom) async {
    try {
      // Crée un objet FormData pour l'envoi multipart
      var request = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/cartes/upload-carte'));

      // Ajoute l'image au formulaire
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'site_map.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));

      // Ajoute les paramètres de la carte
      request.fields['center_lat'] = center.latitude.toString();
      request.fields['center_lng'] = center.longitude.toString();
      request.fields['zoom'] = zoom.toString();
      request.fields['site_id'] = siteId.toString();

      // Envoie la requête
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Crée un objet Carte à partir de la réponse
        final jsonData = jsonDecode(response.body);
        if (jsonData.containsKey('carte')) {
          return Carte.fromJson(jsonData['carte']);
        } else {
          return Carte.fromJson(jsonData);
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Récupère la carte d'un site par son ID
  /// Retourne la carte si elle existe, null sinon
  static Future<Carte?> getCarteBySiteId(int siteId) async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/sites/carte/get_by_site/$siteId'));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        // Si la réponse est vide, retourne null
        if (jsonData == null || jsonData.isEmpty) {
          return null;
        }

        // Crée un objet Carte à partir des données JSON
        final carte = Carte.fromJson(jsonData);

        // Vérifie si cette carte existe déjà dans la liste statique
        final existingCarteIndex =
            Carte.allCartes.indexWhere((c) => c.id == carte.id);
        if (existingCarteIndex >= 0) {
          // Compare les données pour voir si une mise à jour est nécessaire
          final existingCarte = Carte.allCartes[existingCarteIndex];
          if (existingCarte.chemin != carte.chemin ||
              existingCarte.centerLat != carte.centerLat ||
              existingCarte.centerLng != carte.centerLng ||
              existingCarte.zoom != carte.zoom) {
            // La carte a été mise à jour dans la liste statique par le constructeur fromJson
          } else {
            // Carte déjà à jour
          }
        } else {
          // Nouvelle carte ajoutée
        }

        return carte;
      } else if (response.statusCode == 404) {
        // Si la carte n'existe pas, retourne null
        return null;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Met à jour les paramètres d'une carte (centre et zoom)
  /// Retourne la carte mise à jour si la mise à jour réussit, null sinon
  static Future<Carte?> updateCarte(
      int carteId, double centerLat, double centerLng, double zoom) async {
    try {
      // Crée un objet FormData pour l'envoi des paramètres
      var request = http.MultipartRequest(
          'PUT', Uri.parse('$baseUrl/cartes/carte/$carteId'));

      // Ajoute les paramètres de la carte
      request.fields['center_lat'] = centerLat.toString();
      request.fields['center_lng'] = centerLng.toString();
      request.fields['zoom'] = zoom.toString();

      // Envoie la requête
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Log the API response

      if (response.statusCode == 200) {
        // Crée un objet Carte à partir de la réponse
        final jsonData = jsonDecode(response.body);

        // Vérifie si la réponse contient la carte mise à jour
        if (jsonData.containsKey('carte')) {
          return Carte.fromJson(jsonData['carte']);
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Met à jour les paramètres d'une carte par l'ID du site (centre et zoom)
  /// Retourne la carte mise à jour si la mise à jour réussit, null sinon
  static Future<Carte?> updateCarteBySiteId(
      int siteId, double centerLat, double centerLng, double zoom) async {
    try {
      // Log the API call

      // Crée un objet FormData pour l'envoi des paramètres
      var request = http.MultipartRequest(
          'PUT', Uri.parse('$baseUrl/sites/carte/update_by_site/$siteId'));

      // Ajoute les paramètres de la carte
      request.fields['center_lat'] = centerLat.toString();
      request.fields['center_lng'] = centerLng.toString();
      request.fields['zoom'] = zoom.toString();

      // Envoie la requête
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Log the API response

      if (response.statusCode == 200) {
        // Crée un objet Carte à partir de la réponse
        final jsonData = jsonDecode(response.body);

        // Vérifie si la réponse contient la carte mise à jour
        if (jsonData.containsKey('carte')) {
          return Carte.fromJson(jsonData['carte']);
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Met à jour une carte existante avec une nouvelle image
  /// Retourne la carte mise à jour si la mise à jour réussit, null sinon
  static Future<Carte?> updateCarteWithImage(
      int carteId, Uint8List imageBytes, LatLng center, double zoom,
      {int? etageId, int? siteId}) async {
    try {
      // Log the API call

      // Crée un objet FormData pour l'envoi multipart
      var request = http.MultipartRequest(
          'PUT', Uri.parse('$baseUrl/cartes/carte/$carteId'));

      // Ajoute l'image au formulaire
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'floor_map.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));

      // Ajoute les paramètres de la carte
      request.fields['center_lat'] = center.latitude.toString();
      request.fields['center_lng'] = center.longitude.toString();
      request.fields['zoom'] = zoom.toString();

      // Ajoute l'ID de l'étage ou du site si fourni
      if (etageId != null) {
        request.fields['etage_id'] = etageId.toString();
      }
      if (siteId != null) {
        request.fields['site_id'] = siteId.toString();
      }

      // Envoie la requête
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Log the API response

      if (response.statusCode == 200) {
        // Crée un objet Carte à partir de la réponse
        final jsonData = jsonDecode(response.body);

        // Vérifie si la réponse contient la carte mise à jour
        if (jsonData.containsKey('carte')) {
          return Carte.fromJson(jsonData['carte']);
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Récupère la carte d'un étage par son ID
  /// Retourne la carte si elle existe, null sinon
  static Future<Carte?> getFloorMapByFloorId(int floorId) async {
    try {
      // Log the API call

      // Envoie la requête
      final response = await http.get(
        Uri.parse('$baseUrl/sites/carte/get_by_floor/$floorId'),
        headers: {'Content-Type': 'application/json'},
      );

      // Log the API response

      if (response.statusCode == 200) {
        // Crée un objet Carte à partir de la réponse
        final jsonData = jsonDecode(response.body);
        return Carte.fromJson(jsonData);
      } else {
        // Error getting floor map
        return null;
      }
    } catch (e) {
      // Exception handling
      return null;
    }
  }

  /// Met à jour une carte existante associée à un étage d'un site spécifique
  /// Retourne la carte mise à jour si la mise à jour réussit, null sinon
  static Future<Carte?> updateCarteByFloorAndSiteId(
      int siteId, int etageId, double centerLat, double centerLng, double zoom,
      {Uint8List? imageBytes}) async {
    try {
      // Log the API call start

      // D'abord, récupérer la carte associée à l'étage
      Carte? existingCarte = await getFloorMapByFloorId(etageId);

      // Si aucune carte n'existe pour cet étage, retourne null
      if (existingCarte == null) {
        return null;
      }

      // Crée un objet FormData pour l'envoi multipart
      var request = http.MultipartRequest(
          'PUT', Uri.parse('$baseUrl/cartes/carte/${existingCarte.id}'));

      // Ajoute l'image au formulaire si fournie
      if (imageBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'floor_map.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      // Ajoute les paramètres de la carte
      request.fields['center_lat'] = centerLat.toString();
      request.fields['center_lng'] = centerLng.toString();
      request.fields['zoom'] = zoom.toString();
      request.fields['etage_id'] = etageId.toString();
      request.fields['site_id'] = siteId.toString();

      // Envoie la requête
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Log the API response

      if (response.statusCode == 200) {
        // Crée un objet Carte à partir de la réponse
        final jsonData = jsonDecode(response.body);

        // Vérifie si la réponse contient la carte mise à jour
        if (jsonData.containsKey('carte')) {
          return Carte.fromJson(jsonData['carte']);
        } else {
          return Carte.fromJson(jsonData);
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  //get carte by id floor  withGET /get_by_floor/<int:floor_id>
  // ```
  //
  // Cette route est définie dans le fichier `site_carte_routes.py` et fonctionne comme suit:
  //
  // 1. Elle accepte une requête HTTP GET
  // 2. Elle prend l'ID de l'étage comme paramètre dans l'URL
  // 3. Elle vérifie d'abord si l'étage existe
  // 4. Puis elle recherche la carte associée à cet étage
  // 5. Si trouvée, elle renvoie les détails de la carte au format JSON:
  //    - id
  //    - chemin (URL d'accès à l'image)
  //    - center_lat (latitude du centre)
  //    - center_lng (longitude du centre)
  //    - zoom
  //    - etage_id (ID de l'étage)
  //    - site_id (ID du site, peut être null)

  static Future<Carte?> getCarteByFloor(int floorId) async {
    final uri = Uri.parse('$baseUrl/get_by_floor/$floorId');
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return Carte.fromJson(json);
      } else {
        // Vous pouvez logger response.body pour diagnostiquer
        return null;
      }
    } catch (e) {
      // Gérer l'erreur de réseau
      return null;
    }
  }
}
