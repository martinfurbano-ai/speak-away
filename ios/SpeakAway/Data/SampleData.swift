import Foundation
import SpeakAwayCore

/// A fictional account for the preview screens and the store screenshots: Carla Ruiz and her team, a six day streak,
/// a few dictations, words for the dictionary, shortcuts, notes and one meeting. Nothing here is a real person or client.
enum SampleData {
    struct Facts {
        let meetingID: UUID
        let noteID: UUID
    }

    static let meetingID = UUID(uuidString: "5A5A0001-0000-4000-8000-000000000001")!
    static let noteID = UUID(uuidString: "5A5A0002-0000-4000-8000-000000000002")!

    /// Writes the sample files into `folder` (the preview's own temporary folder, never the real one).
    @discardableResult
    static func write(into folder: URL, now: Date = Date(), spanish: Bool = UILanguage.isSpanish,
                      calendar: Calendar = .current) -> Facts {
        let stores = SharedStores(folder: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        try? stores.save(PhoneSettings())
        try? stores.save(stats(now: now, calendar: calendar))
        try? stores.save(history(now: now, spanish: spanish, calendar: calendar))
        try? stores.save(dictionary())
        try? stores.save(snippets(spanish: spanish))

        let notesFolder = ScratchNotesFolder(directory: folder.appendingPathComponent(SharedFiles.notesFolder, isDirectory: true))
        for note in notes(now: now, spanish: spanish) { try? notesFolder.save(note) }

        let meetingStore = NotesStore(folder: folder.appendingPathComponent("Meetings", isDirectory: true))
        _ = try? meetingStore.save(meeting(now: now, spanish: spanish, calendar: calendar))

        return Facts(meetingID: meetingID, noteID: noteID)
    }

    // MARK: Microphones

    /// The inputs the Settings picker shows in the preview screens, instead of whatever the Mac or the simulator has.
    static let microphones = [
        MicrophoneChoice(uid: "preview-iphone", name: "iPhone"),
        MicrophoneChoice(uid: "preview-airpods", name: "AirPods Pro"),
    ]

    // MARK: Numbers

    /// 16 weeks of activity that end in a six day streak, the longest so far, and about 31 thousand words.
    static func stats(now: Date, calendar: Calendar) -> UsageStats {
        let today = DayKey(now, calendar: calendar)
        var result = UsageStats()
        for back in 0..<112 where isActive(daysBack: back) {
            let day = today.adding(-back)
            let words = 120 + ((back * 53) % 17) * 33
            let parts = 3 + back % 3
            for _ in 0..<parts {
                result = result.recording(words: words / parts, seconds: Double(words / parts) * 60 / 142, on: day)
            }
        }
        return result
    }

    /// The last six days are all active; before that, two quiet days a week, so no older run beats the current one.
    private static func isActive(daysBack back: Int) -> Bool {
        if back <= 5 { return true }
        if back == 6 { return false }
        return back % 7 != 6 && back % 7 != 3
    }

    // MARK: History

    private static func history(now: Date, spanish: Bool, calendar: Calendar) -> [HistoryItem] {
        let texts = spanish ? spanishDictations : englishDictations
        let startOfToday = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        let earlier = calendar.date(byAdding: .day, value: -3, to: startOfToday) ?? startOfToday

        func today(_ minutesAgo: Double) -> Date { max(startOfToday.addingTimeInterval(120), now.addingTimeInterval(-minutesAgo * 60)) }
        func on(_ day: Date, hour: Double) -> Date { day.addingTimeInterval(hour * 3600) }

        let dates: [Date] = [today(6), today(48), today(110), on(yesterday, hour: 18.2), on(yesterday, hour: 12.6),
                             on(yesterday, hour: 9.4), on(earlier, hour: 17.0), on(earlier, hour: 10.3)]
        return zip(dates, texts).map { date, text in HistoryItem(date: date, text: text, raw: text, app: nil) }
    }

    private static let spanishDictations = [
        "Hola Carla, te confirmo la reunión de mañana a las diez. Te mando el link del calendario en un momento.",
        "Recuérdame llamar al proveedor de las cajas antes del mediodía y pedirle el presupuesto actualizado.",
        "Gracias por la propuesta. La revisamos en equipo esta semana y te respondemos el viernes.",
        "Nota para el lunes: preparar la presentación del trimestre y reservar la sala grande.",
        "Perfecto, nos vemos en la cafetería de siempre a las cinco.",
        "Buenos días, adjunto el informe de ventas de octubre. Cualquier duda me avisas.",
        "Compré pan, leche y fruta para la semana. Falta pasar por la farmacia.",
        "Quedamos en revisar los números el miércoles con Mateo Díaz y cerrar el plan de noviembre.",
    ]

    private static let englishDictations = [
        "Hi Carla, confirming tomorrow's meeting at ten. I'll send the calendar link in a moment.",
        "Remind me to call the box supplier before noon and ask for the updated quote.",
        "Thanks for the proposal. We'll review it as a team this week and get back to you on Friday.",
        "Note for Monday: prepare the quarterly presentation and book the big room.",
        "Perfect, see you at the usual café at five.",
        "Good morning, I'm attaching the October sales report. Let me know if you have any questions.",
        "Bought bread, milk and fruit for the week. Still need to stop by the pharmacy.",
        "We agreed to go over the numbers on Wednesday with Mateo Díaz and close the November plan.",
    ]

    // MARK: Voice

    private static func dictionary() -> PersonalDictionary {
        PersonalDictionary(entries: [
            DictionaryEntry(word: "Speak Away", replacing: ["speak a way", "espiquei"]),
            DictionaryEntry(word: "Carla Ruiz", replacing: ["carla rus"]),
            DictionaryEntry(word: "Mateo Díaz", replacing: ["mateo dias"]),
            DictionaryEntry(word: "Torre Azul", replacing: ["torre asul"]),
            DictionaryEntry(word: "Open Source Everything"),
        ])
    }

    private static func snippets(spanish: Bool) -> Snippets {
        if spanish {
            return Snippets(items: [
                Snippet(trigger: "mi link de calendario", expansion: "https://cal.example.com/carla-ruiz"),
                Snippet(trigger: "mi dirección", expansion: "Calle 50, Torre Azul, piso 4, Ciudad de Panamá"),
                Snippet(trigger: "gracias estándar", expansion: "Gracias por escribirnos. Te respondemos en menos de 24 horas."),
            ])
        }
        return Snippets(items: [
            Snippet(trigger: "my calendar link", expansion: "https://cal.example.com/carla-ruiz"),
            Snippet(trigger: "my address", expansion: "50th Street, Blue Tower, 4th floor, Panama City"),
            Snippet(trigger: "standard thanks", expansion: "Thanks for writing in. We'll get back to you within 24 hours."),
        ])
    }

    // MARK: Notes

    private static func notes(now: Date, spanish: Bool) -> [ScratchNote] {
        let texts = spanish
            ? ["Ideas para el lanzamiento\nUn video corto con tres escenas. Invitar a Mateo a probar la versión de prueba. Preparar el correo de bienvenida.",
               "Lista del súper\nPan, leche, fruta, café y jabón para los platos.",
               "Llamar a Carla\nPreguntarle por los horarios de la semana que viene."]
            : ["Launch ideas\nA short video with three scenes. Invite Mateo to try the test version. Prepare the welcome email.",
               "Grocery list\nBread, milk, fruit, coffee and dish soap.",
               "Call Carla\nAsk her about next week's schedule."]
        let ids = [noteID, UUID(uuidString: "5A5A0003-0000-4000-8000-000000000003")!, UUID(uuidString: "5A5A0004-0000-4000-8000-000000000004")!]
        return zip(ids, texts).enumerated().map { index, pair in
            let date = now.addingTimeInterval(-Double(index) * 7200 - 600)
            return ScratchNote(id: pair.0, created: date, updated: date, text: pair.1)
        }
    }

    // MARK: Recording

    /// A fictional meeting in progress: twelve minutes in, one pause behind it, and the engine's guess for the sentence
    /// being said now.
    static func recording(spanish: Bool) -> MeetingRecorder.Snapshot {
        let lines: [TranscriptLine]
        let guess: String
        if spanish {
            lines = [
                TranscriptLine(speaker: .room, start: 0, text: "Repasemos el calendario de las sesiones de fotos de diciembre. Tenemos dos sábados libres y el estudio está disponible el segundo."),
                TranscriptLine(speaker: .room, start: 38, text: "Mateo puede reservar el estudio hoy si confirmamos la fecha. Carla manda los primeros diseños antes del viernes."),
                TranscriptLine(speaker: .marker, start: 74, text: MeetingMarker.paused.text(english: false)),
                TranscriptLine(speaker: .marker, start: 74, text: MeetingMarker.resumed.text(english: false)),
                TranscriptLine(speaker: .room, start: 75, text: "De vuelta. El último punto abierto es quién se encarga de la entrega a la imprenta."),
            ]
            guess = "Laura, ¿puedes confirmar la fecha de entrega con la"
        } else {
            lines = [
                TranscriptLine(speaker: .room, start: 0, text: "Let's go over the photo shoot calendar for December. We have two Saturdays open and the studio is free on the second one."),
                TranscriptLine(speaker: .room, start: 38, text: "Mateo can book the studio today if we confirm the date. Carla is sending the first layouts before Friday."),
                TranscriptLine(speaker: .marker, start: 74, text: MeetingMarker.paused.text(english: true)),
                TranscriptLine(speaker: .marker, start: 74, text: MeetingMarker.resumed.text(english: true)),
                TranscriptLine(speaker: .room, start: 75, text: "Back. The last open point is who handles the delivery to the printer."),
            ]
            guess = "Laura, can you confirm the delivery date with the"
        }
        return MeetingRecorder.Snapshot(
            stage: .recording,
            title: spanish ? "Planificación del estudio" : "Studio planning",
            defaultTitle: spanish ? "Reunión 09:30" : "Meeting 09:30",
            transcript: LiveTranscript(lines: lines, volatile: guess),
            level: 0.55,
            elapsed: 754)
    }

    // MARK: Meeting

    private static func meeting(now: Date, spanish: Bool, calendar: Calendar) -> Meeting {
        let startOfToday = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        let start = yesterday.addingTimeInterval(10 * 3600)
        let lines: [TranscriptLine]
        let summary: MeetingSummary
        if spanish {
            lines = [
                TranscriptLine(speaker: .room, start: 0, text: "Buenos días a todos, empezamos con las novedades de la semana. Cerramos el contrato con el proveedor y ya tenemos la fecha de entrega."),
                TranscriptLine(speaker: .room, start: 41, text: "Perfecto. ¿Y el presupuesto de noviembre? Falta la aprobación de Mateo, la tendremos el miércoles."),
                TranscriptLine(speaker: .marker, start: 96, text: MeetingMarker.paused.text(english: false)),
                TranscriptLine(speaker: .marker, start: 96, text: MeetingMarker.resumed.text(english: false)),
                TranscriptLine(speaker: .room, start: 102, text: "Entonces el jueves lo revisamos todo y se lo enviamos a Carla. De acuerdo, yo preparo la presentación para ese día. Quedó claro, gracias a todos."),
            ]
            summary = MeetingSummary(
                summary: "El equipo cerró el contrato con el proveedor y confirmó la fecha de entrega. El presupuesto de noviembre espera la aprobación de Mateo.",
                decisions: ["Cerrar el contrato con el proveedor.", "Revisar todo el jueves y enviarlo a Carla."],
                actionItems: ["Mateo: aprobar el presupuesto de noviembre antes del miércoles.", "Equipo: preparar la presentación para el jueves."],
                questions: ["¿Se mantiene la fecha de entrega si la aprobación se retrasa?"])
        } else {
            lines = [
                TranscriptLine(speaker: .room, start: 0, text: "Good morning everyone, let's start with this week's news. We closed the contract with the supplier and we already have the delivery date."),
                TranscriptLine(speaker: .room, start: 41, text: "Perfect. And the November budget? We still need Mateo's approval, we'll have it on Wednesday."),
                TranscriptLine(speaker: .marker, start: 96, text: MeetingMarker.paused.text(english: true)),
                TranscriptLine(speaker: .marker, start: 96, text: MeetingMarker.resumed.text(english: true)),
                TranscriptLine(speaker: .room, start: 102, text: "Then on Thursday we review everything and send it to Carla. Agreed, I'll prepare the presentation for that day. That's clear, thanks, everyone."),
            ]
            summary = MeetingSummary(
                summary: "The team closed the contract with the supplier and confirmed the delivery date. The November budget is waiting for Mateo's approval.",
                decisions: ["Close the contract with the supplier.", "Review everything on Thursday and send it to Carla."],
                actionItems: ["Mateo: approve the November budget before Wednesday.", "Team: prepare the presentation for Thursday."],
                questions: ["Does the delivery date hold if the approval is late?"])
        }
        return Meeting(id: meetingID, title: spanish ? "Revisión semanal del equipo" : "Weekly team check-in", app: "iPhone",
                       startedAt: start, endedAt: start.addingTimeInterval(23 * 60), lines: lines,
                       summary: summary.markdown(english: !spanish))
    }
}
