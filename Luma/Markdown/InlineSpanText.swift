import LumaCore
import SwiftUI

extension Array where Element == InlineSpan {
    func attributedString(baseFont: Font = .body) -> AttributedString {
        var result = AttributedString()
        for span in self {
            var part = AttributedString(span.text)
            part.font = font(for: span, base: baseFont)
            if span.isCode {
                part.foregroundColor = .pink
            }
            if let link = span.link {
                part.link = link
                part.underlineStyle = .single
            }
            if span.token != nil {
                part.foregroundColor = .accentColor
            }
            if span.isStrikethrough {
                part.strikethroughStyle = .single
            }
            result.append(part)
        }
        return result
    }

    private func font(for span: InlineSpan, base: Font) -> Font {
        var font = span.isCode ? .system(.body, design: .monospaced) : base
        if span.isBold { font = font.bold() }
        if span.isItalic { font = font.italic() }
        return font
    }
}
