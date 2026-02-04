import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Set window size to iPhone 16 dimensions (393 x 852)
    let iPhone16Width: CGFloat = 393
    let iPhone16Height: CGFloat = 852

    // Center the window on screen
    if let screen = NSScreen.main {
      let screenFrame = screen.visibleFrame
      let x = (screenFrame.width - iPhone16Width) / 2 + screenFrame.origin.x
      let y = (screenFrame.height - iPhone16Height) / 2 + screenFrame.origin.y
      let newFrame = NSRect(x: x, y: y, width: iPhone16Width, height: iPhone16Height)
      self.setFrame(newFrame, display: true)
    }

    // Prevent resizing
    self.styleMask.remove(.resizable)
    self.minSize = NSSize(width: iPhone16Width, height: iPhone16Height)
    self.maxSize = NSSize(width: iPhone16Width, height: iPhone16Height)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
