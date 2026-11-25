import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Matches Windows runner client size in `windows/runner/main.cpp`.
  private static let fixedContentSize = NSSize(width: 393, height: 852)

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    contentViewController = flutterViewController

    // Fixed phone-sized frame: same default as Windows (non-resizable).
    styleMask.remove(.resizable)
    collectionBehavior.remove(.fullScreenPrimary)
    collectionBehavior.remove(.fullScreenAuxiliary)

    setContentSize(Self.fixedContentSize)
    minSize = frame.size
    maxSize = frame.size
    standardWindowButton(.zoomButton)?.isEnabled = false
    center()

    RegisterGeneratedPlugins(registry: flutterViewController)
    SystemProxyPlugin.register(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
