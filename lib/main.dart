library baes_front;

import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http_parser/http_parser.dart';
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:baes_front/config.dart';

// Utils
part 'utils/logger.dart';

part 'utils/api_utils.dart';

part 'utils/map_utils.dart';

part 'utils/ui_utils.dart';

// Services
part 'services/baes_service.dart';

part 'services/map_service.dart';

// Widgets
part 'widgets/drawer.dart';

part 'widgets/utilisateur_dialog.dart';

part 'widgets/gradiant_background.dart';

// Services
part 'services/auth_provider.dart';

part 'services/router_guard.dart';

part 'services/api/carte_api.dart';

part 'services/site_provider.dart';

// Pages
part 'pages/home.dart';

part 'pages/view.dart';

part 'pages/admin/gestion_carte.dart';

part 'pages/admin/gestion_utilisateurs.dart';

part 'pages/login.dart';

// Models
part 'models/utilisateur.dart';

part 'models/baes.dart';

part 'models/etage.dart';

part 'models/coordonee.dart';

part 'models/site.dart';

part 'models/batiment.dart';

part 'models/role.dart';

part 'models/historique_erreur.dart';

part 'models/carte.dart';

part 'models/site_association.dart';

//API
part 'services/api/utilisateur_api.dart';

part 'services/api/site_api.dart';

part 'services/api/BAES_api.dart';

part 'services/api/API_batiment.dart';

part 'services/api/erreur_api.dart';

part 'services/general.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SiteProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Configuration des routes
      routes: {
        '/login': (context) => const LoginPage(),
        // Page home (protégée, mais accessible par tout rôle)
        '/home': (context) => const AuthGuard(child: HomePage()),
        '/view': (context) => const AuthGuard(
              child: VisualisationCartePage(),
            ),

        // Pages admin (nécessitent requiresAdmin = true)
        '/admin/carte': (context) => const AuthGuard(
              requiredRoles: ['admin', 'super-admin'],
              child: HomePage(initialPage: 'carte'),
            ),
        '/admin/utilisateurs': (context) => const AuthGuard(
              requiredRoles: ['admin', 'super-admin'],
              child: HomePage(initialPage: 'utilisateurs'),
            ),
      },

      // Page de démarrage
      home: const HomePage(),

      title: 'BAES Front',
      theme: ThemeData(
        useMaterial3: true,
      ),
    );
  }
}
