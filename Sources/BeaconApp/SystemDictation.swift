import AppKit

/// Waits for SwiftUI to establish the text responder before starting native
/// Dictation. Opening a sheet and sending the action synchronously races focus.
enum SystemDictation {
    @MainActor
    static func start() async -> Bool {
        let action = Selector(("startDictation:"))
        NSApp.activate(ignoringOtherApps: true)
        // A sheet may still be attaching to its window after onAppear.
        for _ in 0..<20 {
            guard !Task.isCancelled else { return false }
            if NSApp.isActive, let window = NSApp.keyWindow,
               let editor = window.firstResponder as? NSTextView,
               editor.isEditable {
                // Give the focused field one complete UI update before routing
                // the action. Never send dictation to an unfocused window.
                await Task.yield()
                guard window.isKeyWindow, window.firstResponder === editor else { continue }
                editor.inputContext?.activate()
                // Use the actual Edit-menu command target when available:
                // the system owns this action and its input-method context.
                if let command = dictationCommand(in: NSApp.mainMenu, action: action) {
                    return NSApp.sendAction(action, to: command.target, from: command)
                }
                return NSApp.sendAction(action, to: nil, from: editor)
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return false
    }

    @MainActor
    private static func dictationCommand(in menu: NSMenu?, action: Selector) -> NSMenuItem? {
        for item in menu?.items ?? [] {
            if item.action == action { return item }
            if let found = dictationCommand(in: item.submenu, action: action) { return found }
        }
        return nil
    }

    static let hint = "Dictation couldn’t start. Enable it in System Settings → Keyboard → Dictation, then try again or use your Mac’s Dictation key."
}
