part of '../main.dart';

/// A simple logging utility for the application.
///
/// This class provides methods for logging messages at different levels
/// and can be configured to show or hide logs based on the current environment.
class Logger {
  /// The tag to identify the source of the log.
  final String tag;

  /// Whether to show debug logs.
  static bool showDebugLogs = false;

  /// Creates a new logger with the specified tag.
  Logger(this.tag);

  /// Logs a debug message.
  ///
  /// Debug logs are only shown in debug mode or if [showDebugLogs] is true.
  void d(String message) {
    // Debug logs disabled
  }

  /// Logs an info message.
  void i(String message) {
    // Info logs disabled
  }

  /// Logs a warning message.
  void w(String message) {
    // Warning logs disabled
  }

  /// Logs an error message.
  void e(String message, [Object? error, StackTrace? stackTrace]) {
    // Error logs disabled
  }

  /// Logs the start of a method or operation.
  void start(String methodName) {
    // Start logs disabled
  }

  /// Logs the end of a method or operation.
  void end(String methodName, {bool success = true, String? message}) {
    // End logs disabled
  }
}
