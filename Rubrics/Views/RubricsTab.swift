import SwiftUI
import UniformTypeIdentifiers

struct RubricsTab: View {
    @Environment(AppStore.self) private var store
    @State private var selection: String?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(store.settings.rubrics) { r in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.title.isEmpty ? "Naamloze rubric" : r.title).font(.body.weight(.medium))
                        Text("\(r.criteria.count) criteria · \(r.levels.count) niveaus")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                    .tag(r.id)
                }
            }
            .navigationTitle("Rubrics")
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button("+ Nieuwe rubric") { add(.blank()) }.buttonStyle(.primary)
                    Button("+ Fun Facts Quiz (voorbeeld)") { add(.funFactsQuiz()) }.buttonStyle(.secondarySmall)
                }
                .padding()
            }
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            #endif
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let id = selection, store.settings.rubrics.contains(where: { $0.id == id }) {
                        RubricEditor(rubricID: id, onDelete: { selection = nil }, onDuplicate: { selection = $0 })
                    } else {
                        Card { Text("Kies links een rubric of maak een nieuwe.").foregroundStyle(Theme.muted) }
                    }
                    LogoCard()
                }
                .padding(20)
                .frame(maxWidth: 1200)
            }
            .background(Theme.background)
            .toolbar { ToolbarItem(placement: .automatic) { SaveStatusView() } }
        }
        .onAppear { if selection == nil { selection = store.settings.rubrics.first?.id } }
    }

    private func add(_ r: Rubric) {
        store.settings.rubrics.append(r)
        selection = r.id
    }
}

struct RubricEditor: View {
    @Environment(AppStore.self) private var store
    let rubricID: String
    var onDelete: () -> Void
    var onDuplicate: (String) -> Void

    @State private var confirmDeleteRubric = false
    @State private var levelToDelete: Int?
    @State private var criterionToDelete: String?

    private var index: Int? { store.settings.rubrics.firstIndex { $0.id == rubricID } }

    private var rubric: Binding<Rubric> {
        Binding(
            get: { index.map { store.settings.rubrics[$0] } ?? Rubric() },
            set: { new in if let i = index { store.settings.rubrics[i] = new } }
        )
    }

