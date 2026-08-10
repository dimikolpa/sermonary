import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let richClipboardChannel = FlutterMethodChannel(
      name: "sermonary/rich_clipboard",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    richClipboardChannel.setMethodCallHandler { call, result in
      guard call.method == "rtfToHtml" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let bytes = call.arguments as? FlutterStandardTypedData else {
        result(FlutterError(code: "invalid_rtf", message: "RTF-Daten fehlen.", details: nil))
        return
      }
      do {
        let attributed = try NSAttributedString(
          data: bytes.data,
          options: [.documentType: NSAttributedString.DocumentType.rtf],
          documentAttributes: nil
        )
        let html = try attributed.data(
          from: NSRange(location: 0, length: attributed.length),
          documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
        )
        result(String(data: html, encoding: .utf8))
      } catch {
        result(FlutterError(code: "invalid_rtf", message: error.localizedDescription, details: nil))
      }
    }

    let fileRevealChannel = FlutterMethodChannel(
      name: "sermonary/file_reveal",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    fileRevealChannel.setMethodCallHandler { call, result in
      guard call.method == "reveal" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let path = arguments["path"] as? String,
        FileManager.default.fileExists(atPath: path)
      else {
        result(FlutterError(code: "missing_path", message: "Der Ordner wurde nicht gefunden.", details: nil))
        return
      }
      NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
      result(nil)
    }

    super.awakeFromNib()
  }
}
