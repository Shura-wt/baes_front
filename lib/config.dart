// lib/config.dart

class Config {
  // Vous pouvez avoir plusieurs constantes en fonction de l'environnement.
  // Pour le moment, nous définissons simplement une URL de base.

  // Environnement de développement
  static const String baseUrlDev = "http://localhost:5000";

  // Environnement de production
  static const String baseUrlProd = "https://api.mondomaine.com";

  // Pour sélectionner l'environnement à utiliser, vous pouvez définir une constante :
  static const bool isProduction = false;

  // URL de base utilisée dans l'application
  static String get baseUrl => isProduction ? baseUrlProd : baseUrlDev;
}
