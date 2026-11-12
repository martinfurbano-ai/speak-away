import SpeakAwayBrain
import SpeakAwayCore
import SwiftUI

// MARK: Diccionario

struct DictionaryPage: View {
    @ObservedObject var store: ObservableJSONStore<PersonalDictionary>
    @State private var word = ""
    @State private var heard = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(title: "Diccionario", subtitle: "Nombres, marcas y palabras de tu trabajo. Whisper las escribe bien y corrige lo que suele oír mal.")
            Card {
                HStack(spacing: 10) {
                    TextField("Palabra, por ejemplo «Speak Away»", text: $word).textFieldStyle(.roundedBorder)
                    TextField("Lo que oye mal, con comas (opcional)", text: $heard).textFieldStyle(.roundedBorder)
                    Button("Agregar") { add() }.buttonStyle(.borderedProminent).disabled(word.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            if store.value.entries.isEmpty {
                EmptyState(icon: "character.book.closed", title: "Tu diccionario está vacío", detail: "Agrega el nombre de tu empresa, tus clientes o tu jerga.")
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(store.value.entries, id: \.word) { entry in
                        HStack(spacing: 6) {
                            Text(entry.word).font(.system(size: 13, weight: .medium))
                            if !entry.replacing.isEmpty {
                                Text("← " + entry.replacing.joined(separator: ", ")).font(.system(size: 12)).foregroundStyle(.secondary)
                            }
                            Button { store.update { $0.removing(word: entry.word) } } label: { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)) }
                                .buttonStyle(.borderless).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(Theme.card))
                    }
                }
            }
        }
        .padding(28)
    }

    private func add() {
        let replacing = heard.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let entry = DictionaryEntry(word: word.trimmingCharacters(in: .whitespaces), replacing: replacing)
        store.update { $0.adding(entry) }
        word = ""; heard = ""
    }
}

// MARK: Atajos de voz

struct SnippetsPage: View {
    @ObservedObject var store: ObservableJSONStore<Snippets>
    @State private var trigger = ""
    @State private var expansion = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(title: "Atajos de voz", subtitle: "Di una frase corta y se escribe un texto largo: tu link de calendario, tu dirección, una respuesta que repites.")
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Cuando diga… por ejemplo «mi link de calendario»", text: $trigger).textFieldStyle(.roundedBorder)
                    TextEditor(text: $expansion)
                        .font(.system(size: 13)).frame(height: 70).scrollContentBackground(.hidden)
                        .padding(6).background(RoundedRectangle(cornerRadius: 8).fill(Theme.background))
                        .overlay(alignment: .topLeading) {
                            if expansion.isEmpty { Text("…escribe esto").font(.system(size: 13)).foregroundStyle(.tertiary).padding(11).allowsHitTesting(false) }
                        }
                    HStack { Spacer(); Button("Agregar atajo") { add() }.buttonStyle(.borderedProminent).disabled(trigger.isEmpty || expansion.isEmpty) }
                }
            }
            if store.value.items.isEmpty {
                EmptyState(icon: "text.badge.plus", title: "Sin atajos todavía", detail: "Tu primer atajo te ahorra escribir lo mismo cada día.")
            } else {
                VStack(spacing: 0) {
                    ForEach(store.value.items, id: \.trigger) { s in
                        HStack(alignment: .top, spacing: 14) {
                            Text("«\(s.trigger)»").font(.system(size: 14, weight: .semibold)).frame(width: 220, alignment: .leading)
                            Image(systemName: "arrow.right").foregroundStyle(Theme.accent).font(.system(size: 12, weight: .semibold)).padding(.top, 3)
                            Text(s.expansion).font(.system(size: 13)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).lineLimit(3)
                            Button { store.update { $0.removing(trigger: s.trigger) } } label: { Image(systemName: "trash") }.buttonStyle(.borderless).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 13)
                        if s.trigger != store.value.items.last?.trigger { Divider().padding(.leading, 16) }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
            }
        }
        .padding(28)
    }

    private func add() {
        store.update { $0.adding(Snippet(trigger: trigger.trimmingCharacters(in: .whitespaces), expansion: expansion)) }
        trigger = ""; expansion = ""
    }
}

// MARK: Estilo

struct StylePage: View {
    @ObservedObject var store: ObservableJSONStore<StyleSettings>
    @State private var autoEdit = Settings.autoEdit
    @State private var polish = Settings.polish

    private let categories: [(AppCategory, String, String, String)] = [
        (.messages, "Mensajes", "WhatsApp, iMessage, Slack, Telegram", "message"),
        (.email, "Correo", "Mail, Gmail, Outlook, Spark", "envelope"),
        (.work, "Trabajo y notas", "Notas, Notion, Word, Pages, Teams", "doc.text"),
        (.other, "Todo lo demás", "Navegador y otras apps", "square.grid.2x2"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(title: "Estilo", subtitle: "Cómo suena tu texto en cada tipo de app. Lo que dices es igual; cambia cómo se escribe.")
            VStack(spacing: 12) {
                ForEach(categories, id: \.0) { category, title, apps, icon in
                    Card {
                        HStack(spacing: 14) {
                            Image(systemName: icon).font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.accent).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title).font(.system(size: 14, weight: .semibold))
                                Text(apps).font(.system(size: 12)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Picker("", selection: Binding(get: { store.value.style(for: category) },
                                                          set: { v in store.update { $0.setting(v, for: category) } })) {
                                Text("Formal").tag(WritingStyle.formal)
                                Text("Casual").tag(WritingStyle.casual)
                                Text("Muy casual").tag(WritingStyle.veryCasual)
                            }
                            .pickerStyle(.segmented).labelsHidden().fixedSize()
                        }
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    toggle("Limpiar muletillas y correcciones", "«eh», «este», y «a las 2, no, mejor a las 3» queda «a las 3».", $autoEdit) { Settings.autoEdit = $0 }
                    Divider()
                    toggle("Pulir con Apple Intelligence", polishDetail, $polish) { Settings.polish = $0 }
                        .disabled(!LocalBrain.availability.isUsable)
                }
            }
            Card {
                HStack(spacing: 12) {
                    Keycap("control"); Keycap("fn")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Modo comando").font(.system(size: 14, weight: .semibold))
                        Text("Selecciona texto, mantén Control + Fn y di qué hacer: «hazlo más formal», «tradúcelo al inglés».")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(28)
    }

    private var polishDetail: String {
        LocalBrain.availability.isUsable ? "Ordena la frase en tu Mac antes de pegarla. Tarda un poco más." : LocalBrain.availability.message
    }

    private func toggle(_ title: String, _ detail: String, _ value: Binding<Bool>, save: @escaping (Bool) -> Void) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: value).labelsHidden().toggleStyle(.switch).onChange(of: value.wrappedValue) { _, v in save(v) }
        }
    }
}

/// Wraps chips onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += row + spacing; row = 0 }
            x += size.width + spacing; row = max(row, size.height)
        }
        return CGSize(width: width, height: y + row)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += row + spacing; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; row = max(row, size.height)
        }
    }
}
