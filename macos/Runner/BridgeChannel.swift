import Cocoa
import FlutterMacOS

class BridgeChannel: NSObject {
  static let channelName = "com.brigade.bridge/channel"
  private var channel: FlutterMethodChannel?
  private var statusItem: NSStatusItem?

  func register(with registrar: FlutterPluginRegistrar) {
    channel = FlutterMethodChannel(
      name: BridgeChannel.channelName,
      binaryMessenger: registrar.messenger
    )
    channel?.setMethodCallHandler(handle)
    setupStatusItem()
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "showPanel":
      NSApp.windows.first?.makeKeyAndOrderFront(nil)
      result(nil)
    case "hidePanel":
      NSApp.windows.first?.orderOut(nil)
      result(nil)
    case "setStatusBadge":
      let state = call.arguments as? String ?? "idle"
      updateBadge(state: state)
      result(nil)
    case "requestAccessibility":
      let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
      AXIsProcessTrustedWithOptions(options as CFDictionary)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func setupStatusItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = statusItem?.button {
      button.title = "✦"
      button.target = self
      button.action = #selector(togglePanel)
      // Default: green idle
      button.contentTintColor = NSColor.systemGreen
    }
  }

  @objc private func togglePanel() {
    channel?.invokeMethod("hotkey_fired", arguments: nil)
  }

  private func updateBadge(state: String) {
    guard let button = statusItem?.button else { return }
    switch state {
    case "running", "waiting":
      button.contentTintColor = NSColor.systemOrange
    case "stopped":
      button.contentTintColor = NSColor.systemRed
    default:
      button.contentTintColor = NSColor.systemGreen
    }
  }
}
