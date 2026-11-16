import Foundation
import Observation
import SwiftUI

/// Houdt alle gegevens in het geheugen en bewaart ze automatisch als JSON-bestanden:
///   <Application Support>/Rubrics/settings.json
///   <Application Support>/Rubrics/evals/<id>.json
/// Elke wijziging wordt na een korte vertraging weggeschreven (debounce), per bestand.
@MainActor
@Observable
final class AppStore {
    enum SaveStatus: Equatable { case idle, saving, saved, failed(String) }

    var settings = AppSettings() {
        didSet { if !isLoading { scheduleSave(.settings) } }
    }
    private(set) var evals: [String: Evaluation] = [:]
    var saveStatus: SaveStatus = .idle
    var toast: String? = nil

    @ObservationIgnored private var isLoading = false
    @ObservationIgnored private var pending: [SaveKey: Task<Void, Never>] = [:]
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    enum SaveKey: Hashable { case settings, eval(String) }

    let directory: URL

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Rubrics", isDirectory: true)
        self.directory = base
        try? FileManager.default.createDirectory(at: evalsDirectory, withIntermediateDirectories: true)
        load()
    }

    private var settingsURL: URL { directory.appendingPathComponent("settings.json") }
    private var evalsDirectory: URL { directory.appendingPathComponent("evals", isDirectory: true) }
    private func evalURL(_ id: String) -> URL { evalsDirectory.appendingPathComponent("\(id).json") }

    // MARK: Laden

    private func load() {
        isLoading = true
        defer { isLoading = false }
        let dec = JSONDecoder()
        if let data = try? Data(contentsOf: settingsURL),
           let s = try? dec.decode(AppSettings.self, from: data) {
            settings = s
        }
        let files = (try? FileManager.default.contentsOfDirectory(at: evalsDirectory, includingPropertiesForKeys: nil)) ?? []
        var loaded: [String: Evaluation] = [:]
        for url in files where url.pathExtension == "json" {
            if let data = try? Data(contentsOf: url), let e = try? dec.decode(Evaluation.self, from: data) {
                loaded[e.id] = e
            }
        }
        evals = loaded
    }

    // MARK: Bewaren

    func scheduleSave(_ key: SaveKey, delay: Double = 0.5) {
        pending[key]?.cancel()
        saveStatus = .saving
        pending[key] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.write(key)
            self.pending[key] = nil
            if self.pending.isEmpty, case .saving = self.saveStatus { self.saveStatus = .saved }
        }
    }

    /// Schrijft alles wat nog wacht meteen weg (bv. als de app naar de achtergrond gaat).
    func flushAll() {
        for (key, task) in pending {
            task.cancel()
            write(key)
        }
        pending = [:]
        if case .saving = saveStatus { saveStatus = .saved }
    }

    private func write(_ key: SaveKey) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        do {
            switch key {
            case .settings:
                try enc.encode(settings).write(to: settingsURL, options: .atomic)
            case .eval(let id):
                if let e = evals[id] {
                    try enc.encode(e).write(to: evalURL(id), options: .atomic)
                }
            }
        } catch {
            saveStatus = .failed(error.localizedDescription)
        }
    }

    // MARK: Beoordelingen

    var sortedEvals: [Evaluation] {
        evals.values.sorted { ($0.date, $0.createdAt) > ($1.date, $1.createdAt) }
    }

    func eval(_ id: String) -> Evaluation? { evals[id] }

    func updateEval(_ id: String, delay: Double = 0.5, _ change: (inout Evaluation) -> Void) {
        guard var e = evals[id] else { return }
        change(&e)
        evals[id] = e
        scheduleSave(.eval(id), delay: delay)
    }

    func addEval(_ e: Evaluation) {
        evals[e.id] = e
        scheduleSave(.eval(e.id), delay: 0.1)
    }

    func deleteEval(_ id: String) {
        pending[.eval(id)]?.cancel()
        pending[.eval(id)] = nil
        evals[id] = nil
        try? FileManager.default.removeItem(at: evalURL(id))
    }

    func schoolClass(_ id: String) -> SchoolClass? { settings.classes.first { $0.id == id } }

    // MARK: Back-up

    func makeBackup() throws -> Data {
        flushAll()
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(Backup(settings: settings, evals: Array(evals.values)))
    }

    static func readBackup(_ data: Data) -> Backup? {
        guard let b = try? JSONDecoder().decode(Backup.self, from: data), b.app == Backup.appName else { return nil }
        return b
    }

    /// Voegt een back-up samen met wat er al staat. Wist nooit iets.
    func merge(_ b: Backup) {
        var s = settings
        for r in b.settings.rubrics {
            if let i = s.rubrics.firstIndex(where: { $0.id == r.id }) { s.rubrics[i] = r } else { s.rubrics.append(r) }
        }
        for c in b.settings.classes {
            if let i = s.classes.firstIndex(where: { $0.id == c.id }) { s.classes[i] = c } else { s.classes.append(c) }
        }
        s.showLogo = b.settings.showLogo
        if let logo = b.settings.logo { s.logo = logo }
        settings = s
        for e in b.evals {
            evals[e.id] = e
            scheduleSave(.eval(e.id), delay: 0.2)
        }
    }

    // MARK: Melding

    func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { self?.toast = nil }
        }
    }
}
