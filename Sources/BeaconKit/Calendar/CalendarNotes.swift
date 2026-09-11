import Foundation
import SwiftSoup

/// Converts provider HTML into inert readable text. Parsing never loads URLs or
/// executes markup, and calendar source data is never written back.
public enum CalendarNotes {
    /// Separate only a paired Google-generated block; preserve ordinary prose.
    public static func presentation(_ text: String) -> (body: String, meetingDetails: String) {
        let lines = text.components(separatedBy: .newlines)
        let markers = lines.indices.filter { index in
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            return line.count >= 20 && line.contains("~") && line.allSatisfy { "-:~".contains($0) }
        }
        guard let first = markers.first, let last = markers.dropFirst().first, last > first,
              lines[(first + 1)..<last].contains(where: { $0.contains("https://meet.google.com/") }) else {
            return (text, "")
        }
        let details = lines[(first + 1)..<last].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let body = (Array(lines[..<first]) + Array(lines[(last + 1)...]))
            .joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (body, details)
    }

    public static func plainText(_ source: String) -> String {
        let htmlTag = #"(?i)</?(?:html|body|p|div|br|a|span|ul|ol|li|b|strong|i|em|table|tr|td|h[1-6]|pre|blockquote|script|style|img)\b[^>]*>"#
        guard source.range(of: htmlTag, options: .regularExpression) != nil,
              let document = try? SwiftSoup.parseBodyFragment(source),
              let body = document.body() else { return source }
        let blocks: Set<String> = ["p", "div", "ul", "ol", "li", "table", "tr", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "blockquote"]
        var result = ""
        var stack: [(Node, Bool)] = [(body, false)]
        func newline() {
            if !result.isEmpty && !result.hasSuffix("\n") && !result.hasSuffix("• ") { result += "\n" }
        }
        while let (node, leaving) = stack.popLast() {
            if let text = node as? TextNode {
                result += text.getWholeText()
                continue
            }
            guard let element = node as? Element else { continue }
            let tag = element.tagName().lowercased()
            if ["script", "style", "iframe", "object"].contains(tag) { continue }
            if leaving {
                if tag == "a", let href = try? element.attr("href"),
                   let url = URL(string: href), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                   let label = try? element.text(), label != href {
                    result += " (\(href))"
                }
                if blocks.contains(tag) { newline() }
                if tag == "td" || tag == "th" { result += " " }
                continue
            }
            if tag == "br" { result += "\n"; continue }
            if blocks.contains(tag) { newline() }
            if tag == "li" { result += "• " }
            if tag == "img", let alt = try? element.attr("alt") { result += alt }
            stack.append((node, true))
            for child in node.getChildNodes().reversed() { stack.append((child, false)) }
        }
        return result.replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
