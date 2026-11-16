import Foundation
import CoreGraphics

/// Maakt de PDF's volgens sectie 7 van de technische beschrijving (A4 staand, mm, Helvetica).
enum PDFBuilder {
    struct Labels {
        let name, nr, cls, subject, date, with, criteria, total, feedback: String
        let strengths, improve, general: String
        let order, nameCol, groupCol, doneCol: String

        static func of(_ lang: FormLang) -> Labels {
            switch lang {
            case .en:
                return Labels(name: "Name", nr: "Nr.", cls: "Class", subject: "Subject", date: "Date",
                              with: "Together with", criteria: "Criteria", total: "Total", feedback: "Feedback",
                              strengths: "Strengths", improve: "Points to improve", general: "General feedback",
                              order: "Order", nameCol: "Name", groupCol: "Group", doneCol: "Done")
            case .nl:
                return Labels(name: "Naam", nr: "Nr.", cls: "Klas", subject: "Vak", date: "Datum",
                              with: "Samen met", criteria: "Criteria", total: "Totaal", feedback: "Feedback",
                              strengths: "Pluspunten", improve: "Werkpunten", general: "Algemene feedback",
                              order: "Volgorde", nameCol: "Naam", groupCol: "Groep", doneCol: "Gedaan")
            }
        }
    }

    static let margin = 15.0
    static let right = PDFCanvas.pageW - margin
    static let bottom = PDFCanvas.pageH - margin
    static let lineGray = CGColor(gray: 0.6, alpha: 1)
    static let headerFill = CGColor(gray: 0.93, alpha: 1)

    // MARK: Publieke varianten

    /// Eén of meer leerlingen (één pagina per leerling).
    static func evaluation(_ e: Evaluation, students: [Student], settings: AppSettings) -> Data {
        let c = PDFCanvas()
        let logo = settings.showLogo ? LogoImage.cgImage(for: settings) : nil
        for s in students {
            let r = e.result(s.id)
            let partners = r.partners.compactMap { e.student($0)?.name }
            rubricPage(c, rubric: e.rubric, logo: logo, studentName: s.name, nr: String(s.nr),
                       className: e.className, date: DateText.display(e.date), partners: partners, result: r)
        }
        if students.isEmpty {
            rubricPage(c, rubric: e.rubric, logo: logo, studentName: "", nr: "", className: e.className,
                       date: DateText.display(e.date), partners: [], result: nil)
        }
        return c.finish()
    }

    /// Lege rubric om met de hand in te vullen.
    static func blank(_ rubric: Rubric, settings: AppSettings) -> Data {
        let c = PDFCanvas()
        let logo = settings.showLogo ? LogoImage.cgImage(for: settings) : nil
        rubricPage(c, rubric: rubric, logo: logo, studentName: "", nr: "", className: "", date: "", partners: [], result: nil)
        return c.finish()
    }

    // MARK: Rubricformulier

    private static func drawLogo(_ c: PDFCanvas, _ logo: CGImage?) -> Double {
        guard let logo else { return margin }
        var w = 52.0
        var h = w * Double(logo.height) / Double(max(1, logo.width))
        if h > 22 { h = 22; w = h * Double(logo.width) / Double(max(1, logo.height)) }
        c.image(logo, x: margin, y: 12, w: w, h: h)
        return margin + 52 + 8
    }

    private static func field(_ c: PDFCanvas, label: String, value: String, x: Double, end: Double, y: Double) {
        let size = 10.5
        let l = label + ":"
        c.line(l, x: x, baseline: y, size: size, bold: true)
        let vx = x + c.textWidth(l, size: size, bold: true) + 1.5
        c.stroke(from: (vx, y + 1.2), to: (end, y + 1.2), width: 0.2, gray: 0.7)
        if !value.isEmpty {
            c.line(c.truncate(value, width: max(2, end - vx - 1), size: size), x: vx + 0.5, baseline: y, size: size)
        }
    }

