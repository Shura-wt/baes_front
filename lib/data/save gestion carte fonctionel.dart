//
// part of '../../main.dart';
//
// class GestionCartePage extends StatefulWidget {
//   const GestionCartePage({super.key});
//
//   @override
//   State<GestionCartePage> createState() => _GestionCartePageState();
// }
//
// class _GestionCartePageState extends State<GestionCartePage> {
//   Map<String, dynamic>? mapData; // Stocke les données calculées pour la carte
//   final String imagePath = 'siteX/vue_site.jpg'; // Chemin de l'image
//   bool statePolygons = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeMapData();
//   }
//
//   Future<void> _initializeMapData() async {
//     // Charger les données de l'image
//     final imageInfo = await Carteloader.loadImage();
//     if (imageInfo != null) {
//       setState(() {
//         // Calculer les bounds et le centre en fonction des données de l'image
//         final double ratio = imageInfo['ratio'];
//         final double boundsWidth = 0.005; // Largeur géographique fixe
//         final double boundsHeight = boundsWidth / ratio;
//
//         final LatLng center = LatLng(boundsHeight / 2, boundsWidth / 2);
//
//         mapData = {
//           'bounds': LatLngBounds(
//             LatLng(center.latitude + boundsHeight / 2,
//                 center.longitude - boundsWidth / 2), // Coin supérieur gauche
//             LatLng(center.latitude - boundsHeight / 2,
//                 center.longitude + boundsWidth / 2), // Coin inférieur droit
//           ),
//           'initCenter': center,
//           'initZoom': 18.2 // Zoom initial par défaut
//         };
//       });
//     } else {
//       print('Erreur : Impossible de charger les informations de l\'image.');
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Gestion de la carte'),
//       ),
//       body: Center(
//         child: mapData == null
//             ? const CircularProgressIndicator() // Chargement en cours
//             : FlutterMap(
//           options: MapOptions(
//             initialCenter: mapData!['initCenter'], // Centre calculé
//             initialZoom: mapData!['initZoom'], // Zoom calculé
//           ),
//           children: [
//             OverlayImage(
//               bounds: mapData!['bounds'], // Bounds calculés
//               imageProvider: AssetImage(imagePath), // Image statique
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
