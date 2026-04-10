import 'package:flutter/services.dart';

class MacOsDragDropChannel {
  MacOsDragDropChannel();

  static const MethodChannel _channel = MethodChannel(
    'product_image_edit/dragdrop',
  );

  /// Folders and image files dropped on the window title bar / chrome.
  Future<void> bind({
    required void Function(String path) onPathDropped,
  }) async {
    _channel.setMethodCallHandler((call) async {
      if (call.arguments is String) {
        final path = call.arguments as String;
        if (call.method == 'onInputPathDropped' || call.method == 'onFolderDropped') {
          onPathDropped(path);
        }
      }
      return null;
    });
  }
}
