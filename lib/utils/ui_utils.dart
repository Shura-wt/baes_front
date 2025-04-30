part of '../main.dart';

/// Utility class for UI-related operations.
class UiUtils {
  static final Logger _logger = Logger('UiUtils');

  /// Shows a snackbar with the given message.
  static void showSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    _logger.d('Showing snackbar: $message');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  /// Shows a loading dialog.
  static Future<void> showLoadingDialog(
      BuildContext context, String message) async {
    _logger.d('Showing loading dialog: $message');

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  /// Shows a confirmation dialog.
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = 'Confirmer',
    String cancelText = 'Annuler',
    bool isDestructive = false,
  }) async {
    _logger.d('Showing confirmation dialog: $title');

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: isDestructive
                  ? TextButton.styleFrom(foregroundColor: Colors.red)
                  : null,
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Shows a text input dialog.
  static Future<String?> showTextInputDialog(
    BuildContext context, {
    required String title,
    String? initialValue,
    String hintText = '',
    String confirmText = 'Valider',
    String cancelText = 'Annuler',
  }) async {
    _logger.d('Showing text input dialog: $title');

    final TextEditingController controller =
        TextEditingController(text: initialValue);

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Navigator.of(context).pop(controller.text);
                }
              },
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result;
  }

  /// Creates a container with a dropdown button.
  static Widget createDropdownContainer<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required String hintText,
    double width = double.infinity,
    Color backgroundColor = Colors.white,
    double opacity = 0.8,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 12),
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(8)),
  }) {
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(opacity),
        borderRadius: borderRadius,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hintText),
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
