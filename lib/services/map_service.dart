part of '../main.dart';

/// Service class for map-related operations.
class MapService {
  static final Logger _logger = Logger('MapService');

  /// Converts building polygon points from the API format to LatLng list.
  static List<LatLng> convertBuildingPolygonPoints(List<dynamic>? points) {
    if (points == null || points.isEmpty) {
      return [];
    }

    List<LatLng> result = [];

    for (var point in points) {
      if (point is Map &&
          point.containsKey('lat') &&
          point.containsKey('lng')) {
        final lat = point['lat'];
        final lng = point['lng'];

        if (lat != null && lng != null) {
          result.add(LatLng(lat, lng));
        }
      }
    }

    return result;
  }

  /// Gets building polygons for a site.
  static List<Polygon> getBuildingPolygons(
      int siteId, List<Batiment> batiments) {
    _logger.start('getBuildingPolygons');
    _logger.d('Site ID: $siteId');

    List<Polygon> polygons = [];

    // Filter buildings for the site
    final siteBatiments = batiments.where((b) => b.siteId == siteId).toList();
    _logger.d('Number of buildings for site: ${siteBatiments.length}');

    for (var batiment in siteBatiments) {
      final points = convertBuildingPolygonPoints(batiment.polygonPoints);

      if (points.isNotEmpty) {
        polygons.add(
          Polygon(
            points: points,
            color: Colors.blue.withOpacity(0.3),
            borderColor: Colors.blue,
            borderStrokeWidth: 2,
          ),
        );

        _logger.d('Added polygon for building: ${batiment.name}');
      }
    }

    _logger.d('Total polygons created: ${polygons.length}');
    _logger.end('getBuildingPolygons', success: true);

    return polygons;
  }

  /// Gets image dimensions asynchronously.
  static Future<Map<String, double?>> getImageDimensions(
      String imageUrl) async {
    _logger.start('getImageDimensions');
    _logger.d('Image URL: $imageUrl');

    Completer<Map<String, double?>> completer = Completer();

    final imageProvider = NetworkImage(imageUrl);
    imageProvider.resolve(const ImageConfiguration()).addListener(
          ImageStreamListener(
            (ImageInfo imageInfo, bool synchronousCall) {
              final width = imageInfo.image.width.toDouble();
              final height = imageInfo.image.height.toDouble();

              _logger.d('Image dimensions: width=$width, height=$height');
              _logger.end('getImageDimensions', success: true);

              completer.complete({
                'width': width,
                'height': height,
              });
            },
            onError: (dynamic error, StackTrace? stackTrace) {
              _logger.e('Error loading image', error, stackTrace);
              _logger.end('getImageDimensions',
                  success: false, message: error.toString());

              completer.complete({
                'width': null,
                'height': null,
              });
            },
          ),
        );

    return completer.future;
  }

  /// Creates a map with an overlay image.
  static Widget createMapWithOverlayImage({
    required MapController mapController,
    required LatLng center,
    required double zoom,
    required String imageUrl,
    required double? effectiveWidth,
    required double? effectiveHeight,
    List<Marker> markers = const [],
    List<Polygon> polygons = const [],
    Function(TapPosition, LatLng)? onTap,
  }) {
    _logger.start('createMapWithOverlayImage');

    // Use default values if dimensions are not provided
    double width = effectiveWidth ?? 180.0;
    double height = effectiveHeight ?? 90.0;

    // Normalize dimensions
    final normalized = MapUtils.normalizeImageDimensions(height, width);
    double normalizedHeight = normalized['height']!;
    double normalizedWidth = normalized['width']!;
    double scaleFactor = normalized['scaleFactor']!;

    // Apply scale factor to center coordinates
    double centerLat = center.latitude * scaleFactor;
    double centerLng = center.longitude * scaleFactor;

    _logger.d(
        'Normalized dimensions: width=$normalizedWidth, height=$normalizedHeight, scale=$scaleFactor');
    _logger.d('Center: lat=$centerLat, lng=$centerLng, zoom=$zoom');
    _logger.end('createMapWithOverlayImage', success: true);

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        crs: const CrsSimple(),
        initialCenter: LatLng(centerLat, centerLng),
        initialZoom: zoom,
        maxZoom: zoom + 10,
        minZoom: zoom - 10,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onTap: onTap,
      ),
      children: [
        OverlayImageLayer(
          overlayImages: [
            OverlayImage(
              bounds: LatLngBounds(
                const LatLng(0, 0),
                LatLng(normalizedHeight, normalizedWidth),
              ),
              opacity: 1.0,
              imageProvider: NetworkImage(imageUrl),
            ),
          ],
        ),
        if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }

  /// Creates a map with an overlay image from memory.
  static Widget createMapWithMemoryImage({
    required MapController mapController,
    required LatLng center,
    required double zoom,
    required Uint8List imageBytes,
    required double? effectiveWidth,
    required double? effectiveHeight,
    List<Marker> markers = const [],
    Function(TapPosition, LatLng)? onTap,
  }) {
    _logger.start('createMapWithMemoryImage');

    // Use default values if dimensions are not provided
    double width = effectiveWidth ?? 180.0;
    double height = effectiveHeight ?? 90.0;

    _logger.d('Dimensions: width=$width, height=$height');
    _logger.d(
        'Center: lat=${center.latitude}, lng=${center.longitude}, zoom=$zoom');
    _logger.end('createMapWithMemoryImage', success: true);

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        crs: const CrsSimple(),
        initialCenter: center,
        initialZoom: zoom,
        maxZoom: 20,
        minZoom: -20,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onTap: onTap,
      ),
      children: [
        OverlayImageLayer(
          overlayImages: [
            OverlayImage(
              bounds: LatLngBounds(
                const LatLng(0, 0),
                LatLng(height, width),
              ),
              opacity: 1.0,
              imageProvider: MemoryImage(imageBytes),
            ),
          ],
        ),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }
}
