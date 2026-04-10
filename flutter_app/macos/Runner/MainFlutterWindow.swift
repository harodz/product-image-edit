import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var dragDropChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    self.registerForDraggedTypes([.fileURL])
    dragDropChannel = FlutterMethodChannel(
      name: "product_image_edit/dragdrop",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    let hasFile = sender.draggingPasteboard.canReadObject(
      forClasses: [NSURL.self],
      options: [.urlReadingFileURLsOnly: true]
    )
    return hasFile ? .copy : []
  }

  func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    guard
      let dropped = sender.draggingPasteboard.readObjects(
        forClasses: [NSURL.self],
        options: [.urlReadingFileURLsOnly: true]
      ) as? [URL]
    else {
      return false
    }

    for url in dropped {
      var isDirectory: ObjCBool = false
      guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
        continue
      }
      if isDirectory.boolValue {
        dragDropChannel?.invokeMethod("onFolderDropped", arguments: url.path)
      } else {
        dragDropChannel?.invokeMethod("onInputPathDropped", arguments: url.path)
      }
      return true
    }
    return false
  }
}
