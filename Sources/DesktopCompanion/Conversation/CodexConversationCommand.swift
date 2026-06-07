import Foundation

struct CodexConversationTurn: Equatable {
    let question: String
    let answer: String
}

enum CodexConversationCommand {
    static let maxQuestionCharacterCount = 2_000
    static let maxHistoryTurnCount = 8
    static let maxPromptCharacterCount = 12_000

    static func arguments(workingDirectory: String, outputFile: String) -> [String] {
        [
            "exec",
            "--ephemeral",
            "--skip-git-repo-check",
            "--sandbox", "read-only",
            "--cd", workingDirectory,
            "--output-last-message", outputFile,
            "--color", "never",
            "--json",
            "-"
        ]
    }

    static func validatedPrompt(question: String, history: [CodexConversationTurn]) throws -> String {
        guard question.count <= maxQuestionCharacterCount else {
            throw CodexConversationError.inputTooLong
        }

        let prompt = prompt(question: question, history: boundedHistory(history))
        guard prompt.count <= maxPromptCharacterCount else {
            throw CodexConversationError.inputTooLong
        }

        return prompt
    }

    static func prompt(question: String, history: [CodexConversationTurn]) -> String {
        var sections = [
            "You are answering from a small transparent macOS desktop companion overlay.",
            "Answer the user's general question directly and concisely.",
            "Do not inspect, modify, or rely on local files."
        ]

        if !history.isEmpty {
            sections.append("Conversation so far:")
            sections.append(history.map { turn in
                """
                User: \(turn.question)
                Assistant: \(turn.answer)
                """
            }.joined(separator: "\n\n"))
        }

        sections.append(
            """
            User: \(question)
            Assistant:
            """
        )

        return sections.joined(separator: "\n\n")
    }

    static func boundedHistory(_ history: [CodexConversationTurn]) -> [CodexConversationTurn] {
        Array(history.suffix(maxHistoryTurnCount))
    }

    static func parsedResponse(from contents: String) -> String? {
        let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct CodexConversationStreamParser {
    private var lineBuffer = Data()
    private(set) var streamedText = ""

    mutating func consume(_ data: Data) -> String? {
        guard !data.isEmpty else {
            return nil
        }

        lineBuffer.append(data)
        var didUpdate = false
        while let newlineIndex = lineBuffer.firstIndex(of: 0x0A) {
            let lineData = Data(lineBuffer[..<newlineIndex])
            lineBuffer.removeSubrange(...newlineIndex)
            didUpdate = processLine(lineData) || didUpdate
        }

        return didUpdate ? streamedText : nil
    }

    mutating func finish() -> String? {
        let lineData = lineBuffer
        lineBuffer.removeAll()
        return processLine(lineData) ? streamedText : nil
    }

    private mutating func processLine(_ data: Data) -> Bool {
        guard let line = String(data: data, encoding: .utf8) else {
            return false
        }

        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return false
        }

        if let delta = Self.outputTextDelta(in: json), !delta.isEmpty {
            streamedText += delta
            return true
        }

        if let text = Self.assistantTextEvent(in: json),
           !text.isEmpty,
           text != streamedText {
            streamedText = text
            return true
        }

        return false
    }

    private static func outputTextDelta(in json: Any) -> String? {
        if let dictionary = json as? [String: Any],
           eventType(in: dictionary) == "response.output_text.delta",
           let delta = dictionary["delta"] as? String {
            return delta
        }

        return nil
    }

    private static func assistantTextEvent(in json: Any) -> String? {
        guard let dictionary = json as? [String: Any],
              let type = eventType(in: dictionary) else {
            return nil
        }

        switch type {
        case "response.output_text.done":
            return dictionary["text"] as? String
        case "response_item", "response.output_item.done", "response.completed", "response.done":
            return assistantText(in: dictionary)
        default:
            return nil
        }
    }

    private static func assistantText(in json: Any) -> String? {
        guard let dictionary = json as? [String: Any] else {
            if let values = json as? [Any] {
                return values.compactMap(assistantText(in:)).joinedNonEmpty()
            }
            return nil
        }

        if dictionary["role"] as? String == "assistant" {
            return textContent(in: dictionary["content"]) ?? dictionary["text"] as? String
        }

        if let type = dictionary["type"] as? String,
           type.localizedCaseInsensitiveContains("output_text"),
           let text = dictionary["text"] as? String {
            return text
        }

        for value in dictionary.values {
            if let text = assistantText(in: value), !text.isEmpty {
                return text
            }
        }

        return nil
    }

    private static func eventType(in dictionary: [String: Any]) -> String? {
        (dictionary["type"] as? String)?.lowercased()
    }

    private static func textContent(in value: Any?) -> String? {
        if let text = value as? String {
            return text
        }

        if let values = value as? [Any] {
            return values.compactMap { nestedValue in
                if let dictionary = nestedValue as? [String: Any] {
                    return dictionary["text"] as? String
                }
                return textContent(in: nestedValue)
            }.joinedNonEmpty()
        }

        if let dictionary = value as? [String: Any] {
            return dictionary["text"] as? String ?? textContent(in: dictionary["content"])
        }

        return nil
    }
}

private extension Array where Element == String {
    func joinedNonEmpty() -> String? {
        let value = joined()
        return value.isEmpty ? nil : value
    }
}
