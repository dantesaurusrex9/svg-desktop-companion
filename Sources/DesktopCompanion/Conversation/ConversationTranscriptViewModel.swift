import Foundation

enum ConversationTranscriptItem: Equatable {
    case emptyPrompt(String)
    case user(String)
    case assistant(String)
    case status(String)
}

struct ConversationTranscriptViewModel {
    let history: [CodexConversationTurn]
    let pendingQuestion: String?
    let status: String?

    var items: [ConversationTranscriptItem] {
        var items: [ConversationTranscriptItem] = []
        for turn in history {
            items.append(.user(turn.question))
            items.append(.assistant(turn.answer))
        }

        if let pendingQuestion {
            items.append(.user(pendingQuestion))
        }

        if let status {
            items.append(.status(status))
        }

        return items.isEmpty ? [.emptyPrompt("Ask me anything.")] : items
    }
}