    private static func rubricPage(_ c: PDFCanvas, rubric: Rubric, logo: CGImage?, studentName: String, nr: String,
                                   className: String, date: String, partners: [String], result: StudentResult?) {
        let L = Labels.of(rubric.lang)
        c.beginPage()
        let x0 = drawLogo(c, logo)

        field(c, label: L.name, value: studentName, x: x0, end: right, y: 17)
        field(c, label: L.nr, value: nr, x: x0, end: x0 + 21, y: 25)
        let rest = right - (x0 + 26)
        let classEnd = x0 + 26 + rest * 0.55 - 4
        field(c, label: L.cls, value: className, x: x0 + 26, end: classEnd, y: 25)
        field(c, label: L.subject, value: rubric.subject, x: classEnd + 4, end: right, y: 25)
        field(c, label: L.date, value: date, x: x0, end: x0 + 40, y: 33)
        if !partners.isEmpty {
            field(c, label: L.with, value: partners.joined(separator: ", "), x: x0 + 45, end: right, y: 33)
        }

        // Titel
        let width = right - margin
        let title = rubric.title.uppercased()
        let titleTop = 46 - toMM(PDFCanvas.font(14, bold: true).ascender)
        c.text(title, x: margin, top: titleTop, width: width, size: 14, bold: true, align: .center)
        var y = titleTop + c.textHeight(title, size: 14, bold: true, width: width) + 4

        // Rubrictabel
        let n = max(1, rubric.levels.count)
        let firstW = 34.0
        let colW = (width - firstW) / Double(n)
        let pad = 2.6
        let fs = 9.5

        func header() {
            let cells = [L.criteria] + rubric.levels
            let h = cells.enumerated().map { i, t in
                c.textHeight(t, size: 10.5, bold: true, width: (i == 0 ? firstW : colW) - 2 * pad)
            }.max()! + 2 * pad
            var x = margin
            for (i, t) in cells.enumerated() {
                let w = i == 0 ? firstW : colW
                c.rect(x: x, y: y, w: w, h: h, fill: headerFill, stroke: lineGray)
                c.text(t, x: x + pad, top: y + pad, width: w - 2 * pad, size: 10.5, bold: true)
                x += w
            }
            y += h
        }
        header()

        for crit in rubric.criteria {
            let chosen = result?.scores[crit.id]
            let descs = crit.descs.padded(to: n)
            var h = c.textHeight(crit.name, size: fs, bold: true, width: firstW - 2 * pad)
            for (i, d) in descs.enumerated() {
                let extra = chosen == i ? 5.0 : 0
                h = max(h, c.textHeight(d, size: fs, bold: chosen == i, width: colW - 2 * pad - extra))
            }
            h += 2 * pad
            if y + h > bottom {
                c.beginPage(); y = margin; header()
            }
            c.rect(x: margin, y: y, w: firstW, h: h, stroke: lineGray)
            c.text(crit.name, x: margin + pad, top: y + pad, width: firstW - 2 * pad, size: fs, bold: true)
            var x = margin + firstW
            for (i, d) in descs.enumerated() {
                if chosen == i {
                    c.rect(x: x, y: y, w: colW, h: h, fill: LevelColor.pdfFill(index: i, count: n), stroke: lineGray)
                    c.text(d, x: x + pad, top: y + pad, width: colW - 2 * pad - 5, size: fs, bold: true)
                    // Vinkje rechtsboven
                    let cx = x + colW - 5.2, cy = y + 2.4
                    c.polyline([(cx, cy + 1.6), (cx + 1.3, cy + 2.9), (cx + 3.6, cy)], width: 0.8,
                               color: CGColor(gray: 0, alpha: 1))
                } else {
                    c.rect(x: x, y: y, w: colW, h: h, stroke: lineGray)
                    c.text(d, x: x + pad, top: y + pad, width: colW - 2 * pad, size: fs, color: .init(white: 0.15, alpha: 1))
                }
                x += colW
            }
            y += h
        }

        // Totaal
        if rubric.showTotal {
            let bw = 62.0, bh = 12.0
            if y + 6 + bh > bottom { c.beginPage(); y = margin - 6 }
            let bx = right - bw, by = y + 6
            c.rect(x: bx, y: by, w: bw, h: bh, stroke: CGColor(gray: 0.35, alpha: 1), lineWidth: 0.3)
            let base = by + 7.8
            c.line(L.total + ":", x: bx + 3, baseline: base, size: 11, bold: true)
            let maxText = "/ " + (rubric.totalMax.isEmpty ? "20" : rubric.totalMax)
            c.line(maxText, x: bx + bw - 3, baseline: base, size: 11, align: .right)
            let maxW = c.textWidth(maxText, size: 11)
            let score = result?.total.trimmingCharacters(in: .whitespaces) ?? ""
            if score.isEmpty {
                let lx = bx + 3 + c.textWidth(L.total + ":", size: 11, bold: true) + 2
                c.stroke(from: (lx, base + 0.8), to: (bx + bw - 3 - maxW - 2, base + 0.8), width: 0.2, gray: 0.5)
            } else {
                c.line(score, x: bx + bw - 3 - maxW - 2, baseline: base, size: 14, bold: true, align: .right)
            }
            y = by + bh
        }

        feedbackBlock(c, L: L, result: result, y: y + 6)
        c.endPage()
    }

    /// Haalt opsommingstekens weg en laat lege regels vallen.
    static func bullets(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { line -> String in
                var s = line.trimmingCharacters(in: .whitespaces)
                while let f = s.first, "-*•·–".contains(f) { s.removeFirst(); s = s.trimmingCharacters(in: .whitespaces) }
                return s
            }
            .filter { !$0.isEmpty }
    }

