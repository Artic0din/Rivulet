//
//  HomePerformanceTracer.swift
//  Rivulet
//
//  Epic 2 (E2-PR1) — performance evidence harness for the Home experience.
//
//  Implements the instrumentation foundation required by Epic 0
//  (`performance-budgets-and-baseline.md`). Emits `os_signpost` intervals/events
//  using Epic 0 metric terminology so launch, home-data-load, render-state
//  transition, hero-preparation, and home-completion timings can be captured
//  with Instruments / Xcode Organizer and compared against published budgets.
//
//  NO third-party analytics, NO telemetry service, NO Sentry performance product.
//  Pure first-party OSSignposter. The protocol seam exists so tests can assert
//  instrumentation behavior with a recording tracer.
//
//  Observability (ADR-005 / observability-policy.md): category `PerformanceReview`
//  (review-only), subsystem `com.rivulet.app`. Signposts carry only metric IDs
//  and phase names — no tokens, URLs, or user data.
//

import Foundation
import os

/// Epic 0 performance metric identities relevant to Home (E2-PR1 scope).
/// Raw values are the published metric IDs / budget references.
enum HomePerformanceMetric: String {
    /// PERF-001 (cold) / PERF-002 (warm): launch → first useful home shell.
    case launchToFirstUsefulScreen = "PERF-001/002 launch→first-useful-screen"
    /// PERF-003: hero artwork/title/primary action ready after home shell.
    case homeHeroReady = "PERF-003 home-hero-ready"
    /// Home hub data load duration (feeds PERF-001/003 interpretation).
    case homeDataLoad = "HOME data-load"
    /// Home reached its first content-ready state (hubs processed).
    case homeCompletion = "HOME completion"
    /// Discrete render-state transition (loading→content, etc.).
    case renderStateTransition = "HOME render-state-transition"
}

/// Instrumentation seam for Home performance. Production emits signposts; tests
/// record calls. Methods are intentionally semantic (not raw signpost calls) so
/// the recording double can assert intent without depending on OSSignposter.
protocol HomePerformanceTracing: AnyObject, Sendable {
    /// Mark the in-app launch reference point (ContentView task start).
    func beginLaunch()
    /// Mark the first visually-useful home shell (home content ready / splash
    /// dismissal). Closes the launch interval (PERF-001/002).
    func markFirstUsefulScreen()

    func beginHomeDataLoad()
    func endHomeDataLoad()

    func recordRenderStateTransition(from: RenderStatePhase?, to: RenderStatePhase)

    /// Hero data preparation window (PERF-003). Captured even while the hero is
    /// flag-gated off, so the budget is measurable when hero ships.
    func beginHeroPreparation()
    func endHeroPreparation()

    /// Home reached its first content-ready state.
    func markHomeComplete()
}

// MARK: - Production (os_signpost)

/// Production tracer backed by `OSSignposter`. Interval state for the three
/// span metrics (launch, data-load, hero-prep) is held behind a lock; begins are
/// idempotent so duplicate lifecycle callbacks cannot corrupt an open interval.
final class SignpostHomePerformanceTracer: HomePerformanceTracing, @unchecked Sendable {
    private let signposter = OSSignposter(subsystem: "com.rivulet.app", category: "PerformanceReview")
    private let lock = NSLock()
    private var launchInterval: OSSignpostIntervalState?
    private var dataLoadInterval: OSSignpostIntervalState?
    private var heroInterval: OSSignpostIntervalState?

    func beginLaunch() {
        lock.lock(); defer { lock.unlock() }
        guard launchInterval == nil else { return }
        let id = signposter.makeSignpostID()
        launchInterval = signposter.beginInterval(
            "LaunchToFirstUsefulScreen", id: id,
            "\(HomePerformanceMetric.launchToFirstUsefulScreen.rawValue)"
        )
    }

    func markFirstUsefulScreen() {
        lock.lock(); defer { lock.unlock() }
        guard let interval = launchInterval else { return }
        signposter.endInterval("LaunchToFirstUsefulScreen", interval)
        launchInterval = nil
    }

    func beginHomeDataLoad() {
        lock.lock(); defer { lock.unlock() }
        guard dataLoadInterval == nil else { return }
        let id = signposter.makeSignpostID()
        dataLoadInterval = signposter.beginInterval(
            "HomeDataLoad", id: id, "\(HomePerformanceMetric.homeDataLoad.rawValue)"
        )
    }

    func endHomeDataLoad() {
        lock.lock(); defer { lock.unlock() }
        guard let interval = dataLoadInterval else { return }
        signposter.endInterval("HomeDataLoad", interval)
        dataLoadInterval = nil
    }

    func recordRenderStateTransition(from: RenderStatePhase?, to: RenderStatePhase) {
        signposter.emitEvent(
            "HomeRenderStateTransition",
            "\(from?.rawValue ?? "nil")->\(to.rawValue)"
        )
    }

    func beginHeroPreparation() {
        lock.lock(); defer { lock.unlock() }
        guard heroInterval == nil else { return }
        let id = signposter.makeSignpostID()
        heroInterval = signposter.beginInterval(
            "HomeHeroReady", id: id, "\(HomePerformanceMetric.homeHeroReady.rawValue)"
        )
    }

    func endHeroPreparation() {
        lock.lock(); defer { lock.unlock() }
        guard let interval = heroInterval else { return }
        signposter.endInterval("HomeHeroReady", interval)
        heroInterval = nil
    }

    func markHomeComplete() {
        signposter.emitEvent("HomeCompletion", "\(HomePerformanceMetric.homeCompletion.rawValue)")
    }
}

// MARK: - Access point

/// Process-wide tracer. Swappable for a recording double in tests. MainActor
/// isolated because every call site is SwiftUI/MainActor, which also makes the
/// mutable global race-free under Swift concurrency.
@MainActor
enum HomePerformance {
    static var tracer: HomePerformanceTracing = SignpostHomePerformanceTracer()
}
