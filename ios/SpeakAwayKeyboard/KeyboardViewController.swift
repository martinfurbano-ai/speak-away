import SwiftUI
import UIKit
import SpeakAwayCore

/// The Speak Away keyboard. For now it only hosts the placeholder key layout: the session
/// bridge, speech and Command Mode arrive in the next step.
final class KeyboardViewController: UIInputViewController {
    private let model = KeyboardModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        model.showsGlobe = needsInputModeSwitchKey
        model.insert = { [weak self] text in self?.textDocumentProxy.insertText(text) }
        model.deleteBackward = { [weak self] in self?.textDocumentProxy.deleteBackward() }
        model.nextKeyboard = { [weak self] in self?.advanceToNextInputMode() }
        refreshFieldKind()

        let host = UIHostingController(rootView: KeyboardView(model: model))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)

        let height = view.heightAnchor.constraint(equalToConstant: 260)
        height.priority = .defaultHigh
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            height,
        ])
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        refreshFieldKind()
    }

    /// Maps the current field to a writing-style category with the shared core.
    private func refreshFieldKind() {
        let keyboard = textDocumentProxy.keyboardType?.rawValue ?? UIKeyboardType.default.rawValue
        let content = textDocumentProxy.textContentType??.rawValue
        model.category = FieldKind.category(keyboardType: keyboard, contentType: content)
    }
}
