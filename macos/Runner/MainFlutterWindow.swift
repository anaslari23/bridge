import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSPanel {

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Overlay behaviour
    self.level = .floating
    self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    self.isMovableByWindowBackground = true
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.backgroundColor = NSColor.clear
    self.isOpaque = false
    self.hasShadow = true

    // Panel-specific: don't steal focus
    self.becomesKeyOnlyIfNeeded = true

    RegisterGeneratedPlugins(registry: flutterViewController)
    super.awakeFromNib()
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}
