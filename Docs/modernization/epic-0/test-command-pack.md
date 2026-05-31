# Epic 0 Test Command Pack

## Purpose

This command pack defines the baseline verification commands for Rivulet modernization work. These commands are the default proof points for Epic 0 and later epics unless a work package defines stricter commands.

## Rules

1. A completion claim requires fresh command output.
2. Command, destination, and result must be recorded in the evidence register or PR notes.
3. Partial verification is not a substitute for the required command.
4. Any failed command that blocks the changed area must be fixed or explicitly accepted as debt.

## Baseline Commands

### Build

```bash
xcodebuild -scheme Rivulet -destination 'platform=tvOS Simulator,name=Apple TV' build
```

Pass condition:

- Exit code `0`
- No build failure in app or test targets

### Targeted Credential Registry Verification

```bash
xcodebuild test -scheme Rivulet -destination 'platform=tvOS Simulator,name=Apple TV' -only-testing:RivuletTests/CredentialRegistryTests
```

Current baseline:

- Verified on 2026-05-31
- Result: `** TEST SUCCEEDED **`
- Notes: credential-storage tests are not currently red in this tree

Baseline supersession:

- Supersedes the older roadmap assumption that credential-storage tests were failing.
- Replacement evidence is `E0-TEST-002` in `Docs/modernization/epic-0/evidence-register.md`.
- Any Epic 1 change touching credential storage, keychain behavior, account tokens, server tokens, Plex Home user tokens, or PIN handling must re-run this command and attach reviewed evidence.

### Core Unit Test Suite

```bash
xcodebuild test -scheme Rivulet -destination 'platform=tvOS Simulator,name=Apple TV'
```

Pass condition:

- Exit code `0`
- No failed test cases

### Targeted Playback Routing Tests

```bash
xcodebuild test -scheme Rivulet -destination 'platform=tvOS Simulator,name=Apple TV' \
  -only-testing:RivuletTests/ContentRouterPlaybackPlanTests \
  -only-testing:RivuletTests/RouteAudioPolicyTests \
  -only-testing:RivuletTests/PlaybackStateTests
```

Use when:

- Changing routing, playback policy, or playback-state semantics

### Targeted Plex Network and Auth Tests

```bash
xcodebuild test -scheme Rivulet -destination 'platform=tvOS Simulator,name=Apple TV' \
  -only-testing:RivuletTests/PlexAuthManagerTests \
  -only-testing:RivuletTests/PlexNetworkManagerURLTests \
  -only-testing:RivuletTests/PlexWatchlistServiceTests
```

Use when:

- Changing auth, endpoint construction, token transport, watchlist, or discover behavior

### Targeted Search / Deep Link / Siri Validation

```bash
xcodebuild test -scheme Rivulet -destination 'platform=tvOS Simulator,name=Apple TV' \
  -only-testing:RivuletTests/DeepLinkHandlerDetailTests \
  -only-testing:RivuletTests/MediaItemEntityTests
```

Use when:

- Changing `NSUserActivity`, deep links, search indexing, or play/detail handoff behavior

## Missing but Required Test Lanes

The current repo does not yet have the following formal lanes, but Epic 0 treats them as required work:

- UI regression suite for home, preview, detail, playback, and settings
- Accessibility validation lane
- Performance lane with launch/home/preview/playback metrics
- Extension verification lane for Top Shelf behavior

These are missing capabilities, not optional nice-to-haves.

The governing flow inventory for regression scope lives in `Docs/modernization/epic-0/regression-matrix.md`.

## Manual Regression Pack

Until automated UI coverage exists, the following manual regression pack is mandatory for relevant user-facing changes:

1. Launch to Home
2. Sidebar navigation to Libraries, Search, Settings
3. Continue Watching resume flow
4. Poster -> preview -> detail -> back
5. Direct play or remux playback start
6. Subtitle or audio track selection
7. Playback exit and focus restoration
8. Top Shelf launch into play flow when Top Shelf is affected

## Evidence Format

Each command execution must capture:

- command used
- simulator or device
- build configuration
- result
- artifact path if an `.xcresult` bundle or screenshot set exists

Example:

```markdown
- Command: xcodebuild test -scheme Rivulet -destination 'platform=tvOS Simulator,name=Apple TV' -only-testing:RivuletTests/CredentialRegistryTests
- Device: Apple TV simulator
- Date: 2026-05-31
- Result: PASS
- Artifact: ~/Library/Developer/Xcode/DerivedData/.../Test-Rivulet-2026.05.31_18-41-40-+1000.xcresult
```

## Review Requirements

| Change Type | Minimum verification |
| --- | --- |
| Docs-only Epic 0 updates | Consistency review plus any commands explicitly cited |
| Auth/network/token changes | Build + targeted Plex auth/network tests |
| Credential storage or token persistence changes | Build + targeted credential registry verification + targeted Plex auth/network tests |
| Home/preview/detail changes | Build + relevant unit tests + manual regression pack |
| Playback changes | Build + targeted playback tests + media validation corpus run |
| Release gate validation | Full unit suite + full manual regression pack + accessibility and performance evidence |

## UAT Requirements

Epic 1 auth, server-selection, Plex Home, watchlist/discover, deep-link, and failure-state changes must also provide UAT evidence using the UAT matrix in `Docs/modernization/epic-0/regression-matrix.md`.

## Escalation

- If a required test command fails, the work package is not complete.
- If the required automated lane does not exist, the owning epic must provide manual evidence and record the automation gap as debt.
- If a prior assumption is invalidated by a fresh command, the fresh result wins immediately.
- If a command supersedes an older baseline assumption, the evidence register must record the supersession and replacement evidence ID.
