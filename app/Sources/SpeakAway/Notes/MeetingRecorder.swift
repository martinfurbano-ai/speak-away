import Foundation
import SpeakAwayCore

/// Records a meeting without a bot: the microphone is "Yo", the other apps' audio is "Ellos".
///
/// Each track is cut into chunks of about 20 s at pauses (`Chunker`), silent chunks are dropped
/// (`SpeechGate`), and the rest go one at a time through the injected `transcribe` closure, so only one
/// Whisper call runs at once. Lines appear in `lines` as soon as each chunk is done and are also appended to
/// `live.ndjson`, so a crash loses at most the chunk in flight. Audio lives only in memory and is never written.
///
/// Needs: microphone permission (already used by dictation), plus the system audio permission described
/// in `SystemAudioTap`. If the system audio cannot start, the meeting still records the mic and
/// `systemAudio` says why.
@MainActor
final class MeetingRecorder: ObservableObject {
    typealias Transcribe = ([Float]) async throws -> String

    enum SystemAudioStatus: Equatable {
        case idle
        /// Capturing; the associated value is the backend name ("coreAudioTap" or "screenCaptureKit").
        case capturing(String)
        /// Capturing but nothing audible for 30 s: either nobody spoke or the permission was denied.
        case noSoundYet
        case unavailable(String)
    }

    enum Failure: LocalizedError {
        case alreadyRecording
        case microphone(String)
        var errorDescription: String? {
            switch self {
            case .alreadyRecording: return "Ya hay una reunión grabándose."
            case let .microphone(detail): return "No se pudo abrir el micrófono: \(detail)"
            }
        }
    }

    @Published private(set) var lines: [TranscriptLine] = []
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var systemAudio: SystemAudioStatus = .idle
    /// The last problem worth telling the person (a failed transcription, a failed save). Nil when all is well.
    @Published private(set) var lastError: String?

    let store: NotesStore
    private let transcribe: Transcribe
    private let chunker: Chunker

    private struct Session {
        let id: UUID
        let title: String
        let app: String
        let startedAt: Date
        let mic: TrackBuffer
        let system: TrackBuffer
    }

    private struct Job {
        let speaker: Speaker
        let chunk: TrackBuffer.Chunk
    }

    private var session: Session?
    private var micCapture: MicCapture?
    private var systemTap: SystemAudioTap?
    private var ticker: Task<Void, Never>?
    private var worker: Task<Void, Never>?
    private var jobs: AsyncStream<Job>.Continuation?
    private var liveHandle: FileHandle?

    init(transcribe: @escaping Transcribe, store: NotesStore = NotesStore(), chunker: Chunker = Chunker()) {
        self.transcribe = transcribe
        self.store = store
        self.chunker = chunker
    }

    // MARK: Start

    func start(title: String, app: String) async throws {
        guard !isRecording else { throw Failure.alreadyRecording }
        let startedAt = Date()
        let mic = TrackBuffer(meetingStart: startedAt, chunker: chunker)
        let system = TrackBuffer(meetingStart: startedAt, chunker: chunker)
        let current = Session(id: UUID(), title: title, app: app, startedAt: startedAt, mic: mic, system: system)

        let micCapture = MicCapture { samples in mic.append(samples, at: Date()) }
        do { try micCapture.start() } catch { throw Failure.microphone(error.localizedDescription) }

        lines = []
        elapsed = 0
        lastError = nil
        systemAudio = .idle
        session = current
        self.micCapture = micCapture
        openLiveFile()

        let (stream, continuation) = AsyncStream<Job>.makeStream()
        jobs = continuation
        worker = Task { [weak self] in
            for await job in stream { await self?.process(job) }
        }
        isRecording = true
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self?.tick()
            }
        }

        let tap = SystemAudioTap { samples in system.append(samples, at: Date()) }
        do {
            try await tap.start()
            systemTap = tap
            systemAudio = .capturing(tap.backend?.rawValue ?? "")
        } catch {
            systemAudio = .unavailable(error.localizedDescription)
        }
    }

    // MARK: Stop

    /// Stops both tracks, transcribes what is left, saves the note and returns it. Never throws: a failed
    /// save is reported in `lastError` and the meeting is still returned.
    func stop() async -> Meeting {
        guard let current = session else {
            let now = Date()
            return Meeting(title: "", app: "", startedAt: now, endedAt: now, lines: [])
        }
        isRecording = false
        ticker?.cancel()
        ticker = nil
        micCapture?.stop()
        micCapture = nil
        systemTap?.stop()
        systemTap = nil
        let endedAt = Date()
        elapsed = endedAt.timeIntervalSince(current.startedAt)

        enqueue(current.mic.takeChunks(flush: true), speaker: .me)
        enqueue(current.system.takeChunks(flush: true), speaker: .them)
        jobs?.finish()
        jobs = nil
        await worker?.value
        worker = nil
        closeLiveFile()

        let meeting = Meeting(id: current.id, title: current.title, app: current.app, startedAt: current.startedAt, endedAt: endedAt, lines: lines)
        do {
            try store.save(meeting)
            try? FileManager.default.removeItem(at: store.liveFile)
        } catch {
            lastError = "No se pudo guardar la nota: \(error.localizedDescription). El texto sigue en live.ndjson."
        }
        session = nil
        systemAudio = .idle
        return meeting
    }

    // MARK: Pipeline

    private func tick() {
        guard let current = session, isRecording else { return }
        elapsed = Date().timeIntervalSince(current.startedAt)
        enqueue(current.mic.takeChunks(), speaker: .me)
        enqueue(current.system.takeChunks(), speaker: .them)
        if case .capturing = systemAudio, elapsed > 30, current.system.peak == 0 { systemAudio = .noSoundYet }
        if case .noSoundYet = systemAudio, current.system.peak > 0, let backend = systemTap?.backend { systemAudio = .capturing(backend.rawValue) }
    }

    private func enqueue(_ chunks: [TrackBuffer.Chunk], speaker: Speaker) {
        for chunk in chunks { jobs?.yield(Job(speaker: speaker, chunk: chunk)) }
    }

    private func process(_ job: Job) async {
        guard SpeechGate.check(job.chunk.audio, sampleRate: AudioResampler.sampleRate) == .speech else { return }
        do {
            let raw = try await transcribe(job.chunk.audio)
            let text = SpeechGate.clean(raw).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            let line = TranscriptLine(speaker: job.speaker, start: job.chunk.start, text: text)
            lines = (lines + [line]).sorted { $0.start < $1.start }
            appendLive(line)
        } catch {
            lastError = "Falló una transcripción: \(error.localizedDescription)"
        }
    }

    // MARK: Live file

    private func openLiveFile() {
        let fm = FileManager.default
        try? fm.createDirectory(at: store.folder, withIntermediateDirectories: true)
        fm.createFile(atPath: store.liveFile.path, contents: nil)
        liveHandle = try? FileHandle(forWritingTo: store.liveFile)
    }

    private func appendLive(_ line: TranscriptLine) {
        guard let liveHandle else { return }
        try? liveHandle.write(contentsOf: Data((Meeting.ndjsonLine(for: line) + "\n").utf8))
    }

    private func closeLiveFile() {
        try? liveHandle?.close()
        liveHandle = nil
    }
}
