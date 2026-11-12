import AppKit
import SpeakAwayBrain
import SpeakAwayCore
import SwiftUI

/// Meeting notes state for the hub: the live recorder, saved notes and summaries.
@MainActor
final class MeetingsModel: ObservableObject {
    @Published private(set) var meetings: [Meeting] = []
    @Published var openID: UUID?
    @Published var summarizing: UUID?
    @Published var message: String?
    let recorder: MeetingRecorder
    let store: NotesStore

    init(recorder: MeetingRecorder, store: NotesStore = NotesStore()) {
        self.recorder = recorder
        self.store = store
        reload()
    }

    func reload() { meetings = store.list().sorted { $0.startedAt > $1.startedAt } }

    func start(app: String = "Reunión") {
        let title = "Reunión del " + Date().formatted(.dateTime.day().month(.wide).hour().minute())
        Task {
            do { try await recorder.start(title: title, app: app) } catch { message = error.localizedDescription }
        }
    }

    func stop() {
        Task {
            let meeting = await recorder.stop()
            reload()
            openID = meeting.id
            if let error = recorder.lastError { message = error }
        }
    }

    func summarize(_ meeting: Meeting) {
        guard LocalBrain.availability.isUsable else { message = LocalBrain.availability.message; return }
        summarizing = meeting.id
        Task {
            defer { summarizing = nil }
            do {
                let transcript = meeting.lines.map { "\($0.speaker == .me ? "Yo" : "Ellos"): \($0.text)" }.joined(separator: "\n")
                let summary = try await LocalBrain.summarize(transcript: transcript, language: nil)
                _ = try? store.save(meeting.withSummary(summary.markdown(english: false)))
                reload()
            } catch {
                message = "No se pudo resumir: \(error.localizedDescription)"
            }
        }
    }

    func delete(_ meeting: Meeting) {
        store.delete(meeting.id)
        if openID == meeting.id { openID = nil }
        reload()
    }

    /// For people without Apple Intelligence: the note, ready to paste into ChatGPT or Claude.
    func copyForChat(_ meeting: Meeting) {
        let prompt = "Resume esta reunión en: Resumen, Decisiones, Pendientes (quién, qué, cuándo) y Preguntas abiertas.\n\n" + meeting.markdown()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        message = "Copiado. Pégalo en ChatGPT o Claude."
    }
}

struct MeetingsPage: View {
    @ObservedObject var model: MeetingsModel
    @ObservedObject var recorder: MeetingRecorder

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let id = model.openID, let meeting = model.meetings.first(where: { $0.id == id }) {
                MeetingDetail(meeting: meeting, model: model)
            } else {
                PageHeader(title: "Reuniones", subtitle: "Sin bot. Tu micrófono es «Yo» y el audio de la llamada es «Ellos». Todo se transcribe en tu Mac.")
                recorderCard
                if let message = model.message { Text(message).font(.system(size: 12)).foregroundStyle(.secondary) }
                if model.meetings.isEmpty {
                    EmptyState(icon: "person.2.wave.2", title: "Todavía no hay notas",
                               detail: "Cuando entres a Zoom, Meet, Teams o FaceTime te pregunto si tomo notas.")
                } else {
                    Text("Notas").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                    VStack(spacing: 0) {
                        ForEach(model.meetings) { m in
                            Button { model.openID = m.id } label: { meetingRow(m) }.buttonStyle(.plain)
                            if m.id != model.meetings.last?.id { Divider().padding(.leading, 16) }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
                }
            }
        }
        .padding(28)
    }

    private var recorderCard: some View {
        Card {
            if recorder.isRecording {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        TimelineView(.animation) { t in
                            Circle().fill(Theme.accent).frame(width: 10, height: 10)
                                .opacity(0.45 + 0.55 * abs(sin(t.date.timeIntervalSinceReferenceDate * 2.4)))
                        }
                        .frame(width: 10, height: 10)
                        Text("Tomando notas").font(.system(size: 15, weight: .semibold))
                        Text(Meeting.clock(recorder.elapsed)).font(.system(size: 13, design: .monospaced)).foregroundStyle(.secondary)
                        Spacer()
                        Button { model.stop() } label: { Label("Terminar", systemImage: "stop.fill") }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                    }
                    audioNote
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(recorder.lines.suffix(6)) { TranscriptBubble(line: $0) }
                        if recorder.lines.isEmpty {
                            Text("Escuchando… las primeras líneas aparecen en unos 20 segundos.").font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                HStack(spacing: 14) {
                    BubbleView(bars: BubbleMotion.bars(.idle, level: 0, time: 0)).frame(width: 40, height: 35)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("¿Estás en una llamada?").font(.system(size: 15, weight: .semibold))
                        Text("Empieza ahora o espera a que te lo pregunte.").font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { model.start() } label: { Label("Tomar notas", systemImage: "record.circle") }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                }
            }
        }
    }

