import AppKit

/// Reads the text selected in the frontmost app for Command Mode, without the Accessibility API
/// (the app is sandboxed): Cmd+C, wait for the clipboard to change, read it, put the clipboard back.
/// Sending Cmd+C needs the same permission as pasting.
@MainActor
enum SelectionGrabber {
    /// The selected text, or nil when nothing was selected (the clipboard did not change).
    static func grab(timeout: TimeInterval = 0.6) async -> String? {
        let board = NSPasteboard.general
        let saved = ClipboardSnapshot.take(board)
        let before = board.changeCount

        sendCopy()

        let deadline = Date().addingTimeInterval(timeout)
        while board.changeCount == before, Date() < deadline {
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        let copied = board.changeCount != before
        let text = copied ? board.string(forType: .string) : nil

        if copied { saved.restore(to: board) }
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    private static func sendCopy() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let cKey: CGKeyCode = 8
        let down = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

/// A copy of everything on the clipboard, so it can be given back.
struct ClipboardSnapshot {
    private let items: [NSPasteboardItem]

    static func take(_ board: NSPasteboard) -> ClipboardSnapshot {
        ClipboardSnapshot(items: (board.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        })
    }

    func restore(to board: NSPasteboard) {
        board.clearContents()
        if !items.isEmpty { board.writeObjects(items) }
    }
}
