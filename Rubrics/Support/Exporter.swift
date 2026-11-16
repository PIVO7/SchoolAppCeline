import Foundation
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Geeft een gemaakt bestand (PDF of back-up) aan de gebruiker:
/// op de Mac via een bewaarvenster, op de iPad via het deelmenu (afdrukken, Bewaar in Bestanden).
@MainActor
enum Exporter {
    static func export(_ data: Data, filename: String, type: UTType, openAfterSaving: Bool = false) {
        let name = Filename.clean(filename)
        #if os(macOS)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.allowedContentTypes = [type]
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
                if openAfterSaving { NSWorkspace.shared.open(url) }
            } catch {
                NSAlert(error: error).runModal()
            }
        }
        #else
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do { try data.write(to: url, options: .atomic) } catch { return }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let root = scene.keyWindow?.rootViewController ?? scene.windows.first?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        if let pop = vc.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        top.present(vc, animated: true)
        #endif
    }

    static func exportPDF(_ data: Data, filename: String) {
        export(data, filename: filename.hasSuffix(".pdf") ? filename : filename + ".pdf", type: .pdf, openAfterSaving: true)
    }
}
