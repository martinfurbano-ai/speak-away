import SwiftUI
import UIKit
import SpeakAwayCore

/// The Speak Away keyboard: hosts the SwiftUI keys and gives the model the text field and the system's own keys.
final class KeyboardViewController: UIInputViewController, KeyboardHost {
    private var model: KeyboardModel?
    private var heightConstraint: NSLayoutConstraint?

    // MARK: KeyboardHost

    var proxy: UITextDocumentProxy { textDocumentProxy }
    var needsGlobeKey: Bool { needsInputModeSwitchKey }

    /// Opens the app. A keyboard cannot reach `UIApplication.shared`, but the application object is at the end of the
    /// responder chain, and its `openURL:options:completionHandler:` can be called through the runtime. This only runs
    /// from a tap on a key, which is what the system requires.
    func open(_ url: URL) {
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                let selector = NSSelectorFromString("openURL:options:completionHandler:")
                guard application.responds(to: selector) else { return }
                typealias Open = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, AnyObject?) -> Void
                let open = unsafeBitCast(application.method(for: selector), to: Open.self)
                open(application, selector, url as NSURL, NSDictionary(), nil)
                return
            }
            responder = current.next
        }
    }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        let model = KeyboardModel(host: self)
        self.model = model

        let hosting = UIHostingController(rootView: KeyboardView(model: model, inputController: self))
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        // About the height of the system keyboard; a little less in landscape.
        let height = view.heightAnchor.constraint(equalToConstant: Self.height(for: traitCollection))
        height.priority = .defaultHigh
        heightConstraint = height
        registerForTraitChanges([UITraitVerticalSizeClass.self]) { (controller: KeyboardViewController, _) in
            controller.heightConstraint?.constant = Self.height(for: controller.traitCollection)
        }
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            height,
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        model?.start()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        model?.stop()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        model?.fieldChanged()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        model?.fieldChanged()
    }

    private static func height(for traits: UITraitCollection) -> CGFloat {
        traits.verticalSizeClass == .compact ? 200 : 262
    }
}
