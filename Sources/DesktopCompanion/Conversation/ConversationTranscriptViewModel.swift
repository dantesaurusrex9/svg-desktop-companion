import Foundation

struct ConversationTranscriptViewModel {
    let history: [CodexConversationTurn]
    let pendingQuestion: String?
    let status: String?

    var text: String {
        var lines: [String] = []
        for turn in history {
            lines.append("You: \(turn.question)")
            lines.append("Codex: \(turn.answer)")
        }

        if let pendingQuestion {
            lines.append("You: \(pendingQuestion)")
        }

        if let status {
            lines.append(status)
        }

        return lines.isEmpty ? "Ask me anything." : lines.joined(separator: "\n\n")
    }
}
