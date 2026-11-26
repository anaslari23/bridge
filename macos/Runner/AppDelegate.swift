import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  let bridgeChannel = BridgeChannel()

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController
    else { return }
    let registrar = controller.registrar(forPlugin: "BridgeChannel")
    bridgeChannel.register(with: registrar)
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    return true
  }

  override func applicationShouldTerminateAfterLastWindowClosed(
    _ application: NSApplication
  ) -> Bool {
    return false   // daemon keeps running when overlay is hidden
  }

  override func applicationSupportsSecureRestorableState(
    _ app: NSApplication
  ) -> Bool {
    return true
  }
}
