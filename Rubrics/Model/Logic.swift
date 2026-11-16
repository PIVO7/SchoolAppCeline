import Foundation

// Kernlogica uit sectie 6 van de technische beschrijving.

enum StudentParser {
    /// Leest een geplakte namenlijst. "3 Emma Peeters", "3. Emma", "3) Emma",
    /// "3<tab>Emma" of gewoon "Emma". Een leerling met exact dezelfde naam als
    /// iemand in `pool` krijgt diens id terug (elke id maar één keer).
    static func parse(_ text: String, pool: [Student]) -> [Student] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.replacingOccurrences(of: "\t", with: " ").trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var used = Set<String>()
        var result: [Student] = []
        let regex = try! NSRegularExpression(pattern: #"^(\d{1,3})[\s.):\-]+(.+)$"#)

        for (i, line) in lines.enumerated() {
            var nr = i + 1
            var name = line
            let range = NSRange(line.startIndex..., in: line)
            if let m = regex.firstMatch(in: line, range: range),
               let r1 = Range(m.range(at: 1), in: line),
               let r2 = Range(m.range(at: 2), in: line) {
                nr = Int(line[r1]) ?? nr
                name = String(line[r2]).trimmingCharacters(in: .whitespaces)
            }
            let id: String
            if let existing = pool.first(where: { $0.name == name && !used.contains($0.id) }) {
                id = existing.id
            } else {
                id = newID()
            }
            used.insert(id)
            result.append(Student(id: id, nr: nr, name: name))
        }
        return result
    }

    static func text(for students: [Student]) -> String {
        students.map { "\($0.nr) \($0.name)" }.joined(separator: "\n")
    }
}

enum Lottery {
    /// Fisher–Yates met de systeemgenerator (cryptografisch veilig).
    static func shuffle(_ ids: [String]) -> [String] {
        var a = ids
        var rng = SystemRandomNumberGenerator()
        if a.count > 1 {
            for i in stride(from: a.count - 1, through: 1, by: -1) {
                let j = Int.random(in: 0...i, using: &rng)
                a.swapAt(i, j)
            }
        }
        return a
    }

    static func makeGroups(_ ids: [String], size: Int) -> [[String]] {
        let size = max(1, size)
        var groups: [[String]] = stride(from: 0, to: ids.count, by: size).map {
            Array(ids[$0..<min($0 + size, ids.count)])
        }
        if size > 1, groups.count > 1, let last = groups.last, last.count < size {
            let rest = groups.removeLast()
            if size > 2 && rest.count >= Int((Double(size) / 2).rounded(.up)) {
                groups.append(rest)
            } else {
                var gi = groups.count - 1
                for id in rest {
                    groups[gi].append(id)
                    gi = gi == 0 ? groups.count - 1 : gi - 1
                }
            }
        }
        return groups
    }

    /// Waarschuwing als de klaslijst veranderd is na de loting.
    static func mismatch(for cls: SchoolClass) -> (missing: Int, gone: Int) {
        let drawn = Set(cls.draw.groups.flatMap { $0 })
        let current = Set(cls.students.map(\.id))
        return (current.subtracting(drawn).count, drawn.subtracting(current).count)
    }
}

extension Evaluation {
    /// Groepjes uit de loting van de klas, vertaald naar de leerlingen van deze sessie.
    func drawGroups(using cls: SchoolClass?) -> [[Student]] {
        guard let cls, !cls.draw.groups.isEmpty else { return [] }
        let byID = Dictionary(students.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var seen = Set<String>()
        var groups: [[Student]] = []
        for g in cls.draw.groups {
            let members = g.compactMap { id -> Student? in
                guard !seen.contains(id), let s = byID[id] else { return nil }
                seen.insert(id)
                return s
            }
            if !members.isEmpty { groups.append(members) }
        }
        let leftovers = students.filter { !seen.contains($0.id) }.sorted { $0.nr < $1.nr }
        groups.append(contentsOf: leftovers.map { [$0] })
        return groups
    }

    func nextDrawGroup(using cls: SchoolClass?) -> [Student]? {
        drawGroups(using: cls).first { group in group.contains { !result($0.id).done } }
    }

    enum ChipState { case normal, partial, done, stage }

    func chipState(_ id: String) -> ChipState {
        if stage.contains(id) { return .stage }
        let r = result(id)
        let scored = scoredCount(id)
        if r.done && (scored == rubric.criteria.count || scored == 0) { return .done }
        if scored > 0 { return .partial }
        return .normal
    }

    var sortedStudents: [Student] { students.sorted { ($0.nr, $0.name) < ($1.nr, $1.name) } }

    // MARK: Mutaties

    mutating func toggleScore(student: String, criterion: String, level: Int) {
        var r = result(student)
        if r.scores[criterion] == level { r.scores[criterion] = nil } else { r.scores[criterion] = level }
        results[student] = r
    }

    mutating func setGroupScore(criterion: String, level: Int) {
        for id in stage {
            var r = result(id)
            r.scores[criterion] = level
            results[id] = r
        }
    }

    func groupLevel(criterion: String) -> Int? {
        let levels = stage.map { result($0).scores[criterion] }
        guard let first = levels.first, let f = first, levels.allSatisfy({ $0 == f }) else { return nil }
        return f
    }

    mutating func toggleStage(_ id: String) {
        if let i = stage.firstIndex(of: id) { stage.remove(at: i) } else { stage.append(id) }
    }

    /// Markeert iedereen op het podium als klaar. Geeft terug hoeveel leerlingen
    /// niet volledig ingevuld zijn.
    @discardableResult
    mutating func finishStage() -> Int {
        var incomplete = 0
        for id in stage {
            var r = result(id)
            r.done = true
            r.partners = stage.filter { $0 != id }
            results[id] = r
            if scoredCount(id) < rubric.criteria.count { incomplete += 1 }
        }
        stage = []
        return incomplete
    }
}

enum Filename {
    static func clean(_ s: String) -> String {
        let bad = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return s.components(separatedBy: bad).joined().trimmingCharacters(in: .whitespaces)
    }
}
