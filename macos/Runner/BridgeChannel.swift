import Cocoa
import FlutterMacOS
import ApplicationServices
import ServiceManagement
import CoreGraphics

class BridgeChannel: NSObject {
  static let channelName = "com.brigade.bridge/channel"
  private var channel: FlutterMethodChannel?
  private var statusItem: NSStatusItem?
  private var globalKeyMonitor: Any?
  private var localKeyMonitor: Any?
  private var securityScopedDirectory: URL?

  deinit {
    if let monitor = globalKeyMonitor { NSEvent.removeMonitor(monitor) }
    if let monitor = localKeyMonitor { NSEvent.removeMonitor(monitor) }
    securityScopedDirectory?.stopAccessingSecurityScopedResource()
  }

  func register(with registrar: FlutterPluginRegistrar) {
    channel = FlutterMethodChannel(
      name: BridgeChannel.channelName,
      binaryMessenger: registrar.messenger
    )
    channel?.setMethodCallHandler(handle)
    setupStatusItem()
    setupGlobalShortcut()
    restoreOverlaySettings()
    restoreSecurityScopedDirectory()
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
    case "isAccessibilityEnabled":
      result(AXIsProcessTrusted())
    case "isScreenRecordingEnabled":
      if #available(macOS 10.15, *) {
        result(CGPreflightScreenCaptureAccess())
      } else {
        result(true)
      }
    case "requestScreenRecording":
      if #available(macOS 10.15, *) {
        result(CGRequestScreenCaptureAccess())
      } else {
        result(true)
      }
    case "setClickThrough":
      let enabled = call.arguments as? Bool ?? false
      NSApp.windows.first?.ignoresMouseEvents = enabled
      UserDefaults.standard.set(enabled, forKey: "bridge.clickThrough")
      result(nil)
    case "isClickThroughEnabled":
      result(UserDefaults.standard.bool(forKey: "bridge.clickThrough"))
    case "setOpacity":
      let opacity = call.arguments as? Double ?? 1.0
      let clamped = min(max(opacity, 0.2), 1.0)
      NSApp.windows.first?.alphaValue = clamped
      UserDefaults.standard.set(clamped, forKey: "bridge.opacity")
      result(nil)
    case "getOpacity":
      result(UserDefaults.standard.object(forKey: "bridge.opacity") as? Double ?? 1.0)
    case "setLaunchAtLogin":
      guard #available(macOS 13.0, *) else {
        result(FlutterError(code: "UNSUPPORTED", message: "Launch at login requires macOS 13 or later", details: nil))
        return
      }
      do {
        if call.arguments as? Bool == true {
          try SMAppService.mainApp.register()
        } else {
          try SMAppService.mainApp.unregister()
        }
        result(nil)
      } catch {
        result(FlutterError(code: "LOGIN_ITEM_FAILED", message: error.localizedDescription, details: nil))
      }
    case "isLaunchAtLoginEnabled":
      guard #available(macOS 13.0, *) else {
        result(false)
        return
      }
      result(SMAppService.mainApp.status == .enabled)
    case "isOnboardingComplete":
      result(UserDefaults.standard.bool(forKey: "bridge.onboardingComplete"))
    case "setOnboardingComplete":
      UserDefaults.standard.set(call.arguments as? Bool ?? false,
                                 forKey: "bridge.onboardingComplete")
      result(nil)
    case "chooseDirectory":
      let panel = NSOpenPanel()
      panel.canChooseFiles = false
      panel.canChooseDirectories = true
      panel.allowsMultipleSelection = false
      panel.prompt = "Use Folder"
      panel.begin { response in
        guard response == .OK, let url = panel.url else {
          result(nil)
          return
        }
        self.rememberSecurityScopedDirectory(url)
        result(url.path)
      }
    case "chooseFiles":
      let panel = NSOpenPanel()
      panel.canChooseFiles = true
      panel.canChooseDirectories = false
      panel.allowsMultipleSelection = true
      panel.prompt = "Attach"
      panel.begin { response in
        result(response == .OK ? panel.urls.map { $0.path } : [])
      }
    case "openFile":
      guard let path = call.arguments as? String else {
        result(false)
        return
      }
      result(NSWorkspace.shared.open(URL(fileURLWithPath: path)))
    case "captureWindow":
      guard let id = call.arguments as? String,
            let (app, window) = findWindow(id),
            let image = capture(window: window, pid: app.processIdentifier, id: id),
            let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        result(FlutterError(code: "CAPTURE_FAILED", message: "The target window could not be captured", details: nil))
        return
      }
      result(FlutterStandardTypedData(bytes: data))
    case "discoverWindows":
      result(discoverWindows())
    case "inspectWindow":
      guard let id = call.arguments as? String,
            let (_, window) = findWindow(id) else {
        result(FlutterError(code: "WINDOW_NOT_FOUND", message: "The target window is no longer available", details: nil))
        return
      }
      result(inspect(window: window, id: id))
    case "focusWindow":
      guard let id = call.arguments as? String,
            let (app, window) = findWindow(id) else {
        result(false)
        return
      }
      app.activate(options: [.activateIgnoringOtherApps])
      result(AXUIElementPerformAction(window, kAXRaiseAction as CFString) == .success)
    case "setFocusedText":
      guard let args = call.arguments as? [String: Any],
            let id = args["id"] as? String,
            let text = args["text"] as? String,
            let (app, window) = findWindow(id),
            let focused = focusedElement(app: app, targetWindow: window) else {
        result(false)
        return
      }
      app.activate(options: [.activateIgnoringOtherApps])
      _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
      result(AXUIElementSetAttributeValue(focused, kAXValueAttribute as CFString, text as CFTypeRef) == .success)
    case "pressFocusedControl":
      guard let id = call.arguments as? String,
            let (app, window) = findWindow(id),
            let focused = focusedElement(app: app, targetWindow: window) else {
        result(false)
        return
      }
      app.activate(options: [.activateIgnoringOtherApps])
      _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
      result(AXUIElementPerformAction(focused, kAXPressAction as CFString) == .success)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func discoverWindows() -> [[String: Any]] {
    guard AXIsProcessTrusted() else { return [] }
    let currentBundleId = Bundle.main.bundleIdentifier
    var output: [[String: Any]] = []
    for app in NSWorkspace.shared.runningApplications where app.activationPolicy != .prohibited {
      if app.bundleIdentifier == currentBundleId { continue }
      let element = AXUIElementCreateApplication(app.processIdentifier)
      var value: CFTypeRef?
      guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
            let windows = value as? [AXUIElement] else { continue }
      for (index, window) in windows.enumerated() {
        var titleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
        let title = titleValue as? String ?? "Untitled window"
        output.append([
          "id": "desktop-\(app.processIdentifier)-\(index)-\(fingerprint(title))",
          "pid": app.processIdentifier,
          "name": app.localizedName ?? "Unknown app",
          "title": title,
          "bundleId": app.bundleIdentifier ?? "",
          "kind": "desktop"
        ])
      }
    }
    return output
  }

  private func findWindow(_ id: String) -> (NSRunningApplication, AXUIElement)? {
    let parts = id.split(separator: "-")
    guard parts.count >= 4,
          let pidNumber = Int32(parts[1]),
          let index = Int(parts[2]),
          let expectedFingerprint = UInt64(parts[3], radix: 16) else { return nil }
    let pid = pid_t(pidNumber)
    guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
    let element = AXUIElementCreateApplication(pid)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
          let windows = value as? [AXUIElement], windows.indices.contains(index) else { return nil }
    let window = windows[index]
    var titleValue: CFTypeRef?
    AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
    let title = titleValue as? String ?? "Untitled window"
    guard fingerprint(title) == expectedFingerprint else { return nil }
    return (app, window)
  }

  private func inspect(window: AXUIElement, id: String) -> [String: Any] {
    func attribute(_ key: String) -> String {
      var value: CFTypeRef?
      guard AXUIElementCopyAttributeValue(window, key as CFString, &value) == .success,
            let value else { return "" }
      return String(describing: value)
    }
    return [
      "id": id,
      "title": attribute(kAXTitleAttribute),
      "role": attribute(kAXRoleAttribute),
      "description": attribute(kAXDescriptionAttribute),
      "value": attribute(kAXValueAttribute)
    ]
  }

  private func capture(window: AXUIElement, pid: pid_t, id: String) -> CGImage? {
    var titleValue: CFTypeRef?
    AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
    let title = titleValue as? String ?? ""
    guard let infos = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else { return nil }
    let matches = infos.filter { info in
      (info[kCGWindowOwnerPID as String] as? Int32) == Int32(pid)
    }
    let titled = matches.first { ($0[kCGWindowName as String] as? String) == title && !title.isEmpty }
    let selected = titled ?? matches.first
    guard let number = selected?[kCGWindowNumber as String] as? UInt32 else { return nil }
    return CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(number), [.bestResolution, .boundsIgnoreFraming])
  }

  private func focusedElement(app: NSRunningApplication, targetWindow: AXUIElement) -> AXUIElement? {
    let application = AXUIElementCreateApplication(app.processIdentifier)
    var focusedWindowValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &focusedWindowValue) == .success,
          let focusedWindow = focusedWindowValue,
          CFEqual(focusedWindow, targetWindow) else { return nil }
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &value) == .success else { return nil }
    guard let value else { return nil }
    return value as! AXUIElement
  }

  private func fingerprint(_ value: String) -> UInt64 {
    // FNV-1a gives us a stable, dependency-free identity across launches.
    var hash: UInt64 = 14695981039346656037
    for byte in value.utf8 {
      hash ^= UInt64(byte)
      hash = hash &* 1099511628211
    }
    return hash
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

  private func setupGlobalShortcut() {
    let matches: (NSEvent) -> Bool = { event in
      event.keyCode == 49 && event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.option)
    }
    globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
      if matches(event) { self?.togglePanel() }
    }
    localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      if matches(event) { self?.togglePanel(); return nil }
      if event.keyCode == 53 {
        NSApp.windows.first?.orderOut(nil)
        return nil
      }
      return event
    }
  }

  @objc private func togglePanel() {
    guard let panel = NSApp.windows.first else { return }
    if panel.isVisible {
      panel.orderOut(nil)
    } else {
      panel.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: false)
    }
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

  private func restoreOverlaySettings() {
    let defaults = UserDefaults.standard
    let opacity = defaults.object(forKey: "bridge.opacity") as? Double ?? 1.0
    NSApp.windows.first?.alphaValue = min(max(opacity, 0.2), 1.0)
    NSApp.windows.first?.ignoresMouseEvents = defaults.bool(forKey: "bridge.clickThrough")
  }

  private func rememberSecurityScopedDirectory(_ url: URL) {
    securityScopedDirectory?.stopAccessingSecurityScopedResource()
    _ = url.startAccessingSecurityScopedResource()
    securityScopedDirectory = url
    do {
      let bookmark = try url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      UserDefaults.standard.set(bookmark, forKey: "bridge.terminalBookmark")
    } catch {
      UserDefaults.standard.removeObject(forKey: "bridge.terminalBookmark")
    }
  }

  private func restoreSecurityScopedDirectory() {
    guard let bookmark = UserDefaults.standard.data(forKey: "bridge.terminalBookmark") else {
      return
    }
    var stale = false
    do {
      let url = try URL(
        resolvingBookmarkData: bookmark,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &stale
      )
      if stale {
        rememberSecurityScopedDirectory(url)
      } else {
        _ = url.startAccessingSecurityScopedResource()
        securityScopedDirectory = url
      }
    } catch {
      UserDefaults.standard.removeObject(forKey: "bridge.terminalBookmark")
    }
  }
}
