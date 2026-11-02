import AppKit
import SpeakAwayCore
import SwiftUI

/// First-run window: grant three permissions while the model downloads.
struct WelcomeView: View {
    @ObservedObject var engine: Engine
    var onDone: () -> Void
    @State private var tick = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let accent = Color(red: 0.80, green: 0.21, blue: 0.23)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    // Typing dots, then the logo: something about to be said, then said.
                    TimelineView(.animation) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let phase: BubbleMotion.Phase = t.truncatingRemainder(dividingBy: 4) < 2.4 ? .thinking : .idle
                        BubbleView(bars: BubbleMotion.bars(phase, level: 0, time: t))
                    }
                    .frame(width: 44, height: 39)
                    Text("Speak Away").font(.system(size: 28, weight: .bold)).kerning(-0.6)
                }
                Text("Toca Fn dos veces, habla, y toca Fn otra vez. El texto aparece donde está tu cursor.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                ForEach(Permission.allCases, id: \.title) { permission in
                    row(icon: permission.granted ? "checkmark.circle.fill" : "circle",
                        done: permission.granted,
                        title: permission.title,
                        detail: permission.detail) {
                        if !permission.granted {
                            Button("Permitir") { permission.request() }
                        }
                    }
                }
                row(icon: engine.isReady ? "checkmark.circle.fill" : "arrow.down.circle",
                    done: engine.isReady,
                    title: "Modelo de voz",
                    detail: modelDetail) { EmptyView() }
            }
            .id(tick)

            Text("Si Fn abre los emojis: Ajustes del Sistema › Teclado › «Pulsar la tecla 🌐 para» › No hacer nada.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Link("Hecho por Martín Urbano · Open Source Everything", destination: Settings.instagram)
                    .font(.footnote)
                Spacer()
                if !Permission.allGranted {
                    Button("Reiniciar Speak Away") { Permission.relaunch() }
                        .help("Si ya diste el permiso y sigue sin marcarse, macOS lo aplica al reiniciar la app.")
                }
                Button(Permission.allGranted ? "Listo" : "Después") { onDone() }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
        }
        .padding(28)
        .frame(width: 500)
        .background(Theme.background)
        .onReceive(timer) { _ in tick += 1 }
    }

    private var modelDetail: String {
        switch engine.state {
        case .idle: return "Se descarga una sola vez y después funciona sin internet."
        case .downloading(let p): return "Descargando… \(Int(p * 100)) %"
        case .loading: return "Preparando el modelo para tu Mac (solo la primera vez, puede tardar unos minutos)."
        case .ready: return "Listo. Corre en tu Mac, sin internet."
        case .failed(let message): return "No se pudo cargar: \(message)"
        }
    }

    @ViewBuilder
    private func row<Accessory: View>(icon: String, done: Bool, title: String, detail: String,
                                      @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(done ? Color.green : accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            accessory()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
    }
}

final class WelcomeWindow: NSWindow {
    init(engine: Engine, onDone: @escaping () -> Void) {
        super.init(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        title = "Bienvenido a Speak Away"
        backgroundColor = Theme.backgroundNS
        isReleasedWhenClosed = false
        contentView = NSHostingView(rootView: WelcomeView(engine: engine, onDone: onDone))
        center()
    }
}
