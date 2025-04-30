part of '../main.dart';

class AuthProvider with ChangeNotifier {
  static String baseUrl = Config.baseUrl;

  Utilisateur? _currentUser;
  int? _userId;
  bool _isAuthenticated = false;
  bool _isLoading = true;

  Utilisateur? get currentUser => _currentUser;

  int? get userId => _userId;

  bool get isAuthenticated => _isAuthenticated;

  bool get isLoading => _isLoading;

  bool get isAdmin => _currentUser?.globalRoles.contains('admin') == true;

  bool get isSuperAdmin =>
      _currentUser?.globalRoles.contains('super-admin') == true;

  bool get isUser => _currentUser?.globalRoles.contains('user') == true;

  bool get isTech => _currentUser?.globalRoles.contains('technicien') == true;

  AuthProvider() {
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool storedAuth = prefs.getBool('isAuthenticated') ?? false;
    if (storedAuth) {
      int? storedUserId = prefs.getInt('user_id');
      if (storedUserId != null) {
        try {
          await _fetchUserRoles(storedUserId);
          _userId = storedUserId;
          _isAuthenticated = true;
        } catch (e) {
          _isAuthenticated = false;
        }
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Récupère les rôles et associations de sites de l'utilisateur via l'API
  /// en utilisant son id.
  Future<void> _fetchUserRoles(int userId) async {
    // Appel pour récupérer les rôles (si nécessaire)
    final rolesUrl = Uri.parse('$baseUrl/role/users/$userId/roles');

    final rolesResponse = await http.get(rolesUrl);

    // Log the API response

    if (rolesResponse.statusCode == 200) {
      List<dynamic> rolesData = jsonDecode(rolesResponse.body);
      // Extraction des noms de rôles (peut être utile pour d'autres traitements)
      rolesData.map<String>((roleData) => roleData['name'].toString()).toList();

      // Appel pour récupérer les associations de sites (avec rôles) de l'utilisateur
      final sitesUrl = Uri.parse('$baseUrl/users/sites/$userId/sites');

      final sitesResponse = await http.get(sitesUrl);

      // Log the API response

      List<SiteAssociation> sitesList = [];
      if (sitesResponse.statusCode == 200) {
        if (sitesResponse.body.isNotEmpty && sitesResponse.body != 'null') {
          final dynamic sitesDecoded = jsonDecode(sitesResponse.body);
          if (sitesDecoded is List) {
            sitesList = sitesDecoded
                .map<SiteAssociation>((siteData) =>
                    SiteAssociation.fromJson(siteData as Map<String, dynamic>))
                .toList();
          }
        }
      } else {
        throw Exception(
            'Erreur lors de la récupération des sites. Code: ${sitesResponse.statusCode}');
      }

      _currentUser = Utilisateur(
        id: userId,
        login: 'unknown',
        // À remplacer si vous disposez du login dans la réponse
        sites: sitesList,
      );
    } else {
      throw Exception(
          'Erreur lors de la récupération des rôles. Code: ${rolesResponse.statusCode}, message: ${rolesResponse.body}');
    }
  }

  Future<void> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'login': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      Map<String, dynamic> data = jsonDecode(response.body);
      int userIdFromApi = data['user_id'];
      // Récupération de la liste des associations de sites avec rôles depuis le login
      List<SiteAssociation> sitesList = [];
      if (data['sites'] != null) {
        final sitesDecoded = data['sites'] as List;
        sitesList = sitesDecoded
            .map<SiteAssociation>((siteData) =>
                SiteAssociation.fromJson(siteData as Map<String, dynamic>))
            .toList();
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAuthenticated', true);
      await prefs.setInt('user_id', userIdFromApi);

      _currentUser = Utilisateur(
        id: userIdFromApi,
        login: username,
        sites: sitesList,
      );
      _userId = userIdFromApi;
      _isAuthenticated = true;
      notifyListeners();
    } else {
      throw Exception('Erreur d\'authentification: ${response.statusCode}');
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _userId = null;
    _isAuthenticated = false;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isAuthenticated');
    await prefs.remove('user_id');
    notifyListeners();
  }
}
