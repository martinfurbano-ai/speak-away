import Combine
import Foundation
import SpeakAwayCore

/// Dictating into a note from inside the app. It uses the app's own session: it starts one when none is running,
/// asks for a dictation, and when the text is ready it goes at the end of the note. The keyboard is not involved,
/// and it is told the result was taken so it never inserts it a second time.
@MainActor
final class NoteDictation: ObservableObject {
    enum Phase: Equatable {
        case idle
        /// The session is starting or the model is getting ready.
        case starting
        case listening
        /// Recorded, and being written down.
        case writing
    }

    @Published private(set) var phase: Phase = .idle
    /// Why the last try did not work, in the language of the phone. Cleared by the next try.
    @Published private(set) var message: String?
    /// The message is fixed in the Settings app.
    @Published private(set) var messageNeedsSettings = false

    private let session: SessionController
    private let store: PhoneStore
    private var noteID: UUID?
    private var follow: AnyCancellable?

    init(session: SessionController, store: PhoneStore) {
        self.session = session
        self.store = store
        follow = session.$state.sink { [weak self] state in
            // `$state` fires before the value is stored: look at it one turn later.
            Task { @MainActor in self?.sessionChanged(state) }
        }
    }

    var isBusy: Bool { phase != .idle }

    /// The dictate button of a note: start, or stop and write.
    func toggle(note id: UUID) {
        switch phase {
        case .idle:
            Task { await begin(note: id) }
        case .listening:
            phase = .writing
            session.perform(.finish, field: .general)
        case .starting, .writing:
            break
        }
    }

    /// The note was closed while listening: throw the recording away.
    func cancelIfListening() {
        guard phase == .listening else { return }
        session.perform(.cancel, field: .general)
        phase = .idle
    }

    func clearMessage() {
        message = nil
        messageNeedsSettings = false
    }

    private func begin(note id: UUID) async {
        noteID = id
        clearMessage()
        phase = .starting
        if !session.live { await session.startSession() }
        guard session.live else {
            phase = .idle
            message = session.problem
            messageNeedsSettings = session.problemNeedsSettings
            return
        }
        session.perform(.beginDictation, field: .general)
    }

    private func sessionChanged(_ state: SessionState) {
        guard phase != .idle else { return }
        switch state {
        case .recording:
            phase = .listening
        case .transcribing:
            phase = .writing
        case .done(let id, let text):
            if let noteID { store.appendToNote(noteID, dictation: text) }
            session.consumeResult(id)
            phase = .idle
        case .failed(let reason):
            message = reason
            messageNeedsSettings = session.problemNeedsSettings
            phase = .idle
        case .meeting:
            // A meeting took the microphone: the dictation was dropped.
            message = String(localized: "A meeting is being recorded. Dictation is back when it ends.")
            messageNeedsSettings = false
            phase = .idle
        case .ready, .idle:
            // Back to ready with no text: the recording was empty or was cancelled.
            if phase == .listening || phase == .writing { phase = .idle }
        }
    }
}
