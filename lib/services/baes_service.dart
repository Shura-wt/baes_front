part of '../main.dart';

/// Service class for BAES-related operations.
class BaesService {
  static final Logger _logger = Logger('BaesService');

  /// Creates a new BAES via the API.
  static Future<Baes?> createBaes(
      String name, LatLng position, int etageId) async {
    _logger.start('createBaes');
    _logger.d('Name: $name, Position: $position, Floor ID: $etageId');

    try {
      // Convert LatLng to Map<String, dynamic>
      final Map<String, dynamic> positionMap = {
        'lat': position.latitude,
        'lng': position.longitude,
      };

      _logger.d(
          'Sending data: name=$name, position=$positionMap, etageId=$etageId');

      // Call the consolidated API method
      final baes = await BaesApi.createBaes(name, positionMap, etageId);

      if (baes != null) {
        _logger.d('BAES created with ID: ${baes.id}');
        _logger.end('createBaes', success: true);
        return baes;
      } else {
        _logger.end('createBaes', success: false, message: 'API returned null');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Exception during BAES creation', e, stackTrace);
      _logger.end('createBaes', success: false, message: e.toString());
      return null;
    }
  }

  /// Loads all BAES for a floor.
  static Future<List<Baes>> loadBaesForFloor(int etageId) async {
    _logger.start('loadBaesForFloor');
    _logger.d('Floor ID: $etageId');

    try {
      // Get BAES for the floor
      final baes = await BaesApi.getBaesByIdFloor(etageId);

      _logger.d('Number of BAES retrieved: ${baes.length}');

      // Log some information about the retrieved BAES
      if (baes.isNotEmpty) {
        for (var i = 0; i < baes.length.clamp(0, 5); i++) {
          _logger.d(
              'BAES #$i: ID=${baes[i].id}, Name=${baes[i].name}, Position=${baes[i].position}');
        }

        if (baes.length > 5) {
          _logger.d('... and ${baes.length - 5} more BAES');
        }
      }

      _logger.end('loadBaesForFloor', success: true);
      return baes;
    } catch (e, stackTrace) {
      _logger.e('Exception during BAES loading', e, stackTrace);
      _logger.end('loadBaesForFloor', success: false, message: e.toString());
      return [];
    }
  }

  /// Converts a list of BAES to a list of markers.
  static List<Marker> convertBaesToMarkers(List<Baes> baesList) {
    _logger.start('convertBaesToMarkers');
    _logger.d('Number of BAES to convert: ${baesList.length}');

    final List<Marker> markers = [];

    for (var baes in baesList) {
      // Check if the position is valid
      if (baes.position.containsKey('lat') &&
          baes.position.containsKey('lng')) {
        final lat = baes.position['lat'];
        final lng = baes.position['lng'];

        if (lat != null && lng != null) {
          markers.add(MapUtils.createBaesMarker(LatLng(lat, lng)));
        }
      }
    }

    _logger.d('Number of markers created: ${markers.length}');
    _logger.end('convertBaesToMarkers', success: true);

    return markers;
  }

  /// Creates a floor.
  static Future<Etage?> createFloor(String name, int batimentId) async {
    _logger.start('createFloor');
    _logger.d('Name: $name, Building ID: $batimentId');

    try {
      // Create the floor
      final floor = await BaesApi.createFloor(name, batimentId);

      if (floor != null) {
        _logger.d('Floor created with ID: ${floor.id}');
        _logger.end('createFloor', success: true);
      } else {
        _logger.end('createFloor',
            success: false, message: 'API returned null');
      }

      return floor;
    } catch (e, stackTrace) {
      _logger.e('Exception during floor creation', e, stackTrace);
      _logger.end('createFloor', success: false, message: e.toString());
      return null;
    }
  }

  /// Updates a floor.
  static Future<Etage?> updateFloor(int etageId, String name) async {
    _logger.start('updateFloor');
    _logger.d('ID: $etageId, New name: $name');

    try {
      // Update the floor
      final floor = await BaesApi.updateFloor(etageId, name);

      if (floor != null) {
        _logger.d('Floor updated with ID: ${floor.id}');
        _logger.end('updateFloor', success: true);
      } else {
        _logger.end('updateFloor',
            success: false, message: 'API returned null');
      }

      return floor;
    } catch (e, stackTrace) {
      _logger.e('Exception during floor update', e, stackTrace);
      _logger.end('updateFloor', success: false, message: e.toString());
      return null;
    }
  }

  /// Deletes a floor.
  static Future<bool> deleteFloor(int etageId) async {
    _logger.start('deleteFloor');
    _logger.d('ID: $etageId');

    try {
      // Delete the floor
      final success = await BaesApi.deleteFloor(etageId);

      _logger.d('Floor deletion ${success ? 'successful' : 'failed'}');
      _logger.end('deleteFloor', success: success);

      return success;
    } catch (e, stackTrace) {
      _logger.e('Exception during floor deletion', e, stackTrace);
      _logger.end('deleteFloor', success: false, message: e.toString());
      return false;
    }
  }
}
