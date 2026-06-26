import Foundation
import LumaCore

enum InlineSpanPango {
    static func markup(for spans: [InlineSpan]) -> String {
        spans.map(markup(for:)).joined()
    }

    private static func markup(for span: InlineSpan) -> String {
        var inner = StyledTextPango.escape(span.text)
        if span.isCode {
            inner = "<span foreground=\"#e06c9f\"><tt>\(inner)</tt></span>"
        }
        if span.isStrikethrough {
            inner = "<s>\(inner)</s>"
        }
        if span.isItalic {
            inner = "<i>\(inner)</i>"
        }
        if span.isBold {
            inner = "<b>\(inner)</b>"
        }
        if span.token != nil {
            inner = "<span foreground=\"#3584e4\">\(inner)</span>"
        }
        if let link = span.link {
            inner = "<a href=\"\(StyledTextPango.escape(link.absoluteString))\">\(inner)</a>"
        }
        return inner
    }
}
