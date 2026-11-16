import SwiftUI

struct SessionView: View {
    @Environment(AppStore.self) private var store
    let evalID: String
    var close: () -> Void

    @State private var expanded: Set<String> = []
    @State private var width: CGFloat = 1000

    private var e: Evaluation { store.eval(evalID)! }
    private var cls: SchoolClass? { store.schoolClass(e.classId) }
    private var criterionWidth: CGFloat { width < 900 ? 150 : 230 }

    private func update(delay: Double = 0.5, _ change: (inout Evaluation) -> Void) {
        store.updateEval(evalID, delay: delay, change)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                header
                chipsCard
                totalSettings
                if e.stage.isEmpty {
                    emptyStage
                } else {
                    Section(header: gridHeader) { gridRows }
                    stageButtons
                }
                doneList
            }
            .padding(20)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
        }
        .background(GeometryReader { g in
            Color.clear
                .onAppear { width = g.size.width }
                .onChange(of: g.size.width) { _, w in width = w }
        })
    }

    // MARK: Kop

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button("← Alle beoordelingen", action: close).buttonStyle(.secondarySmall)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.rubric.title).font(.title3.weight(.bold))
                Text("\(e.className) · \(DateText.display(e.date))").font(.callout).foregroundStyle(Theme.muted)
            }
            Spacer()
            Button("PDF hele klas") { pdf(e.sortedStudents.filter { e.isEvaluated($0.id) }, name: "\(e.className) - \(DateText.display(e.date, separator: "-"))") }
                .buttonStyle(.secondary)
        }
    }

    // MARK: Chips

    private var hasDraw: Bool { !(cls?.draw.groups.isEmpty ?? true) }

    private var chipsCard: some View {
        Card {
            HStack {
                Text("Wie staat er voor de klas?").font(.headline)
                Spacer()
                if hasDraw {
                    Picker("Volgorde", selection: Binding(get: { e.useDraw }, set: { v in update { $0.useDraw = v } })) {
                        Text("Klasnummer").tag(false)
                        Text("Loting").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                }
            }
            if e.useDraw && hasDraw {
                let groups = e.drawGroups(using: cls)
                let grouped = (cls?.draw.size ?? 1) > 1
                FlowLayout(spacing: 8) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { gi, g in
                        if grouped {
                            HStack(spacing: 6) {
                                Text("\(gi + 1)").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                                ForEach(g) { chip($0) }
                            }
                            .padding(6)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])))
                        } else {
                            ForEach(g) { chip($0) }
                        }
                    }
                }
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(e.sortedStudents) { chip($0) }
                }
            }
        }
    }

    private func chip(_ s: Student) -> some View {
        let state = e.chipState(s.id)
        let (fill, border, fg): (Color, Color, Color) = switch state {
        case .stage: (Theme.accent, Theme.accent, Color.white)
        case .done: (Theme.doneFill, Theme.doneBorder, Theme.text)
        case .partial: (Theme.partial, Theme.partialBorder, Theme.text)
        case .normal: (Color.white, Theme.border, Theme.text)
        }
        return Button {
            update(delay: 0.35) { $0.toggleStage(s.id) }
        } label: {
            HStack(spacing: 6) {
                Text("\(s.nr)").font(.caption).opacity(0.7)
                Text(s.name).font(.callout.weight(.medium))
                if state == .done { Text("✓").font(.callout.weight(.bold)) }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .foregroundStyle(fg)
            .background(fill, in: Capsule())
            .overlay(Capsule().stroke(border))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var emptyStage: some View {
        VStack(spacing: 10) {
            Text("Tik hierboven op één of meer leerlingen om ze te beoordelen.")
                .foregroundStyle(Theme.muted)
            if e.useDraw, let next = e.nextDrawGroup(using: cls) {
                Button("Volgende uit de loting: \(next.map(\.name).joined(separator: ", "))") {
                    update(delay: 0.35) { $0.stage = next.map(\.id) }
                }
                .buttonStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
    }

    // MARK: Totaalcijfer-instelling

    private var totalSettings: some View {
        HStack(spacing: 10) {
            Toggle("Totaalcijfer", isOn: Binding(get: { e.rubric.showTotal }, set: { v in
                update { $0.rubric.showTotal = v; if v && $0.rubric.totalMax.isEmpty { $0.rubric.totalMax = "20" } }
            }))
            if e.rubric.showTotal {
                Text("op").foregroundStyle(Theme.muted)
                TextField("20", text: Binding(get: { e.rubric.totalMax }, set: { v in update(delay: 0.8) { $0.rubric.totalMax = v } }))
                    .fieldStyle().frame(width: 64)
            }
            Spacer()
        }
        #if os(macOS)
        .toggleStyle(.checkbox)
        #endif
    }

    // MARK: Raster

    private var showGroup: Bool { e.stage.count > 1 }
    private var levelCount: Int { e.rubric.levels.count }

    private func row<A: View, C: View>(@ViewBuilder label: () -> A, group: (() -> AnyView)? = nil,
                                       @ViewBuilder cell: @escaping (String) -> C) -> some View {
        HStack(alignment: .top, spacing: 8) {
            label().frame(width: criterionWidth, alignment: .leading)
            if showGroup {
                Group {
                    if let group { group() } else { Color.clear.frame(height: 1) }
                }
                .frame(maxWidth: .infinity)
            }
            ForEach(e.stage, id: \.self) { sid in
                cell(sid).frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    private var gridHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Criterium").font(.subheadline.weight(.semibold)).frame(width: criterionWidth, alignment: .leading)
            if showGroup {
                Text("Hele groep").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
            }
            ForEach(e.stage, id: \.self) { sid in
                HStack(spacing: 4) {
                    Text(e.student(sid)?.name ?? "?").font(.subheadline.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 2)
                    Button { update(delay: 0.35) { $0.toggleStage(sid) } } label: {
                        Image(systemName: "xmark").font(.caption.weight(.bold)).padding(6)
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(hex: 0xF3F1EC))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    @ViewBuilder
    private var gridRows: some View {
        VStack(spacing: 0) {
            ForEach(e.rubric.criteria) { c in
                row(label: { criterionLabel(c) }, group: { AnyView(groupCell(c)) }, cell: { sid in studentCell(sid, c) })
                Divider()
            }
            if e.rubric.showTotal {
                row(label: { rowLabel("Totaal", "Vul zelf de score in") }, cell: { sid in totalCell(sid) })
                Divider()
            }
            row(label: { rowLabel("Pluspunten", "Eén punt per regel") }, cell: { sid in textCell(sid, \.plus, "bv. goed oogcontact") })
            Divider()
            row(label: { rowLabel("Werkpunten", "Eén punt per regel") }, cell: { sid in textCell(sid, \.work, "bv. luider spreken") })
            Divider()
            row(label: { rowLabel("Algemene feedback", "Optioneel") }, cell: { sid in textCell(sid, \.feedback, "Optioneel") })
        }
        .background(Theme.card)
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(Theme.border))
    }

    private func rowLabel(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(sub).font(.caption).foregroundStyle(Theme.muted)
        }
    }

    private func criterionLabel(_ c: Criterion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(c.name.uppercased()).font(.subheadline.weight(.bold))
                Button(expanded.contains(c.id) ? "verberg uitleg" : "toon uitleg") {
                    if expanded.contains(c.id) { expanded.remove(c.id) } else { expanded.insert(c.id) }
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(Theme.muted)
            }
            if expanded.contains(c.id) {
                ForEach(Array(c.descs.padded(to: levelCount).enumerated()), id: \.offset) { i, d in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.rubric.levels[i]).font(.caption.weight(.semibold))
                            .foregroundStyle(LevelColor.color(index: i, count: levelCount))
                        Text(d).font(.caption).foregroundStyle(Theme.text)
                    }
                }
            }
        }
    }

    private func groupCell(_ c: Criterion) -> some View {
        let current = e.groupLevel(criterion: c.id)
        return VStack(spacing: 6) {
            ForEach(0..<levelCount, id: \.self) { i in
                LevelButton(title: e.rubric.levels[i], index: i, count: levelCount, selected: current == i) {
                    update(delay: 0.35) { $0.setGroupScore(criterion: c.id, level: i) }
                }
            }
        }
    }

    private func studentCell(_ sid: String, _ c: Criterion) -> some View {
        let chosen = e.result(sid).scores[c.id]
        return VStack(spacing: 6) {
            ForEach(0..<levelCount, id: \.self) { i in
                LevelButton(title: e.rubric.levels[i], index: i, count: levelCount, selected: chosen == i) {
                    update(delay: 0.35) { $0.toggleScore(student: sid, criterion: c.id, level: i) }
                }
            }
        }
    }

    private func totalCell(_ sid: String) -> some View {
        HStack(spacing: 6) {
            TextField("", text: Binding(
                get: { e.result(sid).total },
                set: { v in update(delay: 0.8) { $0.results[sid, default: StudentResult()].total = String(v.prefix(6)) } }))
                .fieldStyle()
                .frame(width: 80)
            Text("/ \(e.rubric.totalMax.isEmpty ? "20" : e.rubric.totalMax)").font(.callout.weight(.semibold))
            Spacer(minLength: 0)
        }
    }

    private func textCell(_ sid: String, _ key: WritableKeyPath<StudentResult, String>, _ placeholder: String) -> some View {
        TextField(placeholder, text: Binding(
            get: { e.result(sid)[keyPath: key] },
            set: { v in update(delay: 0.9) { $0.results[sid, default: StudentResult()][keyPath: key] = v } }),
                  axis: .vertical)
            .lineLimit(2...12)
            .fieldStyle()
    }

    // MARK: Knoppen onder het raster

    private var stageButtons: some View {
        HStack(spacing: 10) {
            Button(e.stage.count == 1 ? "Klaar met deze leerling" : "Klaar met deze groep") {
                var incomplete = 0
                update(delay: 0.2) { incomplete = $0.finishStage() }
                if incomplete > 0 {
                    store.showToast(incomplete == 1 ? "Bewaard, maar 1 leerling is niet volledig ingevuld." :
                                        "Bewaard, maar \(incomplete) leerlingen zijn niet volledig ingevuld.")
                } else {
                    store.showToast("Opgeslagen.")
                }
            }
            .buttonStyle(.primary)
            Button(e.stage.count == 1 ? "PDF van deze leerling" : "PDF van deze groep") {
                let students = e.stage.compactMap { e.student($0) }
                pdf(students, name: students.count == 1 ? students[0].name : "groep")
            }
            .buttonStyle(.secondary)
        }
    }

    // MARK: Beoordeeld

    private var doneList: some View {
        let done = e.sortedStudents.filter { e.isEvaluated($0.id) }
        return Card(title: "Beoordeeld (\(done.count)/\(e.students.count))") {
            ForEach(done) { s in
                let r = e.result(s.id)
                HStack(spacing: 10) {
                    Text("\(s.nr)").font(.caption).foregroundStyle(Theme.muted).frame(width: 24, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(s.name).font(.body.weight(.semibold))
                            HStack(spacing: 3) {
                                ForEach(e.rubric.criteria) { c in LevelDot(index: r.scores[c.id], count: levelCount) }
                            }
                        }
                        let partners = r.partners.compactMap { e.student($0)?.name }
                        if !partners.isEmpty {
                            Text("samen met \(partners.joined(separator: ", "))").font(.caption).foregroundStyle(Theme.muted)
                        }
                    }
                    Spacer()
                    if e.rubric.showTotal && !r.total.isEmpty {
                        Text("\(r.total) / \(e.rubric.totalMax)").font(.callout.weight(.semibold))
                    }
                    Button("Aanpassen") {
                        update(delay: 0.35) { if !$0.stage.contains(s.id) { $0.stage.append(s.id) } }
                    }.buttonStyle(.secondarySmall)
                    Button("PDF") { pdf([s], name: s.name) }.buttonStyle(.secondarySmall)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: PDF

    private func pdf(_ students: [Student], name: String) {
        guard !students.isEmpty else { store.showToast("Nog niemand beoordeeld."); return }
        store.flushAll()
        Exporter.exportPDF(PDFBuilder.evaluation(e, students: students, settings: store.settings),
                           filename: "\(e.rubric.title) - \(name)")
    }
}