    @ViewBuilder private var audioNote: some View {
        switch recorder.systemAudio {
        case .noSoundYet:
            Label("No oigo la llamada. Revisa Ajustes del Sistema › Privacidad › Grabación de audio del sistema.", systemImage: "exclamationmark.triangle")
                .font(.system(size: 12)).foregroundStyle(.orange)
        case .unavailable(let why):
            Label("Solo tu micrófono: \(why)", systemImage: "exclamationmark.triangle").font(.system(size: 12)).foregroundStyle(.orange)
        default: EmptyView()
        }
    }

    private func meetingRow(_ m: Meeting) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.accent.opacity(0.12)).frame(width: 38, height: 38)
                Image(systemName: m.summary == nil ? "waveform" : "sparkles").foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(m.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Text("\(m.app) · \(m.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(Int(m.duration / 60)) min")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

/// One line of the transcript as a chat bubble: yours on the right in red, theirs on the left.
struct TranscriptBubble: View {
    let line: TranscriptLine
    var body: some View {
        let mine = line.speaker == .me
        HStack(alignment: .bottom) {
            if mine { Spacer(minLength: 60) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                Text("\(mine ? "Yo" : "Ellos") · \(Meeting.clock(line.start))").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                Text(line.text)
                    .font(.system(size: 14))
                    .foregroundStyle(mine ? .white : .primary)
                    .padding(.horizontal, 13).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(mine ? Theme.accent : Theme.empty))
                    .textSelection(.enabled)
            }
            if !mine { Spacer(minLength: 60) }
        }
    }
}

struct MeetingDetail: View {
    let meeting: Meeting
    @ObservedObject var model: MeetingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button { model.openID = nil } label: { Label("Reuniones", systemImage: "chevron.left") }
                .buttonStyle(.borderless).foregroundStyle(.secondary)
            PageHeader(title: meeting.title, subtitle: "\(meeting.app) · \(meeting.startedAt.formatted(date: .long, time: .shortened)) · \(Int(meeting.duration / 60)) min")
            HStack(spacing: 10) {
                Button { model.summarize(meeting) } label: {
                    Label(model.summarizing == meeting.id ? "Resumiendo…" : (meeting.summary == nil ? "Resumir" : "Resumir otra vez"), systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent).disabled(model.summarizing != nil)
                Button { model.copyForChat(meeting) } label: { Label("Copiar para ChatGPT", systemImage: "doc.on.doc") }
                Spacer()
                Button(role: .destructive) { model.delete(meeting) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
            }
            if let message = model.message { Text(message).font(.system(size: 12)).foregroundStyle(.secondary) }
            if let summary = meeting.summary {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Resumen", systemImage: "sparkles").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.accent)
                        Text(LocalizedStringKey(summary)).font(.system(size: 14)).textSelection(.enabled)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(meeting.lines) { TranscriptBubble(line: $0) }
            }
        }
    }
}

/// The small floating question when a call starts: "¿Tomo notas de Zoom?".
final class MeetingPromptPanel: NSPanel {
    init(app: String, onYes: @escaping () -> Void, onNo: @escaping () -> Void) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 380, height: 76), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = NSHostingView(rootView: MeetingPromptView(app: app, onYes: onYes, onNo: onNo))
    }

    func show() {
        guard let area = NSScreen.main?.visibleFrame else { return }
        setFrameOrigin(NSPoint(x: area.maxX - frame.width - 16, y: area.maxY - frame.height - 12))
        orderFrontRegardless()
    }
}

private struct MeetingPromptView: View {
    let app: String
    let onYes: () -> Void
    let onNo: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            BubbleView(bars: BubbleMotion.bars(.idle, level: 0, time: 0)).frame(width: 30, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text("¿Tomo notas?").font(.system(size: 13, weight: .semibold))
                Text("Estás en \(app)").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button("No", action: onNo).buttonStyle(.borderless)
            Button("Tomar notas", action: onYes).buttonStyle(.borderedProminent).tint(Theme.accent)
        }
        .padding(.horizontal, 14)
        .frame(width: 380, height: 64)
        .modifier(GlassCapsule())
        .padding(6)
    }
}

/// Liquid Glass on macOS 26, a frosted material before that.
struct GlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}
