import SwiftUI

/// The purple "stacked card with a checkmark" mark shown on the sign up and log in screens.
struct AppLogo: View {
    var size: CGFloat = 56

    var body: some View {
        LogoShape()
            .stroke(
                Theme.accentText,
                style: StrokeStyle(lineWidth: size * 0.07, lineCap: .round, lineJoin: .round)
            )
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Drawn in a unit square: two short bars (the stack), the card, and a checkmark.
private struct LogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }

        var path = Path()

        // Top of the stack: two bars that get wider toward the card.
        path.move(to: point(0.32, 0.06))
        path.addLine(to: point(0.68, 0.06))
        path.move(to: point(0.20, 0.22))
        path.addLine(to: point(0.80, 0.22))

        // The card.
        let card = CGRect(
            x: rect.minX + 0.02 * rect.width,
            y: rect.minY + 0.36 * rect.height,
            width: 0.96 * rect.width,
            height: 0.60 * rect.height
        )
        path.addRoundedRect(
            in: card,
            cornerSize: CGSize(width: 0.14 * rect.width, height: 0.14 * rect.width)
        )

        // The checkmark inside the card.
        path.move(to: point(0.32, 0.66))
        path.addLine(to: point(0.45, 0.78))
        path.addLine(to: point(0.68, 0.54))

        return path
    }
}

#Preview("Logo") {
    AppLogo(size: 80)
        .padding(40)
        .background(Theme.background)
}
