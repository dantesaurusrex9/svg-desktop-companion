import Foundation

enum CodexConversationError: Error, Equatable {
    case alreadyRunning
    case codexNotFound
    case launchFailed(String)
    case failed(Int32, String)
    case missingResponse
    case timedOut
    case cancelled

    var userMessage: String {
        switch self {
        case .alreadyRunning:
            "Assistant is already thinking."
        case .codexNotFound:
            "Could not find the assistant CLI. Install it or make sure it is at ~/.local/bin/codex."
        case .launchFailed(let message):
            "Could not start assistant: \(message)"
        case .failed(_, let message):
            message.isEmpty ? "Assistant exited without an answer." : message
        case .missingResponse:
            "Assistant finished without an answer."
        case .timedOut:
            "Assistant took too long to answer."
        case .cancelled:
            "Assistant request cancelled."
        }
    }
}

@MainActor
final class CodexConversationRunner {
    private let locator: CodexExecutableLocator
    private let fileManager: FileManager
    private var process: Process?
    private var completion: ((Result<String, CodexConversationError>) -> Void)?
    private var streamUpdate: ((String) -> Void)?
    private var streamParser = CodexConversationStreamParser()
    private var latestStreamText = ""
    private var outputReadHandle: FileHandle?
    private var timeoutTimer: Timer?
    private var didCancel = false
    private var didTimeOut = false
    private let timeout: TimeInterval = 120

    init(
        locator: CodexExecutableLocator = CodexExecutableLocator(),
        fileManager: FileManager = .default
    ) {
        self.locator = locator
        self.fileManager = fileManager
    }

    func run(
        question: String,
        history: [CodexConversationTurn],
        streamUpdate: ((String) -> Void)? = nil,
        completion: @escaping (Result<String, CodexConversationError>) -> Void
    ) {
        guard process == nil else {
            completion(.failure(.alreadyRunning))
            return
        }

        guard let executablePath = locator.locate() else {
            AppLogger.conversation.error("Codex CLI executable not found")
            completion(.failure(.codexNotFound))
            return
        }

        do {
            let workspaceURL = try conversationWorkspaceURL()
            let outputURL = fileManager.temporaryDirectory
                .appendingPathComponent("desktop-companion-codex-\(UUID().uuidString).txt")
            let prompt = CodexConversationCommand.prompt(question: question, history: history)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = CodexConversationCommand.arguments(
                workingDirectory: workspaceURL.path,
                outputFile: outputURL.path
            )
            process.currentDirectoryURL = workspaceURL

            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardInput = inputPipe
            process.standardError = errorPipe
            process.standardOutput = outputPipe

            let startedAt = Date()
            process.terminationHandler = { [weak self] terminatedProcess in
                let errorText = String(
                    data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                let outputText = (try? String(contentsOf: outputURL, encoding: .utf8)) ?? ""
                try? FileManager.default.removeItem(at: outputURL)

                Task { @MainActor [weak self] in
                    self?.finish(
                        terminatedProcess,
                        outputText: outputText,
                        errorText: errorText,
                        startedAt: startedAt
                    )
                }
            }

            self.process = process
            self.completion = completion
            self.streamUpdate = streamUpdate
            streamParser = CodexConversationStreamParser()
            latestStreamText = ""
            outputReadHandle = outputPipe.fileHandleForReading
            didCancel = false
            didTimeOut = false
            outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    return
                }

                Task { @MainActor [weak self] in
                    self?.consumeStreamData(data)
                }
            }
            try process.run()
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.timeOutCurrentProcess()
                }
            }

            if let data = prompt.data(using: .utf8) {
                inputPipe.fileHandleForWriting.write(data)
            }
            inputPipe.fileHandleForWriting.closeFile()
        } catch {
            self.process = nil
            self.completion = nil
            self.streamUpdate = nil
            outputReadHandle?.readabilityHandler = nil
            outputReadHandle = nil
            AppLogger.conversation.error("Codex launch failed: \(error.localizedDescription, privacy: .public)")
            completion(.failure(.launchFailed(error.localizedDescription)))
        }
    }

    func cancel() {
        didCancel = true
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        outputReadHandle?.readabilityHandler = nil
        outputReadHandle = nil
        process?.terminate()
    }

    private func finish(
        _ terminatedProcess: Process,
        outputText: String,
        errorText: String,
        startedAt: Date
    ) {
        guard process === terminatedProcess else {
            return
        }

        timeoutTimer?.invalidate()
        timeoutTimer = nil
        outputReadHandle?.readabilityHandler = nil
        outputReadHandle = nil
        if let streamedText = streamParser.finish(), !streamedText.isEmpty {
            latestStreamText = streamedText
            streamUpdate?(streamedText)
        }
        process = nil
        let completion = completion
        self.completion = nil
        streamUpdate = nil

        let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        if didCancel {
            AppLogger.conversation.info("Codex request cancelled duration_ms=\(durationMs)")
            completion?(.failure(.cancelled))
            return
        }

        if didTimeOut {
            AppLogger.conversation.error("Codex request timed out duration_ms=\(durationMs)")
            completion?(.failure(.timedOut))
            return
        }

        guard terminatedProcess.terminationStatus == 0 else {
            AppLogger.conversation.error("Codex request failed status=\(terminatedProcess.terminationStatus) duration_ms=\(durationMs)")
            completion?(.failure(.failed(terminatedProcess.terminationStatus, sanitizedError(errorText))))
            return
        }

        let responseText = CodexConversationCommand.parsedResponse(from: outputText)
            ?? CodexConversationCommand.parsedResponse(from: latestStreamText)
        guard let response = responseText else {
            AppLogger.conversation.error("Codex response file was empty duration_ms=\(durationMs)")
            completion?(.failure(.missingResponse))
            return
        }

        AppLogger.conversation.info("Codex request succeeded duration_ms=\(durationMs)")
        completion?(.success(response))
    }

    private func consumeStreamData(_ data: Data) {
        guard process != nil, !didCancel, !didTimeOut else {
            return
        }

        if let streamedText = streamParser.consume(data), !streamedText.isEmpty {
            latestStreamText = streamedText
            streamUpdate?(streamedText)
        }
    }

    private func timeOutCurrentProcess() {
        guard let process else {
            return
        }

        didTimeOut = true
        process.terminate()
    }

    private func conversationWorkspaceURL() throws -> URL {
        let appSupport = try DesktopCompanionPaths.applicationSupportDirectory(
            fileManager: fileManager,
            create: true
        )
        let workspaceURL = appSupport
            .appendingPathComponent("CodexConversation", isDirectory: true)

        try fileManager.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        return workspaceURL
    }

    private func sanitizedError(_ errorText: String) -> String {
        let trimmed = errorText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }

        return String(trimmed.prefix(600))
    }
}
