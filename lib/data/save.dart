part of '../main.dart';
//
// class SavePage extends StatefulWidget {
//   const SavePage({super.key});
//
//   @override
//   State<SavePage> createState() => _SavePageState();
// }
//
// class _SavePageState extends State<SavePage> {
//   final List<LatLng> points = [];
//   final List<Polygon> polygons = [];
//   final LayerHitResult<Polygon<Object>> hitNotifier =  LayerHitResult<Polygon<Object>> (hitValues: [ ],coordinate: LatLng(0, 0) ,point: Point(0, 0));
//
//   @override
//   Widget build(BuildContext context) {
//     const LatLng mapCenter = LatLng(48.8566, 2.3522);
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Gestion bloc BAES"),
//       ),
//       body: FlutterMap(
//         options: MapOptions(
//           initialCenter: mapCenter,
//           initialZoom: 18.0,
//           onTap: (tapPosition, point) {
//             setState(() {
//               points.add(point);
//               if (points.length == 4) {
//                 drawPolygone();
//                 points.clear();
//               }
//             });
//           },
//         ),
//         children: [
//           PolygonLayer(
//             polygons: polygons,
//             hitNotifier: hitNotifier
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           final LayerHitResult<Polygon>? hitResult
//
//           if (hitResult == null || hitResult.hitValues.isEmpty) {
//             print("Aucun polygone n'a été cliqué.");
//           } else {
//             for (final hitPolygon in hitResult.hitValues) {
//               print("Test zone cliquable : ${hitPolygon.hitValue}");
//             }
//           }
//         },
//         child: const Icon(Icons.info),
//       ),
//     );
//   }
//
//   void drawPolygone() {
//     setState(() {
//       polygons.add(
//         Polygon(
//           points: List.from(points),
//           borderColor: Colors.blue,
//           borderStrokeWidth: 3.0,
//           color: Colors.blue.withOpacity(0.3),
//           hitValue: polygons.length, // Unique hitValue
//         ),
//       );
//     });
//   }
// }
