//
//  AnnouncementScriptTests.swift
//  SplitsTests
//

import Foundation
import Testing
@testable import Splits

struct AnnouncementScriptTests {
    private let script = AnnouncementScript()

    private func step(_ kind: StepKind, _ target: SegmentTarget, ordinal: Int = 1) -> WorkoutStep {
        WorkoutStep(kind: kind, target: target, index: 0, ordinal: ordinal, ordinalTotal: 8)
    }

    @Test func runStartSpeaksAndTapsTwice() {
        let announcement = script.announcement(for: .stepStarted(step(.run, .distance(400), ordinal: 3)))
        #expect(announcement?.text == "3번째 달리기, 400미터")
        #expect(announcement?.haptic == .runStart)
        #expect(announcement?.interrupting == false)
    }

    @Test func restStartUsesRestHaptic() {
        let announcement = script.announcement(for: .stepStarted(step(.rest, .duration(90))))
        #expect(announcement?.text == "회복, 1분 30초")
        #expect(announcement?.haptic == .restStart)
    }

    @Test func countdownInterrupts() {
        let announcement = script.announcement(for: .countdown(3))
        #expect(announcement?.text == "3")
        #expect(announcement?.interrupting == true)
        #expect(announcement?.haptic == .countdown)
        #expect(script.announcement(for: .goalCountdown(2))?.interrupting == true)
    }

    @Test func lapWithoutGoalSaysNothing() {
        let lap = LapRecord(index: 0, kind: .run, target: .distance(400), distance: 400, duration: 88, ordinal: 1)
        #expect(script.announcement(for: .lapCompleted(lap)) == nil)
    }

    @Test func imperialUnitChangesSpokenDistance() {
        var imperial = AnnouncementScript()
        imperial.unit = .imperial
        let announcement = imperial.announcement(for: .kilometer(1, splitPace: nil))
        #expect(announcement?.text == "0.6마일")
        #expect(announcement?.haptic == .light)
    }
}
