import SwiftUI
import UniformTypeIdentifiers

struct GradingTab: View {
    @Environment(AppStore.self) private var store
    var goTo: (AppTab) -> Void
    @State private var openEvalID: String?

    var body: some View {
        NavigationStack {
            Group {
                if let id = openEvalID, store.eval(id) != nil {
                    SessionView(evalID: id, close: { openEvalID = nil })
                } else {
                    GradingHome(open: { openEvalID = $0 }, goTo: goTo)
                }
            }
            .background(Theme.background)
            .navigationTitle("Rubrics · spreekopdrachten")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .automatic) { SaveStatusView() } }
        }
    }
}

// MARK: - Startscherm

struct GradingHome: View {
    @Environment(AppStore.self) private var store
    var open: (String) -> Void
    var goTo: (AppTab) -> Void

    @State private var rubricID: String = ""
    @State private var classID: String = ""
    @State private var date = Date()
    @State private var evalToDelete: Evaluation?
    @State private var importing = false
    @State private var pendingBackup: Backup?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                newCard
                historyCard
                backupCard
            }
            .padding(20)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: fixSelection)
        .confirmationDialog("Deze beoordeling verwijderen?", isPresented: Binding(get: { evalToDelete != nil }, set: { if !$0 { evalToDelete = nil } }), titleVisibility: .visible, presenting: evalToDelete) { e in
            Button("Verwijderen", role: .destructive) { store.deleteEval(e.id); evalToDelete = nil }
        } message: { e in
            Text("\(e.rubric.title) · \(e.className) · \(DateText.display(e.date)). Dit kan niet ongedaan gemaakt worden.")
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url), let b = AppStore.readBackup(data) else {
                store.showToast("Dit is geen geldig back-upbestand van de rubric-tool.")
                return
            }
            pendingBackup = b
        }
        .alert("Back-up terugzetten?", isPresented: Binding(get: { pendingBackup != nil }, set: { if !$0 { pendingBackup = nil } }), presenting: pendingBackup) { b in
            Button("Terugzetten") {
                store.merge(b)
                pendingBackup = nil
                fixSelection()
                store.showToast("Back-up teruggezet.")
            }
            Button("Annuleren", role: .cancel) { pendingBackup = nil }
        } message: { b in
            let when = b.exportedAt.isEmpty ? "" : "Back-up van \(DateText.display(String(b.exportedAt.prefix(10)))): "
            Text("\(when)\(b.settings.rubrics.count) rubrics, \(b.settings.classes.count) klassen en \(b.evals.count) beoordelingen. Ze worden samengevoegd met wat er al staat; er wordt niets gewist.")
        }
    }

    private func fixSelection() {
        if !store.settings.rubrics.contains(where: { $0.id == rubricID }) { rubricID = store.settings.rubrics.first?.id ?? "" }
        if !store.settings.classes.contains(where: { $0.id == classID }) { classID = store.settings.classes.first?.id ?? "" }
    }

    private var newCard: some View {
        Card(title: "Nieuwe beoordeling") {
            if store.settings.rubrics.isEmpty || store.settings.classes.isEmpty {
                Text("Je hebt eerst een rubric en een klas nodig.").foregroundStyle(Theme.muted)
                HStack {
                    if store.settings.rubrics.isEmpty { Button("Rubric maken") { goTo(.rubrics) }.buttonStyle(.secondary) }
                    if store.settings.classes.isEmpty { Button("Klas maken") { goTo(.classes) }.buttonStyle(.secondary) }
                }
            } else {
                HStack(alignment: .bottom, spacing: 12) {
                    LabeledField("Rubric") {
                        Picker("", selection: $rubricID) {
                            ForEach(store.settings.rubrics) { Text($0.title.isEmpty ? "Naamloze rubric" : $0.title).tag($0.id) }
                        }.labelsHidden()
                    }
                    LabeledField("Klas") {
                        Picker("", selection: $classID) {
                            ForEach(store.settings.classes) { Text("\($0.name) (\($0.students.count))").tag($0.id) }
                        }.labelsHidden()
                    }
                    LabeledField("Datum") {
                        DatePicker("", selection: $date, displayedComponents: .date).labelsHidden()
                    }
                    Button("Start beoordeling", action: start).buttonStyle(.primary)
                }
            }
        }
    }

    private func start() {
        guard let r = store.settings.rubrics.first(where: { $0.id == rubricID }),
              let c = store.settings.classes.first(where: { $0.id == classID }) else { return }
        guard !c.students.isEmpty else { store.showToast("Deze klas heeft nog geen leerlingen."); return }
        let e = Evaluation(rubric: r, schoolClass: c, date: DateText.isoString(date))
        store.addEval(e)
        open(e.id)
    }

    private var historyCard: some View {
        Card(title: "Eerdere beoordelingen") {
            if store.sortedEvals.isEmpty {
                Text("Nog geen beoordelingen.").foregroundStyle(Theme.muted)
            }
            ForEach(store.sortedEvals) { e in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.rubric.title).font(.body.weight(.semibold))
                        Text("\(e.className) · \(DateText.display(e.date)) · \(e.evaluatedCount) van \(e.students.count) beoordeeld")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button("Openen") { open(e.id) }.buttonStyle(.secondarySmall)
                    Button("PDF") { exportClass(e) }.buttonStyle(.secondarySmall)
                    Button { evalToDelete = e } label: { Image(systemName: "trash") }.buttonStyle(.danger)
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
    }

    private func exportClass(_ e: Evaluation) {
        let done = e.sortedStudents.filter { e.isEvaluated($0.id) }
        guard !done.isEmpty else { store.showToast("Nog niemand beoordeeld in deze sessie."); return }
        Exporter.exportPDF(PDFBuilder.evaluation(e, students: done, settings: store.settings),
                           filename: "\(e.rubric.title) - \(e.className) - \(DateText.display(e.date, separator: "-"))")
    }

    private var backupCard: some View {
        Card(title: "Back-up") {
            Text("Bewaar alles (rubrics, klassen, beoordelingen) in één bestand, of zet een back-up terug. Terugzetten voegt samen en wist niets. Zo haal je ook de gegevens uit de oude tool binnen.")
                .font(.callout).foregroundStyle(Theme.muted)
            HStack {
                Button("Back-up downloaden") {
                    do {
                        let data = try store.makeBackup()
                        Exporter.export(data, filename: "Rubrics back-up \(DateText.display(DateText.todayISO(), separator: "-")).json", type: .json)
                    } catch {
                        store.showToast("Back-up maken mislukt.")
                    }
                }.buttonStyle(.secondary)
                Button("Back-up terugzetten…") { importing = true }.buttonStyle(.secondary)
            }
        }
    }
}
