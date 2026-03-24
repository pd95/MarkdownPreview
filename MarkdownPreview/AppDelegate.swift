import Cocoa

/// App delegate used to control macOS application behaviour.
/// The `applicationShouldTerminateAfterLastWindowClosed` method returns
/// `true` when the *Automatic Quit* mode is enabled. The mode can be
/// toggled by writing to the `exitAfterLastWindow`.
class AppDelegate: NSObject, NSApplicationDelegate {
    var exitAfterLastWindow: Bool = false
    
    // MARK: - NSApplicationDelegate
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return exitAfterLastWindow
    }
}
