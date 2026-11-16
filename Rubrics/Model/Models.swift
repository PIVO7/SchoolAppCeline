import Foundation

// Datamodel, compatibel met het JSON-formaat van de huidige tool
// ("rubrics-spreekopdrachten", versie 1). Ontbrekende velden krijgen
// standaardwaarden, zodat oudere back-ups ook ingelezen worden.

func newID() -> String { UUID().uuidString.lowercased() }

enum FormLang: String, Codable, CaseIterable, Identifiable {
    case en, nl
    var id: String { rawValue }
    var label: String { self == .en ? "Engels" : "Nederlands" }
}

struct Criterion: Codable, Identifiable, Hashable {
    var id: String = newID()
    var name: String = ""
    var descs: [String] = []

    init(id: String = newID(), name: String = "", descs: [String] = []) {
        self.id = id; self.name = name; self.descs = descs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.value(.id, default: newID())
        name = try c.value(.name, default: "")
        descs = try c.value(.descs, default: [])
    }
}

struct Rubric: Codable, Identifiable, Hashable {
    var id: String = newID()
    var title: String = ""
    var subject: String = ""
    var lang: FormLang = .en
    var levels: [String] = ["Strong", "Sufficient", "Insufficient"]
    var criteria: [Criterion] = []
    var showTotal: Bool = true
    var totalMax: String = "20"

    init(id: String = newID(), title: String = "", subject: String = "", lang: FormLang = .en,
         levels: [String] = ["Strong", "Sufficient", "Insufficient"], criteria: [Criterion] = [],
         showTotal: Bool = true, totalMax: String = "20") {
        self.id = id; self.title = title; self.subject = subject; self.lang = lang
        self.levels = levels; self.criteria = criteria; self.showTotal = showTotal; self.totalMax = totalMax
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.value(.id, default: newID())
        title = try c.value(.title, default: "")
        subject = try c.value(.subject, default: "")
        lang = (try? c.decode(FormLang.self, forKey: .lang)) ?? .en
        levels = try c.value(.levels, default: ["Strong", "Sufficient", "Insufficient"])
        criteria = try c.value(.criteria, default: [])
        showTotal = try c.value(.showTotal, default: true)
        totalMax = c.flexibleString(.totalMax) ?? "20"
        // Zorg dat elke omschrijvingenlijst even lang is als de niveaus.
        for i in criteria.indices { criteria[i].descs = criteria[i].descs.padded(to: levels.count) }
    }

    /// Een volledig nieuwe kopie met nieuwe id's.
    func duplicated() -> Rubric {
        var r = self
        r.id = newID()
        r.title = title + " (kopie)"
        r.criteria = criteria.map { Criterion(id: newID(), name: $0.name, descs: $0.descs) }
        return r
    }

    static func blank() -> Rubric {
        Rubric(title: "Nieuwe rubric", criteria: [Criterion(descs: ["", "", ""])])
    }

    static func funFactsQuiz() -> Rubric {
        Rubric(
            title: "Speaking skill – Fun Facts Quiz", subject: "English", lang: .en,
            criteria: [
                Criterion(name: "Task completion", descs: [
                    "You follow all the rules of the assignment.",
                    "You forget one or two rules.",
                    "You don't do as asked."]),
                Criterion(name: "Pronunciation", descs: [
                    "Your pronunciation is clear and correct.",
                    "Your pronunciation is mostly understandable, with some mistakes.",
                    "Your pronunciation is hard to understand."]),
                Criterion(name: "Presentation skills", descs: [
                    "You speak fluently, loudly enough and make eye contact.",
                    "You sometimes hesitate or read from your notes.",
                    "You mostly read and are hard to follow."]),
                Criterion(name: "Creativity", descs: [
                    "Your fun facts are original and surprising.",
                    "Your fun facts are fine but not very original.",
                    "Your fun facts are missing or copied."]),
            ])
    }
}

struct Student: Codable, Identifiable, Hashable {
    var id: String = newID()
    var nr: Int = 0
    var name: String = ""

    init(id: String = newID(), nr: Int, name: String) {
        self.id = id; self.nr = nr; self.name = name
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.value(.id, default: newID())
        if let i = try? c.decode(Int.self, forKey: .nr) { nr = i }
        else if let d = try? c.decode(Double.self, forKey: .nr) { nr = Int(d) }
        else if let s = try? c.decode(String.self, forKey: .nr), let i = Int(s) { nr = i }
        else { nr = 0 }
        name = try c.value(.name, default: "")
    }
}

struct Draw: Codable, Hashable {
    var title: String = "Volgorde spreekopdrachten"
    var size: Int = 1
    var lang: FormLang = .nl
    var groups: [[String]] = []
    var at: String? = nil

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.value(.title, default: "Volgorde spreekopdrachten")
        size = (try? c.decode(Int.self, forKey: .size)) ?? 1
        lang = (try? c.decode(FormLang.self, forKey: .lang)) ?? .nl
        groups = try c.value(.groups, default: [])
        at = try? c.decodeIfPresent(String.self, forKey: .at)
    }
}

struct SchoolClass: Codable, Identifiable, Hashable {
    var id: String = newID()
    var name: String = ""
    var students: [Student] = []
    var draw: Draw = Draw()

    init(id: String = newID(), name: String = "", students: [Student] = []) {
        self.id = id; self.name = name; self.students = students
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.value(.id, default: newID())
        name = try c.value(.name, default: "")
        students = try c.value(.students, default: [])
        draw = (try? c.decodeIfPresent(Draw.self, forKey: .draw)) ?? Draw()
    }
}

