part of '../main.dart';

/// Ce widget permet de protéger l'accès à une partie de l'application en vérifiant
/// si l'utilisateur est authentifié et s'il possède au moins l'un des rôles requis.
class AuthGuard extends StatelessWidget {
  final Widget child;
  final List<String>? requiredRoles; // Par exemple : ['admin', 'super-admin']

  const AuthGuard({
    super.key,
    required this.child,
    this.requiredRoles,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!authProvider.isAuthenticated) {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (requiredRoles != null && requiredRoles!.isNotEmpty) {
      // Utiliser le getter globalRoles
      bool hasRole = authProvider.currentUser?.globalRoles
              .any((role) => requiredRoles!.contains(role)) ??
          false;
      if (!hasRole) {
        Future.microtask(
            () => Navigator.pushReplacementNamed(context, '/home'));
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
    }

    return child;
  }
}
