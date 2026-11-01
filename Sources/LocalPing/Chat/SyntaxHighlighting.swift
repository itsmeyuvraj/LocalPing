import SwiftUI
import AppKit

public enum SyntaxLanguage: String, CaseIterable, Sendable {
    case swift = "swift"
    case python = "python"
    case javascript = "javascript"
    case json = "json"
    case bash = "bash"
    case sql = "sql"
    case markdown = "markdown"
    case html = "html"
    case plain = "text"

    public var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .json: return "JSON"
        case .bash: return "Bash / Shell"
        case .sql: return "SQL"
        case .markdown: return "Markdown"
        case .html: return "HTML"
        case .plain: return "Plain Text"
        }
    }

    public var badgeColor: Color {
        switch self {
        case .swift: return Color(red: 0.98, green: 0.45, blue: 0.26)
        case .python: return Color(red: 0.22, green: 0.46, blue: 0.67)
        case .javascript: return Color(red: 0.97, green: 0.87, blue: 0.12)
        case .json: return Color(red: 0.30, green: 0.75, blue: 0.45)
        case .bash: return Color(red: 0.35, green: 0.70, blue: 0.85)
        case .sql: return Color(red: 0.85, green: 0.35, blue: 0.75)
        case .markdown: return Color(red: 0.40, green: 0.60, blue: 0.95)
        case .html: return Color(red: 0.92, green: 0.35, blue: 0.20)
        case .plain: return Color.secondary
        }
    }

    public static func match(_ string: String?) -> SyntaxLanguage {
        guard let s = string?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            return .plain
        }
        switch s {
        case "swift": return .swift
        case "py", "python": return .python
        case "js", "ts", "javascript", "typescript", "jsx", "tsx": return .javascript
        case "json": return .json
        case "sh", "bash", "zsh", "shell": return .bash
        case "sql": return .sql
        case "md", "markdown": return .markdown
        case "html", "xml", "svg": return .html
        default: return .plain
        }
    }
}

// MARK: - Tokenizer

public enum CodeTokenType: Sendable {
    case keyword
    case type
    case string
    case number
    case comment
    case boolean
    case plain
}

public struct CodeToken: Sendable {
    public let text: String
    public let type: CodeTokenType
}

public final class SimpleSyntaxHighlighter: Sendable {
    public static let shared = SimpleSyntaxHighlighter()

    private let swiftKeywords: Set<String> = [
        "import", "let", "var", "func", "class", "struct", "enum", "protocol",
        "extension", "public", "private", "fileprivate", "internal", "open",
        "guard", "if", "else", "switch", "case", "default", "for", "while",
        "return", "throw", "throws", "try", "await", "async", "self", "Self",
        "init", "deinit", "mutating", "nonisolated", "actor", "some", "any",
        "where", "in", "as", "is", "weak", "unowned", "override"
    ]

    private let pythonKeywords: Set<String> = [
        "import", "from", "def", "class", "return", "if", "elif", "else",
        "for", "while", "in", "try", "except", "finally", "with", "as",
        "lambda", "yield", "raise", "assert", "async", "await", "pass",
        "self", "global", "nonlocal", "not", "and", "or", "is"
    ]

    private let jsKeywords: Set<String> = [
        "import", "export", "from", "const", "let", "var", "function",
        "class", "return", "if", "else", "switch", "case", "default",
        "for", "while", "try", "catch", "finally", "throw", "async",
        "await", "new", "typeof", "instanceof", "interface", "type",
        "extends", "implements", "this", "super", "yield", "void"
    ]

    private let bashKeywords: Set<String> = [
        "if", "then", "else", "elif", "fi", "case", "esac", "for", "while",
        "do", "done", "in", "function", "echo", "export", "source", "local",
        "return", "exit", "sudo", "cd", "ls", "grep", "cat", "mkdir", "rm"
    ]

    private let sqlKeywords: Set<String> = [
        "SELECT", "FROM", "WHERE", "INSERT", "INTO", "UPDATE", "DELETE",
        "JOIN", "INNER", "LEFT", "RIGHT", "OUTER", "ON", "GROUP", "BY",
        "ORDER", "HAVING", "LIMIT", "CREATE", "TABLE", "DROP", "ALTER",
        "INDEX", "AND", "OR", "NOT", "IN", "IS", "NULL", "AS", "DISTINCT",
        "UNION", "VALUES", "SET", "PRIMARY", "KEY", "FOREIGN", "REFERENCES"
    ]

