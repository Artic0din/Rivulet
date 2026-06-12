//  FeatureFlags.swift
//  Rivulet
//
//  Compile-time feature gates. Phase 1 of Docs/MIGRATION_PLAN.md hides Live TV
//  and Music behind these flags (default off) without deleting the code or the
//  SwiftData models, so on-disk stores stay valid. Flip a constant + rebuild to
//  re-enable. Not a Plex capability flag — see PlexLiveTVCapabilities for that.

enum FeatureFlags {
    /// Live TV / IPTV surface (sidebar section, settings, channel UI). Default off.
    static let liveTVEnabled = false
    /// Music surface (sidebar section, music hubs in Plex home/library/search, settings). Default off.
    static let musicEnabled = false
}
