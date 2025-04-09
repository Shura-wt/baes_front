library baes_front;

import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'dart:html' as html;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

// Widgets
part 'widgets/drawer.dart';

// part 'widgets/utilisateur_dialog.dart';

part 'widgets/gradiant_background.dart';

// Services
part 'services/auth_provider.dart';

part 'services/router_guard.dart';

part 'services/image_to_tile.dart';

part 'services/API_carte.dart';

part 'services/site_provider.dart';

// Pages
part 'pages/home.dart';

part 'pages/view_carte_page.dart';

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
part 'models/api/utilisateur_api.dart';

part 'models/api/site_api.dart';

part 'models/api/BAES_api.dart';

part 'models/api/etage_api.dart';

part 'models/api/coordonee_api.dart';

part 'models/api/batiment_api.dart';

// Data
part 'data/save.dart';

part 'models/api/general.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SiteProvider()..loadSites()),
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
