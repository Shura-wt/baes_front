part of '../main.dart';

/// Utility class for map-related operations.
class MapUtils {
  /// The maximum valid latitude value.
  static const double maxValidLat = 90.0;

  /// The maximum valid longitude value.
  static const double maxValidLng = 180.0;

  /// Normalizes image dimensions to fit within valid latitude and longitude ranges.
  ///
  /// Returns a tuple containing the normalized height, width, and scale factor.
  static Map<String, double> normalizeImageDimensions(
      double height, double width) {
    double scaleFactor = 1.0;

    // Calculate scale factor for latitude
    if (height > maxValidLat) {
      scaleFactor = maxValidLat / height;
    }

    // Calculate scale factor for longitude
    if (width > maxValidLng) {
      double lngScaleFactor = maxValidLng / width;
      // Use the more restrictive scale factor
      scaleFactor = scaleFactor < lngScaleFactor ? scaleFactor : lngScaleFactor;
    }

    return {
      'height': height * scaleFactor,
      'width': width * scaleFactor,
      'scaleFactor': scaleFactor,
    };
  }

  /// Checks if a point is inside a polygon using the ray casting algorithm.
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.isEmpty) return false;

    bool isInside = false;
    int i = 0, j = polygon.length - 1;

    for (i = 0; i < polygon.length; i++) {
      if (((polygon[i].latitude > point.latitude) !=
              (polygon[j].latitude > point.latitude)) &&
          (point.longitude <
              (polygon[j].longitude - polygon[i].longitude) *
                      (point.latitude - polygon[i].latitude) /
                      (polygon[j].latitude - polygon[i].latitude) +
                  polygon[i].longitude)) {
        isInside = !isInside;
      }
      j = i;
    }

    return isInside;
  }

  /// Creates a marker with a circle and optional label.
  static Marker createCircleMarker({
    required LatLng point,
    required Color color,
    double width = 20,
    double height = 20,
    String? label,
    Color textColor = Colors.white,
    double fontSize = 10,
    FontWeight fontWeight = FontWeight.bold,
  }) {
    return Marker(
      point: point,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: label != null
              ? Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  /// Creates a BAES marker.
  static Marker createBaesMarker(LatLng point) {
    return Marker(
      point: point,
      width: 30,
      height: 30,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.lightbulb,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