struct Logo: Codable, Hashable {
    var data: String   // data-URL (image/jpeg of image/png, base64)
    var w: Double
    var h: Double
}

struct AppSettings: Codable, Hashable {
    var rubrics: [Rubric] = []
    var classes: [SchoolClass] = []
    var showLogo: Bool = true
    var logo: Logo? = nil

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rubrics = try c.value(.rubrics, default: [])
        classes = try c.value(.classes, default: [])
        showLogo = try c.value(.showLogo, default: true)
        logo = try? c.decodeIfPresent(Logo.self, forKey: .logo)
    }
}

struct StudentResult: Codable, Hashable {
    var scores: [String: Int] = [:]
    var plus: String = ""
    var work: String = ""
    var feedback: String = ""
    var total: String = ""
    var partners: [String] = []
    var done: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scores = try c.value(.scores, default: [:])
        plus = try c.value(.plus, default: "")
        work = try c.value(.work, default: "")
        feedback = try c.value(.feedback, default: "")
        total = c.flexibleString(.total) ?? ""
        partners = try c.value(.partners, default: [])
        done = try c.value(.done, default: false)
    }

    var hasContent: Bool {
        !scores.isEmpty || !plus.isEmpty || !work.isEmpty || !feedback.isEmpty || !total.isEmpty
    }
}

struct Evaluation: Codable, Identifiable, Hashable {
    var id: String = newID()
    var createdAt: Double = Date().timeIntervalSince1970 * 1000
    var date: String = DateText.todayISO()
    var rubric: Rubric
    var classId: String = ""
    var className: String = ""
    var students: [Student] = []
    var results: [String: StudentResult] = [:]
    var stage: [String] = []
    var useDraw: Bool = false

    init(rubric: Rubric, schoolClass: SchoolClass, date: String) {
        self.rubric = rubric
        self.classId = schoolClass.id
        self.className = schoolClass.name
        self.students = schoolClass.students
        self.date = date
        self.useDraw = !schoolClass.draw.groups.isEmpty
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.value(.id, default: newID())
        createdAt = (try? c.decode(Double.self, forKey: .createdAt)) ?? 0
        date = try c.value(.date, default: DateText.todayISO())
        rubric = try c.decode(Rubric.self, forKey: .rubric)
        classId = try c.value(.classId, default: "")
        className = try c.value(.className, default: "")
        students = try c.decode([Student].self, forKey: .students)
        results = try c.value(.results, default: [:])
        stage = try c.value(.stage, default: [])
        useDraw = try c.value(.useDraw, default: false)
    }

    func result(_ studentID: String) -> StudentResult { results[studentID] ?? StudentResult() }

    func student(_ id: String) -> Student? { students.first { $0.id == id } }

    func isEvaluated(_ studentID: String) -> Bool {
        guard let r = results[studentID] else { return false }
        return r.done || r.hasContent
    }

    func scoredCount(_ studentID: String) -> Int {
        let r = result(studentID)
        return rubric.criteria.filter { r.scores[$0.id] != nil }.count
    }

    var evaluatedCount: Int { students.filter { isEvaluated($0.id) }.count }
}

struct Backup: Codable {
    var app: String = Backup.appName
    var version: Int = 1
    var exportedAt: String = ISO8601DateFormatter.withFractional.string(from: Date())
    var settings: AppSettings
    var evals: [Evaluation]

    static let appName = "rubrics-spreekopdrachten"

    init(settings: AppSettings, evals: [Evaluation]) {
        self.settings = settings; self.evals = evals
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        app = try c.value(.app, default: "")
        version = (try? c.decode(Int.self, forKey: .version)) ?? 1
        exportedAt = try c.value(.exportedAt, default: "")
        settings = (try? c.decode(AppSettings.self, forKey: .settings)) ?? AppSettings()
        // Sessies die niet gelezen kunnen worden, worden overgeslagen.
        let raw = (try? c.decode([FailableDecodable<Evaluation>].self, forKey: .evals)) ?? []
        evals = raw.compactMap { $0.value }
    }
}

struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

// MARK: - Hulpmiddelen

extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key, default def: T) throws -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? def
    }

    /// Leest een veld dat als tekst of als getal opgeslagen kan zijn.
    func flexibleString(_ key: Key) -> String? {
        if let s = try? decode(String.self, forKey: key) { return s }
        if let i = try? decode(Int.self, forKey: key) { return String(i) }
        if let d = try? decode(Double.self, forKey: key) { return String(d) }
        return nil
    }
}

extension Array where Element == String {
    func padded(to count: Int) -> [String] {
        if self.count >= count { return Array(prefix(count)) }
        return self + Array(repeating: "", count: count - self.count)
    }
}

extension ISO8601DateFormatter {
    static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

enum DateText {
    private static let iso: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func todayISO() -> String { iso.string(from: Date()) }
    static func date(_ s: String) -> Date? { iso.date(from: String(s.prefix(10))) }
    static func isoString(_ d: Date) -> String { iso.string(from: d) }

    /// "2026-11-12" -> "12/11/2026"
    static func display(_ s: String, separator: String = "/") -> String {
        let p = s.prefix(10).split(separator: "-")
        guard p.count == 3 else { return s }
        return "\(p[2])\(separator)\(p[1])\(separator)\(p[0])"
    }
}
