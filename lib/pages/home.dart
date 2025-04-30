part of '../main.dart';

class HomePage extends StatefulWidget {
  final String? initialPage;

  const HomePage({super.key, this.initialPage});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late String _currentPage;

  @override
  void initState() {
    super.initState();

    _currentPage = widget.initialPage ?? 'home';
  }

  // Méthode pour créer un bouton de navigation.
  // On accepte un paramètre textStyle pour forcer la taille (ici fontSize: 75).
  TextButton _buildNavButton({
    required BuildContext context,
    required String page,
    required String text,
    required String route,
    TextStyle? textStyle,
  }) {
    bool isActive = _currentPage == page;
    // Style par défaut avec fontSize 75.
    TextStyle defaultStyle = const TextStyle(
      fontSize: 75,
      fontWeight: FontWeight.bold,
    );
    TextStyle finalStyle = (textStyle ?? defaultStyle).copyWith(
      color: isActive ? Colors.yellow : Colors.white,
      fontWeight: FontWeight.bold,
    );

    return TextButton(
      onPressed: () {
        if (!isActive) {
          Navigator.pushReplacementNamed(context, route);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: finalStyle,
          ),
          // Ligne de soulignement si le bouton est actif.
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 2.0),
              height: 2.0,
              width: 20.0,
              color: Colors.yellow,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Affichage d'un indicateur de chargement
    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Redirection si l'utilisateur n'est pas authentifié
    if (!authProvider.isAuthenticated) {
      // ignore: use_build_context_synchronously
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Sélection du contenu en fonction de _currentPage
    Widget bodyContent;
    switch (_currentPage) {
      case 'home':
        bodyContent = const ViewCartePage();
        break;
      case 'carte':
        bodyContent = const GestionCartePage();
        break;
      case 'utilisateurs':
        bodyContent = const GestionUtilisateursPage();
        break;
      default:
        bodyContent = const ViewCartePage();
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100.0),
        child: AppBar(
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF0a526a),
          title: _buildNavButton(
            context: context,
            page: 'home',
            text: "Gestion bloc BAES",
            route: '/home',
            textStyle: const TextStyle(fontSize: 30),
          ),
          actions: [
            if (authProvider.isAdmin || authProvider.isSuperAdmin) ...[
              _buildNavButton(
                context: context,
                page: 'carte',
                text: "Gestion carte",
                route: '/admin/carte',
                textStyle: const TextStyle(fontSize: 30),
              ),
              _buildNavButton(
                context: context,
                page: 'utilisateurs',
                text: "Gestion utilisateurs",
                route: '/admin/utilisateurs',
                textStyle: const TextStyle(fontSize: 30),
              ),
            ],
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                authProvider.logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
              tooltip: "Se déconnecter",
            ),
          ],
        ),
      ),
      drawer: const LeftDrawer(),
      body: GradiantBackground.getSafeAreaGradiant(context, bodyContent),
    );
  }
}