    public func highlightLine(_ line: String, language: SyntaxLanguage) -> [CodeToken] {
        guard !line.isEmpty else { return [] }

        // Fast check for single-line comments
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if (language == .swift || language == .javascript) && trimmed.hasPrefix("//") {
            return [CodeToken(text: line, type: .comment)]
        }
        if (language == .python || language == .bash) && trimmed.hasPrefix("#") {
            return [CodeToken(text: line, type: .comment)]
        }
        if language == .sql && trimmed.hasPrefix("--") {
            return [CodeToken(text: line, type: .comment)]
        }

        var tokens: [CodeToken] = []
        var currentIndex = line.startIndex

        while currentIndex < line.endIndex {
            let char = line[currentIndex]

            // Check for string literal ("..." or '...')
            if char == "\"" || char == "'" || char == "`" {
                let quote = char
                var endIndex = line.index(after: currentIndex)
                var escaped = false

                while endIndex < line.endIndex {
                    let c = line[endIndex]
                    if c == "\\" {
                        escaped.toggle()
                    } else if c == quote && !escaped {
                        endIndex = line.index(after: endIndex)
                        break
                    } else {
                        escaped = false
                    }
                    endIndex = line.index(after: endIndex)
                }

                let strLiteral = String(line[currentIndex..<endIndex])
                tokens.append(CodeToken(text: strLiteral, type: .string))
                currentIndex = endIndex
                continue
            }

            // Check for inline comment start
            if (language == .swift || language == .javascript) && line[currentIndex...].hasPrefix("//") {
                let comment = String(line[currentIndex...])
                tokens.append(CodeToken(text: comment, type: .comment))
                break
            }
            if (language == .python || language == .bash) && char == "#" {
                let comment = String(line[currentIndex...])
                tokens.append(CodeToken(text: comment, type: .comment))
                break
            }
            if language == .sql && line[currentIndex...].hasPrefix("--") {
                let comment = String(line[currentIndex...])
                tokens.append(CodeToken(text: comment, type: .comment))
                break
            }

            // Check for word (identifier, keyword, type, number)
            if char.isLetter || char == "_" || char == "$" {
                var endIndex = line.index(after: currentIndex)
                while endIndex < line.endIndex && (line[endIndex].isLetter || line[endIndex].isNumber || line[endIndex] == "_") {
                    endIndex = line.index(after: endIndex)
                }
                let word = String(line[currentIndex..<endIndex])
                let tokenType = classifyWord(word, language: language)
                tokens.append(CodeToken(text: word, type: tokenType))
                currentIndex = endIndex
                continue
            }

            // Check for numbers
            if char.isNumber {
                var endIndex = line.index(after: currentIndex)
                while endIndex < line.endIndex && (line[endIndex].isNumber || line[endIndex] == "." || line[endIndex] == "x") {
                    endIndex = line.index(after: endIndex)
                }
                let num = String(line[currentIndex..<endIndex])
                tokens.append(CodeToken(text: num, type: .number))
                currentIndex = endIndex
                continue
            }

            // Non-word symbol/space
            tokens.append(CodeToken(text: String(char), type: .plain))
            currentIndex = line.index(after: currentIndex)
        }

        return tokens
    }

    private func classifyWord(_ word: String, language: SyntaxLanguage) -> CodeTokenType {
        switch language {
        case .swift:
            if swiftKeywords.contains(word) { return .keyword }
            if word == "true" || word == "false" || word == "nil" { return .boolean }
            if word.first?.isUppercase == true { return .type }

        case .python:
            if pythonKeywords.contains(word) { return .keyword }
            if word == "True" || word == "False" || word == "None" { return .boolean }
            if word.first?.isUppercase == true { return .type }

        case .javascript:
            if jsKeywords.contains(word) { return .keyword }
            if word == "true" || word == "false" || word == "null" || word == "undefined" { return .boolean }
            if word.first?.isUppercase == true { return .type }

        case .bash:
            if bashKeywords.contains(word) { return .keyword }

        case .sql:
            if sqlKeywords.contains(word.uppercased()) { return .keyword }
            if word.uppercased() == "TRUE" || word.uppercased() == "FALSE" || word.uppercased() == "NULL" { return .boolean }

        case .json:
            if word == "true" || word == "false" || word == "null" { return .boolean }

        default:
            break
        }

        return .plain
    }
}

