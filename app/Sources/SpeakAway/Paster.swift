import AppKit
import SpeakAwayCore

/// Puts the text where the cursor is: clipboard + Cmd+V, then gives the user's clipboard back.
/// Needs Accessibility permission to send Cmd+V. The rules for what comes back live in `ClipboardKeeper`.
@MainActor
enum Paster {
    /// The last clipboard that belonged to the user, kept while one of our dictations sits on the clipboard.
    private static var userClipboard: ClipboardSnapshot?
    /// The pending give-back of the previous paste; a new paste replaces it.
    private static var pendingRestore: DispatchWorkItem?

    /// `send` false (no Accessibility) only leaves the text on the clipboard, unmarked, for a manual Cmd+V.
    static func paste(_ text: String, send: Bool = true) {
        let board = NSPasteboard.general
        pendingRestore?.cancel()
        pendingRestore = nil

        let currentIsOurs = ClipboardKeeper.isOurs(types: (board.types ?? []).map(\.rawValue))
        let user = ClipboardKeeper.userClipboard(current: ClipboardSnapshot.take(board),
                                                 currentIsOurs: currentIsOurs, remembered: userClipboard)
        guard send else {
            userClipboard = nil
            board.clearContents()
            board.setString(text, forType: .string)
            return
        }
        userClipboard = user

        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        for type in ClipboardKeeper.markerTypes {
            item.setData(Data(), forType: NSPasteboard.PasteboardType(type))
        }
        board.clearContents()
        board.writeObjects([item])
        let ours = board.changeCount
        DebugLog.write("paste \(text.count) chars, clipboard \(ours)\(currentIsOurs ? ", was ours" : "")")

        sendCommandV()

        let restore = DispatchWorkItem {
            guard ClipboardKeeper.mayRestore(changeCountNow: board.changeCount, ours: ours) else {
                DebugLog.write("restore skipped, clipboard changed")
                userClipboard = nil
                return
            }
            guard let user else { return }
            user.restore(to: board)
            userClipboard = nil
            DebugLog.write("clipboard given back")
        }
        pendingRestore = restore
        DispatchQueue.main.asyncAfter(deadline: .now() + ClipboardKeeper.restoreDelay, execute: restore)
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        // Only Command: a Control or Fn still held from the dictation must not turn this into another shortcut.
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
