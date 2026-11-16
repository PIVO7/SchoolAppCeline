import Foundation
import CoreGraphics
#if os(macOS)
import AppKit
typealias PFont = NSFont
typealias PColor = NSColor
#else
import UIKit
typealias PFont = UIFont
typealias PColor = UIColor
#endif

/// Millimeter naar PDF-punten.
@inline(__always) func mm(_ v: Double) -> CGFloat { CGFloat(v * 72.0 / 25.4) }
@inline(__always) func toMM(_ pt: CGFloat) -> Double { Double(pt) * 25.4 / 72.0 }

/// Een eenvoudige A4-tekenlaag in millimeter, met de oorsprong linksboven
/// (zoals jsPDF). Tekst wordt getekend met de systeemtekstlaag van AppKit/UIKit.
final class PDFCanvas {
    static let pageW = 210.0
    static let pageH = 297.0

    private let data = NSMutableData()
    private let ctx: CGContext
    private(set) var inPage = false

    init() {
        var box = CGRect(x: 0, y: 0, width: mm(Self.pageW), height: mm(Self.pageH))
        let consumer = CGDataConsumer(data: data as CFMutableData)!
        ctx = CGContext(consumer: consumer, mediaBox: &box, nil)!
    }

    func beginPage() {
        if inPage { endPage() }
        ctx.beginPDFPage(nil)
        ctx.saveGState()
        ctx.translateBy(x: 0, y: mm(Self.pageH))
        ctx.scaleBy(x: 1, y: -1)
        #if os(macOS)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        #else
        UIGraphicsPushContext(ctx)
        #endif
        inPage = true
    }

    func endPage() {
        guard inPage else { return }
        #if os(macOS)
        NSGraphicsContext.restoreGraphicsState()
        #else
        UIGraphicsPopContext()
        #endif
        ctx.restoreGState()
        ctx.endPDFPage()
        inPage = false
    }

    func finish() -> Data {
        endPage()
        ctx.closePDF()
        return data as Data
    }

    // MARK: Tekst

    static func font(_ size: Double, bold: Bool = false) -> PFont {
        PFont(name: bold ? "Helvetica-Bold" : "Helvetica", size: CGFloat(size))
            ?? (bold ? PFont.boldSystemFont(ofSize: CGFloat(size)) : PFont.systemFont(ofSize: CGFloat(size)))
    }

    enum Align { case left, center, right }

    private func attributed(_ text: String, size: Double, bold: Bool, color: PColor, align: Align) -> NSAttributedString {
        let p = NSMutableParagraphStyle()
        p.lineBreakMode = .byWordWrapping
        p.alignment = align == .left ? .left : (align == .center ? .center : .right)
        p.lineHeightMultiple = 1.0
        return NSAttributedString(string: text, attributes: [
            .font: Self.font(size, bold: bold),
            .foregroundColor: color,
            .paragraphStyle: p,
        ])
    }

    /// Hoogte (mm) van tekst die binnen `width` mm afgebroken wordt.
    func textHeight(_ text: String, size: Double, bold: Bool = false, width: Double) -> Double {
        guard !text.isEmpty else { return 0 }
        let r = attributed(text, size: size, bold: bold, color: .black, align: .left)
            .boundingRect(with: CGSize(width: mm(width), height: CGFloat.greatestFiniteMagnitude),
                          options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return toMM(ceil(r.height))
    }

    func textWidth(_ text: String, size: Double, bold: Bool = false) -> Double {
        let r = attributed(text, size: size, bold: bold, color: .black, align: .left)
            .boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                          options: [.usesLineFragmentOrigin], context: nil)
        return toMM(ceil(r.width))
    }

    /// Tekst met de bovenkant op `top` (mm), afgebroken binnen `width`.
    func text(_ text: String, x: Double, top: Double, width: Double, size: Double, bold: Bool = false,
              align: Align = .left, color: PColor = .black) {
        guard !text.isEmpty else { return }
        attributed(text, size: size, bold: bold, color: color, align: align)
            .draw(with: CGRect(x: mm(x), y: mm(top), width: mm(width), height: 10_000),
                  options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }

    /// Eén regel tekst met de basislijn op `baseline` (mm), zoals in jsPDF.
    func line(_ s: String, x: Double, baseline: Double, size: Double, bold: Bool = false,
              align: Align = .left, color: PColor = .black) {
        let f = Self.font(size, bold: bold)
        let top = baseline - toMM(f.ascender)
        let w = textWidth(s, size: size, bold: bold) + 1
        let left: Double
        switch align {
        case .left: left = x
        case .center: left = x - w / 2
        case .right: left = x - w
        }
        text(s, x: left, top: top, width: w + 1, size: size, bold: bold, align: .left, color: color)
    }

    /// Kort tekst in met "…" tot ze in `width` mm past.
    func truncate(_ s: String, width: Double, size: Double, bold: Bool = false) -> String {
        if textWidth(s, size: size, bold: bold) <= width { return s }
        var chars = Array(s)
        while !chars.isEmpty && textWidth(String(chars) + "…", size: size, bold: bold) > width {
            chars.removeLast()
        }
        return String(chars) + "…"
    }

    // MARK: Vormen

    func stroke(from a: (Double, Double), to b: (Double, Double), width: Double = 0.2, gray: Double = 0.6) {
        ctx.setStrokeColor(CGColor(gray: gray, alpha: 1))
        ctx.setLineWidth(mm(width))
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: mm(a.0), y: mm(a.1)))
        ctx.addLine(to: CGPoint(x: mm(b.0), y: mm(b.1)))
        ctx.strokePath()
    }

    func polyline(_ pts: [(Double, Double)], width: Double, color: CGColor) {
        guard let first = pts.first else { return }
        ctx.setStrokeColor(color)
        ctx.setLineWidth(mm(width))
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.move(to: CGPoint(x: mm(first.0), y: mm(first.1)))
        for p in pts.dropFirst() { ctx.addLine(to: CGPoint(x: mm(p.0), y: mm(p.1))) }
        ctx.strokePath()
    }

    func rect(x: Double, y: Double, w: Double, h: Double, fill: CGColor? = nil,
              stroke: CGColor? = CGColor(gray: 0.6, alpha: 1), lineWidth: Double = 0.2) {
        let r = CGRect(x: mm(x), y: mm(y), width: mm(w), height: mm(h))
        if let fill { ctx.setFillColor(fill); ctx.fill(r) }
        if let stroke { ctx.setStrokeColor(stroke); ctx.setLineWidth(mm(lineWidth)); ctx.stroke(r) }
    }

    func dot(x: Double, y: Double, r: Double) {
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: mm(x - r), y: mm(y - r), width: mm(2 * r), height: mm(2 * r)))
    }

    func image(_ img: CGImage, x: Double, y: Double, w: Double, h: Double) {
        ctx.saveGState()
        ctx.translateBy(x: mm(x), y: mm(y + h))
        ctx.scaleBy(x: 1, y: -1)
        ctx.interpolationQuality = .high
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: mm(w), height: mm(h)))
        ctx.restoreGState()
    }
}
