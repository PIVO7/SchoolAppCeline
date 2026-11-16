import SwiftUI

/// Witte kaart met rand, zoals in de huidige tool.
struct Card<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title).font(.headline).foregroundStyle(Theme.text)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
            .contentShape(Rectangle())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var small = false
    var color: Color = Theme.text
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(small ? .callout.weight(.medium) : .body.weight(.medium))
            .padding(.horizontal, small ? 10 : 14)
            .frame(minHeight: small ? 32 : 40)
            .background(Color.white.opacity(configuration.isPressed ? 0.6 : 1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
            .foregroundStyle(color)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static var secondarySmall: SecondaryButtonStyle { SecondaryButtonStyle(small: true) }
    static var danger: SecondaryButtonStyle { SecondaryButtonStyle(small: true, color: Theme.danger) }
}

/// Niveauknop: gekleurde rand en tekst, of volledig ingekleurd als hij gekozen is.
struct LevelButton: View {
    let title: String
    let index: Int
    let count: Int
    let selected: Bool
    var compact = false
    let action: () -> Void

    var body: some View {
        let color = LevelColor.color(index: index, count: count)
        Button(action: action) {
            Text(title.isEmpty ? "–" : title)
                .font(.callout.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: compact ? 32 : 38)
                .padding(.horizontal, 6)
                .foregroundStyle(selected ? Color.white : color)
                .background(selected ? color : Color.white, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(selected ? 1 : 0.55), lineWidth: 1.2))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Eenvoudige "flow"-layout voor de leerlingen-chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

/// Bolletje in de kleur van een niveau.
struct LevelDot: View {
    let index: Int?
    let count: Int
    var body: some View {
        Circle()
            .fill(index.map { LevelColor.color(index: $0, count: count) } ?? Color.clear)
            .overlay(Circle().stroke(index == nil ? Theme.border : Color.clear))
            .frame(width: 11, height: 11)
    }
}

struct ToastView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.callout)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.black.opacity(0.82), in: Capsule())
            .foregroundStyle(.white)
            .padding(.bottom, 24)
    }
}

extension View {
    /// Tekstveld met een rand, zoals in de huidige tool.
    func fieldStyle() -> some View {
        self
            .textFieldStyle(.plain)
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
    }
}
