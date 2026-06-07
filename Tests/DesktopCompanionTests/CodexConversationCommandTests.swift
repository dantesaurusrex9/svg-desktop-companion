import AppKit
import Testing
@testable import DesktopCompanion

struct CodexConversationCommandTests {
    @Test
    func testArgumentsRunCodexExecInReadOnlyGeneralMode() {
        #expect(
            CodexConversationCommand.arguments(workingDirectory: "/tmp/work", outputFile: "/tmp/answer.txt") ==
            [
                "exec",
                "--ephemeral",
                "--skip-git-repo-check",
                "--sandbox", "read-only",
                "--cd", "/tmp/work",
                "--output-last-message", "/tmp/answer.txt",
                "--color", "never",
                "--json",
                "-"
            ]
        )
    }

    @Test
    func testPromptUsesOnlyRecentHistory() throws {
        let history = (0..<12).map { index in
            CodexConversationTurn(question: "Question \(index)", answer: "Answer \(index)")
        }
        let prompt = try CodexConversationCommand.validatedPrompt(question: "Now?", history: history)

        #expect(!prompt.contains("Question 0"))
        #expect(!prompt.contains("Answer 3"))
        #expect(prompt.contains("Question 4"))
        #expect(prompt.contains("Answer 11"))
    }

    @Test
    func testPromptRejectsOversizedQuestion() {
        let question = String(repeating: "x", count: CodexConversationCommand.maxQuestionCharacterCount + 1)

        #expect(throws: CodexConversationError.inputTooLong) {
            _ = try CodexConversationCommand.validatedPrompt(question: question, history: [])
        }
    }

    @Test
    func testPromptIncludesHistoryAndCurrentQuestion() {
        let prompt = CodexConversationCommand.prompt(
            question: "What is the moon?",
            history: [
                CodexConversationTurn(question: "Hello?", answer: "Hi.")
            ]
        )

        #expect(prompt.contains("Do not inspect, modify, or rely on local files."))
        #expect(prompt.contains("User: Hello?"))
        #expect(prompt.contains("Assistant: Hi."))
        #expect(prompt.contains("User: What is the moon?"))
    }

    @Test
    func testParsedResponseTrimsBlankSpace() {
        #expect(CodexConversationCommand.parsedResponse(from: "\n  Answer. \n") == "Answer.")
        #expect(CodexConversationCommand.parsedResponse(from: "\n \t") == nil)
    }

    @Test
    func testStreamingParserAccumulatesDeltaEvents() {
        var parser = CodexConversationStreamParser()
        let first = #"{"type":"response.output_text.delta","delta":"Hel"}"#
        let second = #"{"type":"response.output_text.delta","delta":"lo"}"#

        #expect(parser.consume(Data("\(first)\n".utf8)) == "Hel")
        #expect(parser.consume(Data("\(second)\n".utf8)) == "Hello")
    }

    @Test
    func testStreamingParserHandlesMultibyteCharactersSplitAcrossChunks() throws {
        var parser = CodexConversationStreamParser()
        let line = #"{"type":"response.output_text.delta","delta":"Hi 🌕"}"#
        let data = Data("\(line)\n".utf8)
        let emojiStart = try #require(data.firstIndex(of: 0xF0))
        let splitIndex = data.index(after: emojiStart)

        #expect(parser.consume(Data(data[..<splitIndex])) == nil)
        #expect(parser.consume(Data(data[splitIndex...])) == "Hi 🌕")
    }

    @Test
    func testStreamingParserIgnoresNonAnswerOutput() {
        var parser = CodexConversationStreamParser()
        let progress = #"{"type":"response.reasoning_text.delta","delta":"internal thought"}"#
        let status = #"{"type":"turn.status.delta","delta":"working"}"#
        let answer = #"{"type":"response.output_text.delta","delta":"Answer"}"#

        #expect(parser.consume(Data("plain stdout warning\n".utf8)) == nil)
        #expect(parser.consume(Data("\(progress)\n".utf8)) == nil)
        #expect(parser.consume(Data("\(status)\n".utf8)) == nil)
        #expect(parser.consume(Data("\(answer)\n".utf8)) == "Answer")
    }

    @Test
    func testStreamingParserUsesAssistantMessageEvents() {
        var parser = CodexConversationStreamParser()
        let line = """
        {"type":"response_item","item":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Complete answer"}]}}
        """

        #expect(parser.consume(Data("\(line)\n".utf8)) == "Complete answer")
    }

    @Test
    func testConversationErrorMessagesAvoidCodexLabel() {
        #expect(!CodexConversationError.codexNotFound.userMessage.contains("Codex"))
        #expect(!CodexConversationError.launchFailed("boom").userMessage.contains("Codex"))
    }

    @Test
    func testExecutableLocatorPrefersKnownCodexLocationsThenPath() {
        let locator = CodexExecutableLocator(
            environment: [
                "HOME": "/Users/example",
                "PATH": "/bin:/custom/bin:/bin"
            ],
            isExecutableFile: { $0 == "/custom/bin/codex" }
        )

        #expect(locator.locate() == "/custom/bin/codex")
        #expect(
            CodexExecutableLocator.candidatePaths(environment: [
                "HOME": "/Users/example",
                "PATH": "/bin:/custom/bin:/bin"
            ]) ==
            [
                "/Users/example/.local/bin/codex",
                "/opt/homebrew/bin/codex",
                "/usr/local/bin/codex",
                "/bin/codex",
                "/custom/bin/codex"
            ]
        )
    }
}
