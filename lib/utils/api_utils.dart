part of '../main.dart';

/// Utility class for API-related operations.
class ApiUtils {
  static final Logger _logger = Logger('ApiUtils');

  /// Performs a GET request to the specified URL.
  ///
  /// Returns the decoded JSON response if successful, or null if an error occurs.
  static Future<dynamic> get(String url, {Map<String, String>? headers}) async {
    _logger.start('GET $url');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: headers ?? {'Content-Type': 'application/json'},
      );

      _logger.d('Response status code: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonData = jsonDecode(response.body);
        _logger.end('GET $url', success: true);
        return jsonData;
      } else {
        _logger.e('HTTP error: ${response.statusCode}', response.body);
        _logger.end('GET $url',
            success: false, message: 'HTTP error ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Exception during GET request', e, stackTrace);
      _logger.end('GET $url', success: false, message: e.toString());
      return null;
    }
  }

  /// Performs a POST request to the specified URL with the given body.
  ///
  /// Returns the decoded JSON response if successful, or null if an error occurs.
  static Future<dynamic> post(String url, dynamic body,
      {Map<String, String>? headers}) async {
    _logger.start('POST $url');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers ?? {'Content-Type': 'application/json'},
        body: body is String ? body : jsonEncode(body),
      );

      _logger.d('Response status code: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonData = jsonDecode(response.body);
        _logger.end('POST $url', success: true);
        return jsonData;
      } else {
        _logger.e('HTTP error: ${response.statusCode}', response.body);
        _logger.end('POST $url',
            success: false, message: 'HTTP error ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Exception during POST request', e, stackTrace);
      _logger.end('POST $url', success: false, message: e.toString());
      return null;
    }
  }

  /// Performs a PUT request to the specified URL with the given body.
  ///
  /// Returns the decoded JSON response if successful, or null if an error occurs.
  static Future<dynamic> put(String url, dynamic body,
      {Map<String, String>? headers}) async {
    _logger.start('PUT $url');

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: headers ?? {'Content-Type': 'application/json'},
        body: body is String ? body : jsonEncode(body),
      );

      _logger.d('Response status code: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonData = jsonDecode(response.body);
        _logger.end('PUT $url', success: true);
        return jsonData;
      } else {
        _logger.e('HTTP error: ${response.statusCode}', response.body);
        _logger.end('PUT $url',
            success: false, message: 'HTTP error ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Exception during PUT request', e, stackTrace);
      _logger.end('PUT $url', success: false, message: e.toString());
      return null;
    }
  }

  /// Performs a DELETE request to the specified URL.
  ///
  /// Returns true if successful, or false if an error occurs.
  static Future<bool> delete(String url, {Map<String, String>? headers}) async {
    _logger.start('DELETE $url');

    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: headers ?? {'Content-Type': 'application/json'},
      );

      _logger.d('Response status code: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _logger.end('DELETE $url', success: true);
        return true;
      } else {
        _logger.e('HTTP error: ${response.statusCode}', response.body);
        _logger.end('DELETE $url',
            success: false, message: 'HTTP error ${response.statusCode}');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('Exception during DELETE request', e, stackTrace);
      _logger.end('DELETE $url', success: false, message: e.toString());
      return false;
    }
  }
}
