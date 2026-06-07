import AppKit
import Testing
@testable import DesktopCompanion

func makeThemeFolder(
    manifest: String,
    bubbleSVG: String = #"<svg viewBox="0 0 420 300" xmlns="http://www.w3.org/2000/svg"></svg>"#
) throws -> ConversationTheme {
    let folderURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("desktop-companion-theme-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    try manifest.write(to: folderURL.appendingPathComponent("theme.json"), atomically: true, encoding: .utf8)
    try bubbleSVG.write(to: folderURL.appendingPathComponent("bubble.svg"), atomically: true, encoding: .utf8)
    return try ConversationThemeLoader.loadTheme(from: folderURL)
}

func testMetrics() -> ConversationBubbleMetrics {
    ConversationBubbleMetrics(
        width: 520,
        minHeight: 300,
        maxVisibleHeightRatio: 0.5,
        contentInsets: NSEdgeInsets(top: 42, left: 42, bottom: 30, right: 42),
        inputHeight: 42,
        transcriptInputSpacing: 16,
        tailAnchor: NSPoint(x: 94, y: 0)
    )
}

func transcriptText(_ items: [ConversationTranscriptItem]) -> String {
    items.map { item in
        switch item {
        case .emptyPrompt(let text), .user(let text), .assistant(let text), .status(let text):
            text
        }
    }.joined(separator: "\n")
}

func makeCompanionPackage(
    manifest: String? = nil,
    svg: String = #"<svg viewBox="0 0 220 220" data-mouth-anchor="108 89" xmlns="http://www.w3.org/2000/svg"></svg>"#,
    includeThemes: Bool = false
) throws -> CompanionPackage {
    let folderURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("desktop-companion-package-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

    let manifestText = manifest ?? """
    {
      "schemaVersion": 1,
      "id": "test-companion",
      "displayName": "Test Companion",
      "companionSVG": "companion.svg",
      \(includeThemes ? #""conversationThemesDirectory": "ConversationThemes","# : "")
      "speechAnchor": { "x": 108, "y": 89 },
      "bubblePlacement": "right",
      "animationPreset": "wholeObjectReaction"
    }
    """
    try manifestText.write(to: folderURL.appendingPathComponent("companion.json"), atomically: true, encoding: .utf8)
    try svg.write(to: folderURL.appendingPathComponent("companion.svg"), atomically: true, encoding: .utf8)

    if includeThemes {
        let themeFolderURL = folderURL
            .appendingPathComponent("ConversationThemes", isDirectory: true)
            .appendingPathComponent("package-cloud", isDirectory: true)
        try FileManager.default.createDirectory(at: themeFolderURL, withIntermediateDirectories: true)
        try """
        {
          "schemaVersion": 1,
          "id": "package-cloud",
          "displayName": "Package Cloud",
          "bubbleSVG": "bubble.svg",
          "width": 360,
          "minHeight": 190,
          "maxVisibleHeightRatio": 0.5,
          "contentInsets": { "top": 34, "left": 36, "bottom": 26, "right": 36 },
          "inputHeight": 34,
          "transcriptInputSpacing": 12,
          "tailAnchor": { "x": 72, "y": 0 }
        }
        """
            .write(to: themeFolderURL.appendingPathComponent("theme.json"), atomically: true, encoding: .utf8)
        try "<svg viewBox=\"0 0 360 190\" xmlns=\"http://www.w3.org/2000/svg\"></svg>"
            .write(to: themeFolderURL.appendingPathComponent("bubble.svg"), atomically: true, encoding: .utf8)
    }

    return try CompanionPackageLoader.loadPackage(from: folderURL)
}

func testPackage(id: String, displayName: String? = nil) -> CompanionPackage {
    CompanionPackage(
        id: id,
        displayName: displayName ?? id,
        folderURL: URL(fileURLWithPath: "/tmp/\(id)", isDirectory: true),
        svgURL: URL(fileURLWithPath: "/tmp/\(id)/companion.svg", isDirectory: false),
        conversationThemesDirectoryURL: nil,
        speechAnchor: NSPoint(x: 121, y: 94),
        bubblePlacement: .automatic,
        animationPreset: .wholeObjectReaction
    )
}

func testInstance(id: String, packageID: String) -> CompanionInstance {
    CompanionInstance(
        id: id,
        packageID: packageID,
        origin: CompanionAnchor(x: 10, y: 20),
        layerMode: .desktop,
        speechAnchor: CompanionAnchor(x: 121, y: 94),
        bubblePlacement: .automatic,
        animationPreset: .wholeObjectReaction
    )
}

@MainActor
func descendantViews<View: NSView>(ofType type: View.Type, in root: NSView) -> [View] {
    let matchingRoot = (root as? View).map { [$0] } ?? []
    return matchingRoot + root.subviews.flatMap { descendantViews(ofType: type, in: $0) }
}

@MainActor
func hasIdleAnimation(in root: NSView) -> Bool {
    descendantViews(ofType: NSView.self, in: root).contains {
        $0.layer?.animation(forKey: "desktopCompanionIdle") != nil
    }
}

func testCompanionFrame() -> NSRect {
    NSRect(x: 220, y: 100, width: 220, height: 220)
}

func bodyScreenRect(from layout: ConversationBubbleLayoutResult) -> NSRect {
    NSRect(
        x: layout.frame.minX + layout.bodyRect.minX,
        y: layout.frame.maxY - layout.bodyRect.maxY,
        width: layout.bodyRect.width,
        height: layout.bodyRect.height
    )
}

func rgbaComponents(_ color: NSColor) -> [CGFloat] {
    let color = color.usingColorSpace(.deviceRGB) ?? color
    return [
        color.redComponent,
        color.greenComponent,
        color.blueComponent,
        color.alphaComponent
    ]
}

@MainActor
func submittedConversationController() throws -> (
    controller: ConversationBubbleWindowController,
    runner: FakeCodexConversationRunner,
    recorder: RunningStateRecorder
) {
    let runner = FakeCodexConversationRunner()
    let recorder = RunningStateRecorder()
    let controller = ConversationBubbleWindowController(runner: runner)
    controller.onRunningStateChanged = { recorder.values.append($0) }

    let inputField = try #require(firstEditableTextField(in: controller.window?.contentView))
    inputField.stringValue = "What is Go?"
    guard let action = inputField.action else {
        Issue.record("Conversation input did not have a submit action")
        return (controller, runner, recorder)
    }

    #expect(NSApp.sendAction(action, to: inputField.target, from: inputField))
    return (controller, runner, recorder)
}

@MainActor
func firstEditableTextField(in view: NSView?) -> NSTextField? {
    guard let view else {
        return nil
    }

    if let textField = view as? NSTextField,
       textField.isEditable {
        return textField
    }

    for subview in view.subviews {
        if let textField = firstEditableTextField(in: subview) {
            return textField
        }
    }

    return nil
}

@MainActor
final class FakeCodexConversationRunner: CodexConversationRunning {
    private var completion: ((Result<String, CodexConversationError>) -> Void)?
    private(set) var didCancel = false

    func run(
        question: String,
        history: [CodexConversationTurn],
        streamUpdate: ((String) -> Void)?,
        completion: @escaping (Result<String, CodexConversationError>) -> Void
    ) {
        self.completion = completion
    }

    func cancel() {
        didCancel = true
    }

    func complete(_ result: Result<String, CodexConversationError>) {
        let completion = completion
        self.completion = nil
        completion?(result)
    }
}

final class RunningStateRecorder {
    var values: [Bool] = []
}
