import SwiftUI

/// A label above an input, with an optional small tag on the right (like "Optional").
struct FormFieldContainer<Content: View>: View {
    let title: String
    var tag: String?
    var errorMessage: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.app(14, .medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 8)
                if let tag {
                    Text(tag)
                        .font(.app(11, .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.field, in: Capsule())
                }
            }

            content

            if let errorMessage {
                Text(errorMessage)
                    .font(.app(12))
                    .foregroundStyle(Theme.danger)
            }
        }
    }
}

private struct InputBoxModifier: ViewModifier {
    let isFocused: Bool
    let hasError: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1.5)
            )
    }

    private var borderColor: Color {
        if hasError { return Theme.danger }
        return isFocused ? Theme.accent : Color.clear
    }
}

extension View {
    /// The rounded gray box around a text field.
    func inputBox(isFocused: Bool = false, hasError: Bool = false) -> some View {
        modifier(InputBoxModifier(isFocused: isFocused, hasError: hasError))
    }
}

/// Thin purple bar showing how far through the cards the user is.
struct StepProgressBar: View {
    /// 0 to 1
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.field)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 4)
        .animation(.easeInOut(duration: 0.25), value: progress)
        .accessibilityHidden(true)
    }
}

/// Small tip box with a document icon.
struct HintBox: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.accentText)
                .frame(width: 28, height: 28)
                .background(Theme.accentTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            Text(text)
                .font(.app(14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }
}