    private static func feedbackBlock(_ c: PDFCanvas, L: Labels, result: StudentResult?, y startY: Double) {
        let width = right - margin
        let gap = 4.0
        let half = (width - gap) / 2
        let fs = 9.5
        let lists = [bullets(result?.plus ?? ""), bullets(result?.work ?? "")]
        let general = result?.feedback ?? ""

        func listHeight(_ items: [String]) -> Double {
            items.reduce(0) { $0 + c.textHeight($1, size: fs, width: half - 3 - 4 - 3) + 0.8 }
        }
        let topH = max(26, (lists.map(listHeight).max() ?? 0) + 13)
        let genH = max(20, c.textHeight(general, size: 10, width: width - 6) + 12)
        let headingH = 6.0
        var y = startY
        if y + headingH + topH + 4 + genH > bottom {
            c.beginPage(); y = margin
        }

        c.line(L.feedback, x: margin, baseline: y + 4, size: 11, bold: true)
        y += headingH

        let titles = [L.strengths, L.improve]
        for k in 0..<2 {
            let bx = margin + Double(k) * (half + gap)
            c.rect(x: bx, y: y, w: half, h: topH, stroke: CGColor(gray: 0.5, alpha: 1), lineWidth: 0.25)
            c.line(titles[k], x: bx + 3, baseline: y + 5.5, size: 10, bold: true)
            var ty = y + 8.5
            for item in lists[k] {
                let h = c.textHeight(item, size: fs, width: half - 3 - 4 - 3)
                c.dot(x: bx + 4.2, y: ty + 1.8, r: 0.55)
                c.text(item, x: bx + 3 + 4, top: ty, width: half - 3 - 4 - 3, size: fs)
                ty += h + 0.8
            }
        }
        y += topH + 4

        c.rect(x: margin, y: y, w: width, h: genH, stroke: CGColor(gray: 0.5, alpha: 1), lineWidth: 0.25)
        c.line(L.general, x: margin + 3, baseline: y + 5.5, size: 10, bold: true)
        c.text(general, x: margin + 3, top: y + 8.5, width: width - 6, size: 10)
    }

    // MARK: Lotingslijst

    static func drawList(_ cls: SchoolClass, settings: AppSettings) -> Data {
        let d = cls.draw
        let L = Labels.of(d.lang)
        let c = PDFCanvas()
        let logo = settings.showLogo ? LogoImage.cgImage(for: settings) : nil
        let byID = Dictionary(cls.students.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let groups = d.groups.map { $0.compactMap { byID[$0]?.name } }.filter { !$0.isEmpty }

        c.beginPage()
        let x0 = drawLogo(c, logo)
        let dateText = DateText.display(d.at.map { String($0.prefix(10)) } ?? DateText.todayISO())
        for (label, value, y) in [(L.cls, cls.name, 19.0), (L.date, dateText, 27.0)] {
            let l = label + ": "
            c.line(l, x: x0, baseline: y, size: 11, bold: true)
            c.line(value, x: x0 + c.textWidth(l, size: 11, bold: true), baseline: y, size: 11)
        }
        let width = right - margin
        let title = (d.title.isEmpty ? "Volgorde spreekopdrachten" : d.title).uppercased()
        let titleTop = 44 - toMM(PDFCanvas.font(14, bold: true).ascender)
        c.text(title, x: margin, top: titleTop, width: width, size: 14, bold: true, align: .center)
        var y = titleTop + c.textHeight(title, size: 14, bold: true, width: width) + 5

        let wOrder = 24.0, wDone = 22.0
        let wName = width - wOrder - wDone
        let pad = 2.6
        let fs = 11.0

        func header() {
            let h = 8.0
            let titles = [L.order, d.size > 1 ? L.groupCol : L.nameCol, L.doneCol]
            let widths = [wOrder, wName, wDone]
            var x = margin
            for i in 0..<3 {
                c.rect(x: x, y: y, w: widths[i], h: h, fill: headerFill, stroke: lineGray)
                c.text(titles[i], x: x + pad, top: y + 1.8, width: widths[i] - 2 * pad, size: fs, bold: true,
                       align: i == 1 ? .left : .center)
                x += widths[i]
            }
            y += h
        }
        header()

        for (i, g) in groups.enumerated() {
            let names = g.joined(separator: "\n")
            let h = max(9, c.textHeight(names, size: fs, width: wName - 2 * pad) + 2 * pad)
            if y + h > bottom { c.beginPage(); y = margin; header() }
            c.rect(x: margin, y: y, w: wOrder, h: h, stroke: lineGray)
            c.text("\(i + 1)", x: margin, top: y + pad, width: wOrder, size: fs, bold: true, align: .center)
            c.rect(x: margin + wOrder, y: y, w: wName, h: h, stroke: lineGray)
            c.text(names, x: margin + wOrder + pad, top: y + pad, width: wName - 2 * pad, size: fs)
            let dx = margin + wOrder + wName
            c.rect(x: dx, y: y, w: wDone, h: h, stroke: lineGray)
            c.rect(x: dx + (wDone - 4.5) / 2, y: y + (h - 4.5) / 2, w: 4.5, h: 4.5,
                   stroke: CGColor(gray: 0.2, alpha: 1), lineWidth: 0.3)
            y += h
        }
        return c.finish()
    }
}
