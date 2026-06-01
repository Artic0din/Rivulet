//
//  SidebarNavigationPolicyTests.swift
//  RivuletTests
//
//  E2-PR6 — deterministic top-level navigation decisions.
//

import XCTest
@testable import Rivulet

final class SidebarNavigationPolicyTests: XCTestCase {

    // MARK: - resolveSelection

    func testHonorsOrdinaryTabChange() {
        let outcome = SidebarNavigationPolicy.resolveSelection(
            requested: .home, isNested: false, isSettingsSubPage: false, hasMultipleProfiles: false
        )
        XCTAssertEqual(outcome, .select(.home))
    }

    func testHonorsLibraryTabWithAssociatedValue() {
        let outcome = SidebarNavigationPolicy.resolveSelection(
            requested: .library(key: "3"), isNested: false, isSettingsSubPage: false, hasMultipleProfiles: true
        )
        XCTAssertEqual(outcome, .select(.library(key: "3")))
    }

    func testBlockedWhileNested() {
        let outcome = SidebarNavigationPolicy.resolveSelection(
            requested: .search, isNested: true, isSettingsSubPage: false, hasMultipleProfiles: true
        )
        XCTAssertEqual(outcome, .ignore)
    }

    func testBlockedWhileInSettingsSubPage() {
        let outcome = SidebarNavigationPolicy.resolveSelection(
            requested: .discover, isNested: false, isSettingsSubPage: true, hasMultipleProfiles: false
        )
        XCTAssertEqual(outcome, .ignore)
    }

    func testAccountWithMultipleProfilesPresentsSwitcher() {
        let outcome = SidebarNavigationPolicy.resolveSelection(
            requested: .account, isNested: false, isSettingsSubPage: false, hasMultipleProfiles: true
        )
        XCTAssertEqual(outcome, .presentProfileSwitcher)
    }

    func testAccountWithSingleProfileIsIgnored() {
        let outcome = SidebarNavigationPolicy.resolveSelection(
            requested: .account, isNested: false, isSettingsSubPage: false, hasMultipleProfiles: false
        )
        XCTAssertEqual(outcome, .ignore)
    }

    func testAccountNeverStoredEvenWhenNotBlocked() {
        // The account row must never become the stored selection.
        for multiple in [true, false] {
            let outcome = SidebarNavigationPolicy.resolveSelection(
                requested: .account, isNested: false, isSettingsSubPage: false, hasMultipleProfiles: multiple
            )
            XCTAssertNotEqual(outcome, .select(.account))
        }
    }

    // MARK: - fallbackTab

    func testFreshSignInOnSettingsFallsBackToHome() {
        XCTAssertEqual(
            SidebarNavigationPolicy.fallbackTab(currentlySelected: .settings, freshlySignedIn: true, discoverHidden: false),
            .home
        )
    }

    func testFreshSignInElsewhereStaysPut() {
        XCTAssertNil(
            SidebarNavigationPolicy.fallbackTab(currentlySelected: .search, freshlySignedIn: true, discoverHidden: false)
        )
    }

    func testDiscoverHiddenWhileSelectedFallsBackToHome() {
        XCTAssertEqual(
            SidebarNavigationPolicy.fallbackTab(currentlySelected: .discover, freshlySignedIn: false, discoverHidden: true),
            .home
        )
    }

    func testDiscoverHiddenWhileElsewhereStaysPut() {
        XCTAssertNil(
            SidebarNavigationPolicy.fallbackTab(currentlySelected: .home, freshlySignedIn: false, discoverHidden: true)
        )
    }

    func testNoTriggerMeansStayPut() {
        XCTAssertNil(
            SidebarNavigationPolicy.fallbackTab(currentlySelected: .settings, freshlySignedIn: false, discoverHidden: false)
        )
    }
}
