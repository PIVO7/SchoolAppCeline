import SwiftUI

struct ClassesTab: View {
    @Environment(AppStore.self) private var store
    @State private var selection: String?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(store.settings.classes) { c in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.name.isEmpty ? "Naamloze klas" : c.name).font(.body.weight(.medium))
                        Text("\(c.students.count) leerlingen").font(.caption).foregroundStyle(Theme.muted)
                    }
                    .tag(c.id)
                }
            }
            .navigationTitle("Klassen")
            .safeAreaInset(edge: .bottom) {
                Button("+ Nieuwe klas") {
                    let c = SchoolClass(name: "Nieuwe klas")
                    store.settings.classes.append(c)
                    selection = c.id
                }
                .buttonStyle(.primary)
                .padding()
            }
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
            #endif
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let id = selection, store.settings.classes.contains(where: { $0.id == id }) {
                        ClassEditor(classID: id, onDelete: { selection = nil })
                            .id(id)
                    } else {
                        Card { Text("Kies links een klas of maak een nieuwe.").foregroundStyle(Theme.muted) }
                    }
                }
                .padding(20)
                .frame(maxWidth: 1200)
            }
            .background(Theme.background)
            .toolbar { ToolbarItem(placement: .automatic) { SaveStatusView() } }
        }
        .onAppear { if selection == nil { selection = store.settings.classes.first?.id } }
    }
}

struct ClassEditor: View {
    @Environment(AppStore.self) private var store
    let classID: String
    var onDelete: () -> Void

    @State private var namesText = ""
    @State private var pool: [Student] = []
    @State private var confirmDelete = false
    @State private var confirmRedraw = false

    private var index: Int? { store.settings.classes.firstIndex { $0.id == classID } }

    private var cls: Binding<SchoolClass> {
        Binding(
            get: { index.map { store.settings.classes[$0] } ?? SchoolClass() },
            set: { new in if let i = index { store.settings.classes[i] = new } }
        )
    }

    var body: some View {
        let c = cls
        VStack(alignment: .leading, spacing: 16) {
            Card {
                LabeledField("Naam van de klas (komt op de PDF)") {
                    TextField("bv. 4B", text: c.name).fieldStyle()
                }
                LabeledField("Namenlijst: één leerling per regel, optioneel met klasnummer vooraan") {
                    TextEditor(text: $namesText)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 260)
                        .padding(6)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                }
                Text("\(c.wrappedValue.students.count) leerlingen").font(.callout).foregroundStyle(Theme.muted)
                Button("Klas verwijderen") { confirmDelete = true }
                    .buttonStyle(SecondaryButtonStyle(small: true, color: Theme.danger))
            }
            DrawCard(cls: c, askRedraw: { confirmRedraw = true }, doDraw: { draw(c) })
        }
        .onAppear {
            namesText = StudentParser.text(for: c.wrappedValue.students)
            pool = c.wrappedValue.students
        }
        .onChange(of: namesText) { _, text in
            let parsed = StudentParser.parse(text, pool: pool)
            for s in parsed where !pool.contains(where: { $0.id == s.id }) { pool.append(s) }
            if parsed != c.wrappedValue.students { c.wrappedValue.students = parsed }
        }
        .confirmationDialog("Deze klas verwijderen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Verwijderen", role: .destructive) {
                store.settings.classes.removeAll { $0.id == classID }
                onDelete()
            }
        } message: { Text("Eerdere beoordelingen blijven bewaard, want die hebben een eigen kopie.") }
        .confirmationDialog("Opnieuw loten?", isPresented: $confirmRedraw, titleVisibility: .visible) {
            Button("Opnieuw loten", role: .destructive) { draw(c) }
        } message: { Text("De huidige volgorde wordt vervangen.") }
    }

    private func draw(_ c: Binding<SchoolClass>) {
        let ids = c.wrappedValue.students.map(\.id)
        guard !ids.isEmpty else { store.showToast("Deze klas heeft nog geen leerlingen."); return }
        var d = c.wrappedValue.draw
        d.groups = Lottery.makeGroups(Lottery.shuffle(ids), size: d.size)
        d.at = ISO8601DateFormatter.withFractional.string(from: Date())
        c.wrappedValue.draw = d
    }
}

struct DrawCard: View {
    @Environment(AppStore.self) private var store
    @Binding var cls: SchoolClass
    var askRedraw: () -> Void
    var doDraw: () -> Void

    var body: some View {
        let byID = Dictionary(cls.students.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        Card(title: "Willekeurige volgorde") {
            HStack(alignment: .top, spacing: 12) {
                LabeledField("Titel") { TextField("Volgorde spreekopdrachten", text: $cls.draw.title).fieldStyle() }
                LabeledField("Loten per") {
                    Picker("", selection: $cls.draw.size) {
                        ForEach(1...5, id: \.self) { Text($0 == 1 ? "1 leerling" : "\($0) leerlingen").tag($0) }
                    }.labelsHidden()
                }
                .frame(maxWidth: 160)
                LabeledField("Taal van de PDF") {
                    Picker("", selection: $cls.draw.lang) {
                        ForEach(FormLang.allCases) { Text($0.label).tag($0) }
                    }.labelsHidden().pickerStyle(.segmented)
                }
                .frame(maxWidth: 220)
            }
            HStack {
                if cls.draw.groups.isEmpty {
                    Button("Loten", action: doDraw).buttonStyle(.primary)
                } else {
                    Button("Opnieuw loten", action: askRedraw).buttonStyle(.secondary)
                    Button("Download als PDF") {
                        Exporter.exportPDF(PDFBuilder.drawList(cls, settings: store.settings),
                                           filename: "\(cls.draw.title) - \(cls.name)")
                    }.buttonStyle(.primary)
                }
            }

            if !cls.draw.groups.isEmpty {
                let diff = Lottery.mismatch(for: cls)
                if diff.missing > 0 || diff.gone > 0 {
                    Text("De klaslijst is veranderd na de loting: \(diff.missing) leerling(en) zitten niet in de loting, \(diff.gone) staan er niet meer in de klas. Lot opnieuw als je ze mee wil nemen.")
                        .font(.callout)
                        .padding(10)
                        .background(Theme.partial, in: RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(cls.draw.groups.enumerated()), id: \.offset) { i, g in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i + 1)").font(.body.weight(.bold)).frame(width: 28, alignment: .trailing)
                            Text(g.compactMap { byID[$0]?.name }.joined(separator: ", "))
                        }
                    }
                }
            }
        }
    }
}
