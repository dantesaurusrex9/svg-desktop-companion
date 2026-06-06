import Foundation

struct CodexConversationTurn: Equatable {
    let question: String
    let answer: String
}

enum CodexConversationCommand {
    static func arguments(workingDirectory: String, outputFile: String) -> [String] {
        [
            "exec",
            "--ephemeral",
            "--skip-git-repo-check",
            "--sandbox", "read-only",
            "--cd", workingDirectory,
            "--output-last-message", outputFile,
            "--color", "never",
            "-"
        ]
    }

    static func prompt(question: String, history: [CodexConversationTurn]) -> String {
        var sections = [
            "You are answering from a small macOS desktop companion speech bubble.",
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

    static func parsedResponse(from contents: String) -> String? {
        let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