    var body: some View {
        let r = rubric
        Card {
            VStack(alignment: .leading, spacing: 14) {
                LabeledField("Titel") { TextField("Titel", text: r.title).fieldStyle() }
                HStack(alignment: .top, spacing: 12) {
                    LabeledField("Vak") { TextField("bv. English", text: r.subject).fieldStyle() }
                    LabeledField("Taal van het formulier") {
                        Picker("", selection: r.lang) {
                            ForEach(FormLang.allCases) { Text($0.label).tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }
                }
                HStack(spacing: 10) {
                    Toggle("Totaalcijfer op het formulier", isOn: r.showTotal)
                    if r.wrappedValue.showTotal {
                        Text("op").foregroundStyle(Theme.muted)
                        TextField("20", text: r.totalMax).fieldStyle().frame(width: 70)
                    }
                }

                Divider()
                levelsEditor(r)
                Divider()
                criteriaEditor(r)

                FlowLayout(spacing: 8) {
                    Button("+ Criterium") {
                        r.wrappedValue.criteria.append(Criterion(descs: Array(repeating: "", count: r.wrappedValue.levels.count)))
                    }.buttonStyle(.secondary)
                    Button("Lege rubric als PDF") {
                        Exporter.exportPDF(PDFBuilder.blank(r.wrappedValue, settings: store.settings),
                                           filename: "\(r.wrappedValue.title) - leeg")
                    }.buttonStyle(.secondary)
                    Button("Kopie maken") {
                        let copy = r.wrappedValue.duplicated()
                        store.settings.rubrics.append(copy)
                        onDuplicate(copy.id)
                    }.buttonStyle(.secondary)
                    Button("Verwijderen") { confirmDeleteRubric = true }
                        .buttonStyle(SecondaryButtonStyle(color: Theme.danger))
                }
            }
        }
        .confirmationDialog("Deze rubric verwijderen?", isPresented: $confirmDeleteRubric, titleVisibility: .visible) {
            Button("Verwijderen", role: .destructive) {
                store.settings.rubrics.removeAll { $0.id == rubricID }
                onDelete()
            }
        } message: { Text("Eerdere beoordelingen blijven bewaard, want die hebben een eigen kopie.") }
        .confirmationDialog("Dit niveau verwijderen?", isPresented: Binding(get: { levelToDelete != nil }, set: { if !$0 { levelToDelete = nil } }), titleVisibility: .visible) {
            Button("Verwijderen", role: .destructive) {
                if let i = levelToDelete { removeLevel(i, r) }
                levelToDelete = nil
            }
        } message: { Text("De omschrijvingen van dit niveau verdwijnen bij alle criteria.") }
        .confirmationDialog("Dit criterium verwijderen?", isPresented: Binding(get: { criterionToDelete != nil }, set: { if !$0 { criterionToDelete = nil } }), titleVisibility: .visible) {
            Button("Verwijderen", role: .destructive) {
                r.wrappedValue.criteria.removeAll { $0.id == criterionToDelete }
                criterionToDelete = nil
            }
        }
    }

    @ViewBuilder
    private func levelsEditor(_ r: Binding<Rubric>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Niveaus (van best naar zwakst)").font(.subheadline.weight(.semibold))
            FlowLayout(spacing: 8) {
                ForEach(r.wrappedValue.levels.indices, id: \.self) { i in
                    HStack(spacing: 4) {
                        Circle().fill(LevelColor.color(index: i, count: r.wrappedValue.levels.count)).frame(width: 10, height: 10)
                        TextField("Niveau", text: Binding(
                            get: { i < r.wrappedValue.levels.count ? r.wrappedValue.levels[i] : "" },
                            set: { if i < r.wrappedValue.levels.count { r.wrappedValue.levels[i] = $0 } }))
                            .frame(width: 130)
                        if r.wrappedValue.levels.count > 1 {
                            Button { levelToDelete = i } label: { Image(systemName: "xmark") }
                                .buttonStyle(.plain).foregroundStyle(Theme.muted)
                        }
                    }
                    .fieldStyle()
                }
                Button("+ Niveau") {
                    r.wrappedValue.levels.append("Level \(r.wrappedValue.levels.count + 1)")
                    for k in r.wrappedValue.criteria.indices { r.wrappedValue.criteria[k].descs.append("") }
                }.buttonStyle(.secondarySmall)
            }
        }
    }

    private func removeLevel(_ i: Int, _ r: Binding<Rubric>) {
        guard i < r.wrappedValue.levels.count else { return }
        r.wrappedValue.levels.remove(at: i)
        for k in r.wrappedValue.criteria.indices where i < r.wrappedValue.criteria[k].descs.count {
            r.wrappedValue.criteria[k].descs.remove(at: i)
        }
    }

    @ViewBuilder
    private func criteriaEditor(_ r: Binding<Rubric>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Criteria").font(.subheadline.weight(.semibold))
            ForEach(Array(r.wrappedValue.criteria.enumerated()), id: \.element.id) { ci, crit in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Naam van het criterium", text: Binding(
                            get: { r.wrappedValue.criteria.first { $0.id == crit.id }?.name ?? "" },
                            set: { v in if let k = r.wrappedValue.criteria.firstIndex(where: { $0.id == crit.id }) { r.wrappedValue.criteria[k].name = v } }))
                            .font(.body.weight(.semibold))
                            .fieldStyle()
                        Button { move(ci, -1, r) } label: { Image(systemName: "arrow.up") }
                            .buttonStyle(.secondarySmall).disabled(ci == 0)
                        Button { move(ci, 1, r) } label: { Image(systemName: "arrow.down") }
                            .buttonStyle(.secondarySmall).disabled(ci == r.wrappedValue.criteria.count - 1)
                        Button {
                            let hasText = !crit.name.isEmpty || crit.descs.contains { !$0.isEmpty }
                            if hasText { criterionToDelete = crit.id } else { r.wrappedValue.criteria.removeAll { $0.id == crit.id } }
                        } label: { Image(systemName: "xmark") }
                            .buttonStyle(.danger)
                    }
                    let n = r.wrappedValue.levels.count
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: max(1, n)), spacing: 8) {
                        ForEach(0..<n, id: \.self) { li in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(r.wrappedValue.levels[li]).font(.caption.weight(.semibold))
                                    .foregroundStyle(LevelColor.color(index: li, count: n))
                                TextField("Omschrijving", text: descBinding(r, critID: crit.id, level: li), axis: .vertical)
                                    .lineLimit(2...8)
                                    .font(.callout)
                                    .fieldStyle()
                            }
                        }
                    }
                }
                .padding(12)
                .background(Theme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func descBinding(_ r: Binding<Rubric>, critID: String, level: Int) -> Binding<String> {
        Binding(
            get: {
                guard let c = r.wrappedValue.criteria.first(where: { $0.id == critID }), level < c.descs.count else { return "" }
                return c.descs[level]
            },
            set: { v in
                guard let k = r.wrappedValue.criteria.firstIndex(where: { $0.id == critID }) else { return }
                var descs = r.wrappedValue.criteria[k].descs.padded(to: r.wrappedValue.levels.count)
                if level < descs.count { descs[level] = v }
                r.wrappedValue.criteria[k].descs = descs
            })
    }

    private func move(_ i: Int, _ d: Int, _ r: Binding<Rubric>) {
        let j = i + d
        guard j >= 0, j < r.wrappedValue.criteria.count else { return }
        r.wrappedValue.criteria.swapAt(i, j)
    }
}

struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LogoCard: View {
    @Environment(AppStore.self) private var store
    @State private var importing = false

    var body: some View {
        @Bindable var store = store
        Card(title: "Logo op de PDF") {
            Toggle("Logo tonen op de PDF's", isOn: $store.settings.showLogo)
            if let img = LogoImage.cgImage(for: store.settings) {
                Image(decorative: img, scale: 1)
                    .resizable().scaledToFit()
                    .frame(maxWidth: 260, maxHeight: 60, alignment: .leading)
                    .padding(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
            } else {
                Text("Nog geen logo gekozen.").font(.callout).foregroundStyle(Theme.muted)
            }
            HStack {
                Button("Ander logo…") { importing = true }.buttonStyle(.secondary)
                if store.settings.logo != nil {
                    Button("Schoollogo terugzetten") { store.settings.logo = nil }.buttonStyle(.secondary)
                }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), let logo = LogoImage.makeLogo(from: data) {
                store.settings.logo = logo
            } else {
                store.showToast("Dit bestand kon niet als logo gelezen worden.")
            }
        }
    }
}
