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

          // Print user roles at session restoration
          print(
              'User roles (restored session): ${_currentUser?.globalRoles.join(', ')}');
        } catch (e) {
          _isAuthenticated = false;
        }
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Récupère les rôles et associations de sites de l'utilisateur via l'API
  /// en utilisant son id. Cette méthode consolidée gère à la fois le nouvel endpoint
  /// et l'ancien, avec un mécanisme de cache pour éviter les appels redondants.
  Future<void> _fetchUserRoles(int userId) async {
    // Variable pour suivre si nous avons déjà essayé le nouvel endpoint
    Map<int, bool> newEndpointAvailable = {};

    try {
      // Si nous savons déjà que le nouvel endpoint n'est pas disponible pour cet utilisateur,
      // utiliser directement la méthode legacy
      if (newEndpointAvailable.containsKey(userId) &&
          !newEndpointAvailable[userId]!) {
        await _fetchUserRolesInternal(userId, useLegacy: true);
        return;
      }

      // Essayer d'abord le nouvel endpoint
      await _fetchUserRolesInternal(userId, useLegacy: false);

      // Si nous arrivons ici, le nouvel endpoint a fonctionné
      newEndpointAvailable[userId] = true;
    } catch (e) {
      // Si le nouvel endpoint a échoué, marquer comme non disponible et essayer la méthode legacy
      newEndpointAvailable[userId] = false;

      try {
        await _fetchUserRolesInternal(userId, useLegacy: true);
      } catch (legacyError) {
        // Si même la méthode legacy échoue, propager l'erreur
        throw Exception(
            'Erreur lors de la récupération des rôles de l\'utilisateur: $legacyError');
      }
    }
  }

  /// Méthode interne pour récupérer les rôles et associations de sites de l'utilisateur
  /// Cette méthode est utilisée par _fetchUserRoles et ne devrait pas être appelée directement.
  Future<void> _fetchUserRolesInternal(int userId,
      {required bool useLegacy}) async {
    if (useLegacy) {
      // Méthode legacy
      // Appel pour récupérer les rôles (si nécessaire)
      final rolesUrl = Uri.parse('$baseUrl/role/users/$userId/roles');

      final rolesResponse = await http.get(rolesUrl);

      if (rolesResponse.statusCode == 200) {
        List<dynamic> rolesData = jsonDecode(rolesResponse.body);
        // Extraction des noms de rôles (peut être utile pour d'autres traitements)
        List<Role> globalRolesList = rolesData
            .map<Role>(
                (roleData) => Role.fromJson(roleData as Map<String, dynamic>))
            .toList();

        // Appel pour récupérer les associations de sites (avec rôles) de l'utilisateur
        final sitesUrl = Uri.parse('$baseUrl/users/sites/$userId/sites');

        final sitesResponse = await http.get(sitesUrl);

        List<SiteAssociation> sitesList = [];
        if (sitesResponse.statusCode == 200) {
          if (sitesResponse.body.isNotEmpty && sitesResponse.body != 'null') {
            final dynamic sitesDecoded = jsonDecode(sitesResponse.body);
            if (sitesDecoded is List) {
              sitesList = sitesDecoded
                  .map<SiteAssociation>((siteData) => SiteAssociation.fromJson(
                      siteData as Map<String, dynamic>))
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
          sites: sitesList,
          globalRolesList: globalRolesList,
        );
      } else {
        throw Exception(
            'Erreur lors de la récupération des rôles. Code: ${rolesResponse.statusCode}, message: ${rolesResponse.body}');
      }
    } else {
      // Nouvel endpoint
      final authUrl = Uri.parse('$baseUrl/auth/user/$userId');

      final authResponse = await http.get(authUrl);

      if (authResponse.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(authResponse.body);

        // Récupération de la liste des associations de sites avec rôles
        List<SiteAssociation> sitesList = [];
        if (data['sites'] != null) {
          final sitesDecoded = data['sites'] as List;
          sitesList = sitesDecoded
              .map<SiteAssociation>((siteData) =>
                  SiteAssociation.fromJson(siteData as Map<String, dynamic>))
              .toList();
        }

        // Récupération des rôles globaux
        List<Role> globalRolesList = [];
        if (data['global_roles'] != null) {
          final globalRolesDecoded = data['global_roles'] as List;
          globalRolesList = globalRolesDecoded
              .map<Role>(
                  (roleData) => Role.fromJson(roleData as Map<String, dynamic>))
              .toList();
        }

        String login = data['login'] ?? 'unknown';

        _currentUser = Utilisateur(
          id: userId,
          login: login,
          sites: sitesList,
          globalRolesList: globalRolesList,
        );
      } else {
        throw Exception(
            'Erreur lors de la récupération des informations utilisateur. Code: ${authResponse.statusCode}');
      }
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

      // Récupération des rôles globaux
      List<Role> globalRolesList = [];
      if (data['global_roles'] != null) {
        final globalRolesDecoded = data['global_roles'] as List;
        globalRolesList = globalRolesDecoded
            .map<Role>(
                (roleData) => Role.fromJson(roleData as Map<String, dynamic>))
            .toList();
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAuthenticated', true);
      await prefs.setInt('user_id', userIdFromApi);

      _currentUser = Utilisateur(
        id: userIdFromApi,
        login: username,
        sites: sitesList,
        globalRolesList: globalRolesList,
      );
      _userId = userIdFromApi;
      _isAuthenticated = true;

      // Print user roles at login
      print('User roles: ${_currentUser?.globalRoles.join(', ')}');

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
