import AppKit
import SpeakAwayCore

/// `SpeakAway --preview-home out` writes out-light.png and out-dark.png of the home window with sample numbers.
/// Used to check the design without dictating for weeks.
@MainActor
enum Preview {
    static func home(to base: String) -> Never {
        _ = NSApplication.shared
        let today = DayKey(Date())
        var stats = UsageStats()
        for back in 0..<140 where back < 6 || (back % 3 != 0 && back % 7 != 5) {
            let words = 120 + (back * 37) % 900
            stats = stats.recording(words: words, seconds: Double(words) / 2.4, on: today.adding(-back))
        }
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("speakaway-preview-\(UUID().uuidString)")
        let history = HistoryStore(folder: temp, defaults: UserDefaults(suiteName: "speakaway-preview")!)
        let samples: [(String, String, Double)] = [
            ("Hola Carla, te mando la cotización hoy antes de las 5. El martes te llamo para revisarla juntos.", "Mail", -600),
            ("dale, nos vemos a las 3 en la oficina", "WhatsApp", -3_000),
            ("Pendientes de la semana: cerrar la propuesta del cliente, revisar el diseño del sitio y llamar al banco.", "Notas", -90_000),
            ("Thanks for the call today. I'll send the summary and next steps by Friday.", "Slack", -95_000),
        ]
        for (text, app, ago) in samples { history.add(text: text, raw: text, app: app, date: Date().addingTimeInterval(ago)) }
        let pad = ScratchpadStore(folder: temp.appendingPathComponent("Notes"))
        pad.add("Ideas para el video de Speak Away\n\nAbrir con la pregunta: ¿cuánto pagas al año por dictar? Mostrar Fn Fn en WhatsApp y cerrar con el link.")
        pad.add("Lista del súper: café, avena, limones")
        let dict = ObservableJSONStore(file: temp.appendingPathComponent("d.json"), default: PersonalDictionary(entries: [
            DictionaryEntry(word: "Speak Away", replacing: ["spik away", "speakaway"]), DictionaryEntry(word: "WhisperKit"),
            DictionaryEntry(word: "Open Source Everything"), DictionaryEntry(word: "Panamá Pacífico", replacing: ["panama pacifico"]),
        ]))
        let snips = ObservableJSONStore(file: temp.appendingPathComponent("s.json"), default: Snippets(items: [
            Snippet(trigger: "mi link de calendario", expansion: "Agenda una llamada conmigo aquí: cal.com/tu-nombre/30min"),
            Snippet(trigger: "mi dirección", expansion: "Calle 50, Edificio Global, piso 12, Ciudad de Panamá"),
        ]))
        let styles = ObservableJSONStore(file: temp.appendingPathComponent("st.json"), default: StyleSettings())
        let store = NotesStore(folder: temp.appendingPathComponent("Meetings"))
        let start = Date().addingTimeInterval(-7_200)
        _ = try? store.save(Meeting(title: "Llamada con el equipo de diseño", app: "Zoom", startedAt: start, endedAt: start.addingTimeInterval(1_860), lines: [
            TranscriptLine(speaker: .them, start: 4, text: "¿Ya viste la nueva versión del logo?"),
            TranscriptLine(speaker: .me, start: 9, text: "Sí, me encanta la burbuja. Solo cambiaría el rojo por uno un poco más cálido."),
            TranscriptLine(speaker: .them, start: 17, text: "Perfecto, lo ajusto hoy y te lo mando antes de las 5."),
        ], summary: "**Resumen.** Se aprobó el logo con un rojo más cálido.\n\n**Pendientes.** Ajustar el color y enviarlo hoy antes de las 5."))
        let meetings = MeetingsModel(recorder: MeetingRecorder { _ in "" }, store: store)
        let window = HubWindow(stores: HubStores(stats: StatsStore(preview: stats), history: history, scratchpad: pad, dictionary: dict,
                                                 snippets: snips, styles: styles, meetings: meetings), engine: Engine(), previewReady: true)
        if ProcessInfo.processInfo.environment["OPEN"] == "1" { meetings.openID = meetings.meetings.first?.id }
        if let s = ProcessInfo.processInfo.environment["SECTION"], let section = HubSection(rawValue: s) { window.model.section = section }
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            window.appearance = NSAppearance(named: appearance)
            window.center()
            window.orderFrontRegardless()
            RunLoop.main.run(until: Date().addingTimeInterval(1.5))
            // Real window capture: offscreen caching misses the Liquid Glass layers.
            let shot = Process()
            shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            shot.arguments = ["-x", "-o", "-l", String(window.windowNumber), "\(base)-\(name).png"]
            try? shot.run()
            shot.waitUntilExit()
        }
        window.orderOut(nil)
        exit(0)
    }
}
