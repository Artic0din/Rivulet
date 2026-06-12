//
//  HomePerformanceTracerTests.swift
//  RivuletTests
//
//  Epic 2 (E2-PR1) — performance instrumentation behavior coverage.
//  Asserts the harness records the expected semantic events via the protocol
//  seam, and that the production signpost tracer is crash-safe under duplicate
//  / unbalanced lifecycle callbacks.
//

import XCTest
@testable import Rivulet

/// Recording double used to assert instrumentation intent without OSSignposter.
final class RecordingHomePerformanceTracer: HomePerformanceTracing, @unchecked Sendable {
    enum Event: Equatable {
        case beginLaunch
        case firstUsefulScreen
        case beginHomeDataLoad
        case endHomeDataLoad
        case transition(RenderStatePhase?, RenderStatePhase)
        case beginHeroPreparation
        case endHeroPreparation
        case homeComplete
    }

    private let lock = NSLock()
    private var _events: [Event] = []
    var events: [Event] {
        lock.lock(); defer { lock.unlock() }
        return _events
    }

    private func append(_ event: Event) {
        lock.lock(); defer { lock.unlock() }
        _events.append(event)
    }

    func beginLaunch() { append(.beginLaunch) }
    func markFirstUsefulScreen() { append(.firstUsefulScreen) }
    func beginHomeDataLoad() { append(.beginHomeDataLoad) }
    func endHomeDataLoad() { append(.endHomeDataLoad) }
    func recordRenderStateTransition(from: RenderStatePhase?, to: RenderStatePhase) {
        append(.transition(from, to))
    }
    func beginHeroPreparation() { append(.beginHeroPreparation) }
    func endHeroPreparation() { append(.endHeroPreparation) }
    func markHomeComplete() { append(.homeComplete) }
}

@MainActor
final class HomePerformanceTracerTests: XCTestCase {

    private var saved: HomePerformanceTracing!

    override func setUp() {
        super.setUp()
        saved = HomePerformance.tracer
    }

    override func tearDown() {
        HomePerformance.tracer = saved
        super.tearDown()
    }

    func testRecorderCapturesLaunchToFirstUsefulScreen() {
        let recorder = RecordingHomePerformanceTracer()
        HomePerformance.tracer = recorder

        HomePerformance.tracer.beginLaunch()
        HomePerformance.tracer.markFirstUsefulScreen()

        XCTAssertEqual(recorder.events, [.beginLaunch, .firstUsefulScreen])
    }

    func testRecorderCapturesHomeLoadLifecycle() {
        let recorder = RecordingHomePerformanceTracer()
        HomePerformance.tracer = recorder

        let tracer = HomePerformance.tracer
        tracer.beginHomeDataLoad()
        tracer.recordRenderStateTransition(from: nil, to: .loading)
        tracer.recordRenderStateTransition(from: .loading, to: .content)
        tracer.endHomeDataLoad()
        tracer.beginHeroPreparation()
        tracer.endHeroPreparation()
        tracer.markHomeComplete()

        XCTAssertEqual(recorder.events, [
            .beginHomeDataLoad,
            .transition(nil, .loading),
            .transition(.loading, .content),
            .endHomeDataLoad,
            .beginHeroPreparation,
            .endHeroPreparation,
            .homeComplete
        ])
    }

    func testTransitionRecordsErrorAndEmptyPaths() {
        let recorder = RecordingHomePerformanceTracer()
        HomePerformance.tracer = recorder

        HomePerformance.tracer.recordRenderStateTransition(from: .loading, to: .error)
        HomePerformance.tracer.recordRenderStateTransition(from: .loading, to: .empty)

        XCTAssertEqual(recorder.events, [
            .transition(.loading, .error),
            .transition(.loading, .empty)
        ])
    }

    /// Production tracer must tolerate duplicate begins and unbalanced ends
    /// (SwiftUI lifecycle callbacks can fire more than once) without crashing.
    func testSignpostTracerIsCrashSafeUnderDuplicateLifecycle() {
        let tracer = SignpostHomePerformanceTracer()
        tracer.beginLaunch()
        tracer.beginLaunch()            // idempotent
        tracer.markFirstUsefulScreen()
        tracer.markFirstUsefulScreen()  // unbalanced end — no-op

        tracer.endHomeDataLoad()        // end with no begin — no-op
        tracer.beginHomeDataLoad()
        tracer.endHomeDataLoad()

        tracer.endHeroPreparation()     // end with no begin — no-op
        tracer.beginHeroPreparation()
        tracer.beginHeroPreparation()   // idempotent
        tracer.endHeroPreparation()

        tracer.recordRenderStateTransition(from: nil, to: .loading)
        tracer.markHomeComplete()
        // Reaching here without trapping is the assertion.
    }
}
