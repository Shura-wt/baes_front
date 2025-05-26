part of "../../main.dart";

class ErreurApi {
  static String baseUrl = Config.baseUrl;

  /// Récupère la dernière erreur
  static Future<HistoriqueErreur?> getLatestError() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/erreurs/latest'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return HistoriqueErreur.fromJson(jsonData);
      } else {
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors de la récupération de la dernière erreur: $e");
      }
      return null;
    }
  }

  /// Récupère toutes les erreurs
  static Future<List<HistoriqueErreur>> getAllErrors() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/erreurs/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        return jsonData.map((json) => HistoriqueErreur.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors de la récupération des erreurs: $e");
      }
      return [];
    }
  }

  /// Récupère les erreurs après un ID spécifique
  static Future<List<HistoriqueErreur>> getErrorsAfter(int errorId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/erreurs/after/$errorId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        return jsonData.map((json) => HistoriqueErreur.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors de la récupération des nouvelles erreurs: $e");
      }
      return [];
    }
  }

  /// Récupère les erreurs pour un BAES spécifique
  static Future<List<HistoriqueErreur>> getErrorsForBaes(int baesId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/erreurs/baes/$baesId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        return jsonData.map((json) => HistoriqueErreur.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors de la récupération des erreurs du BAES: $e");
      }
      return [];
    }
  }

  /// Acquitte une erreur (marque comme résolu/ignoré)
  static Future<bool> acknowledgeError(int errorId, bool isSolved, bool isIgnored) async {
    try {
      final Map<String, dynamic> data = {
        'is_solved': isSolved,
        'is_ignored': isIgnored,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/erreurs/$errorId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors de l'acquittement de l'erreur: $e");
      }
      return false;
    }
  }
}
