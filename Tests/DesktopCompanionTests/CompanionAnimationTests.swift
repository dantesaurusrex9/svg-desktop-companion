import AppKit
import Testing
@testable import DesktopCompanion

struct CompanionAnimationTests {
    @Test
    func testAnimationStatesAreSharedAcrossActivePresets() {
        #expect(CompanionAnimationClip.states(for: .wholeObjectReaction) == CompanionAnimationState.allCases)
        #expect(CompanionAnimationClip.states(for: .legoSmash) == CompanionAnimationState.allCases)
        #expect(CompanionAnimationClip.states(for: .idleOnly).isEmpty)
    }

    @MainActor
    @Test
    func testAnimationClipsBuildTypingAndThinkingStates() throws {
        let markup = #"<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg"><g class="lego-smash-arm"></g></svg>"#
        let renderer: (String) -> NSImage = { _ in NSImage(size: NSSize(width: 2, height: 2)) }

        let typing = try #require(CompanionAnimationClip.clip(
            markup: markup,
            preset: .legoSmash,
            state: .typing,
            renderer: renderer
        ))
        let thinking = try #require(CompanionAnimationClip.clip(
            markup: markup,
            preset: .legoSmash,
            state: .thinking,
            renderer: renderer
        ))

        #expect(typing.frames.count == 3)
        #expect(typing.duration == 0.30)
        #expect(thinking.frames.count == 1)
        #expect(thinking.duration == 1.25)
    }

    @MainActor
    @Test
    func testAnimationClipPreservesSelfClosingHookGroups() throws {
        let markup = #"<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg"><g class="lego-smash-arm"/></svg>"#
        var renderedMarkup: [String] = []
        let renderer: (String) -> NSImage = { markup in
            renderedMarkup.append(markup)
            return NSImage(size: NSSize(width: 2, height: 2))
        }

        _ = try #require(CompanionAnimationClip.clip(
            markup: markup,
            preset: .legoSmash,
            state: .typing,
            renderer: renderer
        ))

        #expect(renderedMarkup.contains { $0.contains(#"<g class="lego-smash-arm" transform="rotate(-160 88 116)"/>"#) })
        #expect(renderedMarkup.contains { $0.contains(#"<g class="lego-smash-arm" transform="rotate(15 88 116)"/>"#) })
    }

    @MainActor
    @Test
    func testIdleOnlyDoesNotBuildAnimationClips() {
        let renderer: (String) -> NSImage = { _ in NSImage(size: NSSize(width: 2, height: 2)) }

        let clip = CompanionAnimationClip.clip(
            markup: #"<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg"></svg>"#,
            preset: .idleOnly,
            state: .typing,
            renderer: renderer
        )
        if clip != nil {
            Issue.record("Idle-only preset should not build animation clips")
        }
    }
}
