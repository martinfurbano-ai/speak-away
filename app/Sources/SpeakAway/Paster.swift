import AppKit

/// Puts the text where the cursor is: clipboard + Cmd+V, then gives the clipboard back.
/// Needs Accessibility permission to send Cmd+V.
enum Paster {
    static func paste(_ text: String) {
        let board = NSPasteboard.general
        let saved: [NSPasteboardItem] = (board.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }

        board.clearContents()
        board.setString(text, forType: .string)
        let ours = board.changeCount

        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        // Restore what was on the clipboard, unless the user copied something new meanwhile.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard board.changeCount == ours, !saved.isEmpty else { return }
            board.clearContents()
            board.writeObjects(saved)
        }
    }
}
