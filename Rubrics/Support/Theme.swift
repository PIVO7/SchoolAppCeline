import SwiftUI
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum Theme {
    static let background = Color(hex: 0xF6F5F2)
    static let card = Color.white
    static let border = Color(hex: 0xE2DFD8)
    static let text = Color(hex: 0x1D2327)
    static let muted = Color(hex: 0x69737A)
    static let accent = Color(hex: 0x0F6B63)
    static let danger = Color(hex: 0xB3261E)
    static let partial = Color(hex: 0xFFF4CC)
    static let partialBorder = Color(hex: 0xE6C65C)
    static let doneFill = Color(hex: 0xE5F3E8)
    static let doneBorder = Color(hex: 0x9CCDA6)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// Kleur van een niveau volgens zijn positie: eerste = groen (135),
/// midden = oranje (38), laatste = rood (4), lineair daartussen.
enum LevelColor {
    static func hue(index: Int, count: Int) -> Double {
        guard count > 1 else { return 135 }
        let t = Double(index) / Double(count - 1)
        if t <= 0.5 { return 135 + (38 - 135) * (t / 0.5) }
        return 38 + (4 - 38) * ((t - 0.5) / 0.5)
    }

    static func rgb(index: Int, count: Int, saturation: Double = 0.62, lightness: Double = 0.38) -> (Double, Double, Double) {
        hslToRGB(h: hue(index: index, count: count), s: saturation, l: lightness)
    }

    static func color(index: Int, count: Int) -> Color {
        let (r, g, b) = rgb(index: index, count: count)
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    /// Lichte vulling voor de PDF (HSL 55 %, 86 %).
    static func pdfFill(index: Int, count: Int) -> CGColor {
        let (r, g, b) = rgb(index: index, count: count, saturation: 0.55, lightness: 0.86)
        return CGColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    static func hslToRGB(h: Double, s: Double, l: Double) -> (Double, Double, Double) {
        let c = (1 - abs(2 * l - 1)) * s
        let hp = h / 60
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        var (r, g, b) = (0.0, 0.0, 0.0)
        switch hp {
        case 0..<1: (r, g, b) = (c, x, 0)
        case 1..<2: (r, g, b) = (x, c, 0)
        case 2..<3: (r, g, b) = (0, c, x)
        case 3..<4: (r, g, b) = (0, x, c)
        case 4..<5: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        let m = l - c / 2
        return (r + m, g + m, b + m)
    }
}

// MARK: - Logo

enum LogoImage {
    /// Het logo dat op de PDF komt: het eigen logo, anders het schoollogo uit de Assets (indien aanwezig).
    static func cgImage(for settings: AppSettings) -> CGImage? {
        if let logo = settings.logo, let img = decode(dataURL: logo.data) { return img }
        return defaultLogo()
    }

    static func defaultLogo() -> CGImage? {
        #if os(macOS)
        guard let img = NSImage(named: "SchoolLogo") else { return nil }
        var rect = CGRect(origin: .zero, size: img.size)
        return img.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #else
        return UIImage(named: "SchoolLogo")?.cgImage
        #endif
    }

    static func decode(dataURL: String) -> CGImage? {
        let base64: Substring
        if let comma = dataURL.firstIndex(of: ",") { base64 = dataURL[dataURL.index(after: comma)...] } else { base64 = Substring(dataURL) }
        guard let data = Data(base64Encoded: String(base64), options: .ignoreUnknownCharacters),
              let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    /// Verkleint een gekozen afbeelding tot max. 640 px breed en bewaart ze als JPEG (0,85).
    static func makeLogo(from data: Data) -> Logo? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let full = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        let scale = min(1, 640 / Double(full.width))
        let w = Int((Double(full.width) * scale).rounded())
        let h = Int((Double(full.height) * scale).rounded())
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        // Witte achtergrond, want JPEG kent geen transparantie.
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.interpolationQuality = .high
        ctx.draw(full, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let scaled = ctx.makeImage() else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, scaled, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        let b64 = (out as Data).base64EncodedString()
        return Logo(data: "data:image/jpeg;base64,\(b64)", w: Double(w), h: Double(h))
    }
}
