import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayController: CompanionWindowController?
    private var typingMonitor: TypingActivityMonitor?
    private var hotKeyMonitor: GlobalHotKeyMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let overlayController = CompanionWindowController()
        overlayController.show()

        let typingMonitor = TypingActivityMonitor(
            onTyping: {
                overlayController.playTypingReaction()
            },
            onKeyboardAccessChanged: { hasKeyboardAccess in
                overlayController.setKeyboardAccessEnabled(hasKeyboardAccess)
            }
        )
        typingMonitor.start()

        let hotKeyMonitor = GlobalHotKeyMonitor {
            NSApp.terminate(nil)
        }
        hotKeyMonitor.start()

        self.overlayController = overlayController
        self.typingMonitor = typingMonitor
        self.hotKeyMonitor = hotKeyMonitor
    }

    func applicationWillTerminate(_ notification: Notification) {
        typingMonitor?.stop()
        hotKeyMonitor?.stop()
    }
}
