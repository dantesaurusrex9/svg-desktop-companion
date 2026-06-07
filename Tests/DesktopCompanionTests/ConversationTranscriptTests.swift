import AppKit
import Testing
@testable import DesktopCompanion

struct ConversationTranscriptTests {
    @Test
    func testConversationTranscriptItemsUseChatRowsWithoutSpeakerLabels() {
        let model = ConversationTranscriptViewModel(
            history: [
                CodexConversationTurn(question: "tell me golang is?", answer: "Go is a programming language.")
            ],
            pendingQuestion: "What is concurrency?",
            streamingAnswer: nil,
            status: "Thinking..."
        )

        #expect(
            model.items == [
                .user("tell me golang is?"),
                .assistant("Go is a programming language."),
                .user("What is concurrency?"),
                .status("Thinking...")
            ]
        )
        #expect(!transcriptText(model.items).contains("Codex:"))
        #expect(!transcriptText(model.items).contains("You:"))
    }

    @Test
    func testConversationTranscriptShowsPromptWhenEmpty() {
        let model = ConversationTranscriptViewModel(
            history: [],
            pendingQuestion: nil,
            streamingAnswer: nil,
            status: nil
        )

        #expect(model.items == [.emptyPrompt("Ask me anything.")])
    }

    @Test
    func testConversationTranscriptShowsStreamingAnswerForPendingQuestion() {
        let model = ConversationTranscriptViewModel(
            history: [],
            pendingQuestion: "Explain buffers.",
            streamingAnswer: "Buffers hold temporary bytes",
            status: nil
        )

        #expect(model.items == [
            .user("Explain buffers."),
            .assistant("Buffers hold temporary bytes")
        ])
    }

    @MainActor
    @Test
    func testAssistantTranscriptRowsUseFullAvailableWidth() {
        let text = Array(repeating: "conversation text should use available width", count: 8)
            .joined(separator: " ")
        let assistantView = ConversationTranscriptView(frame: .zero)
        assistantView.items = [.assistant(text)]
        let userView = ConversationTranscriptView(frame: .zero)
        userView.items = [.user(text)]

        #expect(assistantView.measuredHeight(width: 360) < assistantView.measuredHeight(width: 260))
        #expect(userView.measuredHeight(width: 360) < userView.measuredHeight(width: 260))
    }

    @MainActor
    @Test
    func testConversationTextStyleUpdateChangesTranscriptMeasurement() {
        let text = Array(repeating: "conversation text should reflow after font changes", count: 5)
            .joined(separator: " ")
        let view = ConversationTranscriptView(frame: .zero)
        view.items = [.assistant(text)]
        let originalHeight = view.measuredHeight(width: 280)

        var style = ConversationTranscriptStyle.defaultStyle
        style.assistant.font = NSFont.systemFont(ofSize: 24)
        view.updateTextStyle(style)

        #expect(view.measuredHeight(width: 280) > originalHeight)
    }

    @MainActor
    @Test
    func testConversationTextStyleUsesDistinctUserAndAssistantBackgrounds() {
        let style = ConversationTranscriptStyle.defaultStyle
        let userBackground = rgbaComponents(style.itemStyle(for: .user("hello")).backgroundColor)
        let assistantBackground = rgbaComponents(style.itemStyle(for: .assistant("hello")).backgroundColor)

        #expect(userBackground != assistantBackground)
    }
}
