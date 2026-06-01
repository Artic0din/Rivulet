# Rivulet Release Checklist

Status: approved
Owner: Project Owner
Last updated: 2026-06-01

Use this checklist before TestFlight or App Store release candidates. This checklist does not replace Epic 0 governance or Epic 5 release readiness. It is the PR/CI setup release companion.

## Governance

- [ ] Release PR references the current epic/work package.
- [ ] Evidence IDs are listed.
- [ ] Known limitations are listed.
- [ ] Dependency assumptions are listed.
- [ ] Open debt is reviewed and either closed, reduced, or explicitly accepted.
- [ ] No unresolved governance blockers remain.
- [ ] Human/project-owner approval is recorded.
- [ ] Manual merge only.

## Deterministic CI

- [ ] Governance validation passes.
- [ ] CSV validation passes.
- [ ] Privacy manifest validation passes.
- [ ] Secret scan passes.
- [ ] tvOS build passes.
- [ ] Targeted tests pass.
- [ ] No AI review check is required by branch protection.

## Privacy

- [ ] `Rivulet/PrivacyInfo.xcprivacy` is present and current.
- [ ] `TopShelfExtension/PrivacyInfo.xcprivacy` is present and current.
- [ ] Privacy disclosure matrix reflects any changed data flows.
- [ ] Top Shelf payloads were reviewed for token-bearing URLs.
- [ ] Deep links and `NSUserActivity` paths were reviewed for secret-free payloads.
- [ ] Local network and ATS assumptions are documented.

## Secrets

- [ ] `Rivulet/Config/Secrets.swift` is not committed.
- [ ] `Rivulet/Config/Secrets.swift.template` contains placeholders only.
- [ ] No real Sentry DSN is committed.
- [ ] No Plex token, PIN, credential, signing certificate, provisioning profile, App Store key, or API key is committed.
- [ ] Gitleaks passes on the release PR.

## Sentry And dSYM

- [ ] Project Owner confirms `Secrets.sentryDSN` points to a Rivulet-owned Sentry project, or Release Sentry startup is explicitly disabled.
- [ ] Sentry release name and distribution/version mapping are documented for the build.
- [ ] dSYM upload path is verified for the archive/build process.
- [ ] Sentry debug-symbol upload warnings are reviewed and either fixed or accepted with documented rationale.
- [ ] Sentry redaction policy remains in effect for tokens, URLs, credentials, PINs, request payloads, and playback diagnostics.
- [ ] Crash reporting disclosure remains accurate in the privacy manifest and privacy disclosure matrix.

## Real Apple TV Validation

Required for release candidates.

- [ ] App launches on a physical Apple TV.
- [ ] Sign-in or existing credential reload works.
- [ ] Server selection works.
- [ ] Home loads without blocking on optional provider failures.
- [ ] Browse and detail navigation work.
- [ ] Playback starts for at least one direct-play-compatible sample.
- [ ] Play, pause, seek, and exit playback work.
- [ ] Focus returns to an expected location after playback exit.
- [ ] Top Shelf does not expose token-bearing URLs in logs or payload review evidence.
- [ ] Device, tvOS version, media sample, and result are recorded.

## Playback Validation

Use the Epic 0 media validation corpus when applicable.

- [ ] MP4 Direct Play checked.
- [ ] MKV Direct Play or retained route behavior checked.
- [ ] HLS route checked where applicable.
- [ ] SDR checked.
- [ ] HDR10/HDR10+/Dolby Vision checked where available.
- [ ] AAC Stereo checked.
- [ ] Dolby Atmos or retained limitation documented.
- [ ] SRT/ASS/PGS subtitle behavior checked where relevant.
- [ ] Large bitrate sample checked where available.
- [ ] Movie and TV episode samples checked.
- [ ] Live TV sample checked only if Live TV is in scope and enabled.

## App Store / TestFlight

- [ ] Version and build number are correct.
- [ ] Release notes are prepared.
- [ ] App Store privacy disclosures match current manifests and matrix.
- [ ] Entitlements are reviewed.
- [ ] Signing assets are not committed.
- [ ] TestFlight build uploads successfully.
- [ ] Any tester-facing known limitations are documented.

## AI Advisory Review

- [ ] Codex advisory review is requested or automatic Codex review is enabled.
- [ ] Sentry Seer review is considered for crash/release-risk changes.
- [ ] Greptile review is considered if secondary advisory review is useful.
- [ ] AI findings are addressed or explicitly dismissed.
- [ ] AI review is not treated as merge authority.

## Release Decision

Decision:

- [ ] Ship.
- [ ] Ship with accepted debt.
- [ ] Do not ship.

Decision notes:

```text
<evidence IDs, accepted debt, limitations, and owner sign-off>
```
