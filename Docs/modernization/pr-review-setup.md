# Rivulet PR Review And CI Setup

Status: approved
Owner: Project Owner
Last updated: 2026-06-01

## Operating Model

Rivulet uses deterministic CI and human review as merge authorities. AI review is useful, but advisory.

| Role | Responsibility | Merge Authority |
| --- | --- | --- |
| Claude Code | Implementation agent for Epic 2 onward | No |
| Codex | Primary advisory AI reviewer in GitHub | No |
| Sentry Seer | Optional advisory bug-prediction and release-risk review | No |
| Greptile | Optional secondary advisory review | No |
| GitHub Actions | Deterministic required checks | Yes |
| Ryan / Project Owner | Final human review and manual merge | Yes |

## Required Merge Gates

Required branch-protection checks should be deterministic only:

- `Governance validation`
- `CSV validation`
- `Privacy manifest validation`
- `Gitleaks`
- `Repository secret pattern guard`
- `Build Rivulet`
- `Targeted Rivulet tests`

Human/project-owner approval is required. Manual merge only.

Do not require these as branch-protection checks:

- Codex review
- Claude Code
- Sentry Seer
- Greptile
- SwiftLint
- swift-format

SwiftLint and swift-format can become gates only after project-specific configs and a baseline are approved.

## CI Cost Awareness

Mac runners are expensive and slower than Linux runners. The setup separates cheap deterministic checks from tvOS build/test work:

- Governance, CSV, privacy manifest parsing, and secret scanning run on Ubuntu.
- tvOS build/test runs on macOS only.
- The tvOS workflow pins `macos-15` to stabilize hosted-runner image selection.
- The `macos-15` pin does not guarantee the hosted image contains the Xcode/tvOS 26 runtime required by Rivulet.
- If GitHub-hosted runners do not provide the required Xcode/tvOS 26 stack, tvOS build/test must remain visibly blocked or failing rather than falsely green.
- Update the pinned runner when GitHub provides a hosted runner with the required Rivulet Xcode/tvOS stack.
- The targeted test job depends on the build job to avoid spending macOS runner time when compilation already fails.
- This sequencing does not eliminate all compile work from `xcodebuild test`; deeper build/test optimization requires separate validation.
- tvOS simulator destinations include `OS=latest` to reduce destination ambiguity when a compatible runtime exists.
- `OS=latest` does not fix a missing simulator runtime.
- Workflows use `pull_request` and `push` to `main`; they do not run macOS jobs on feature-branch pushes.
- Workflows use concurrency cancellation to avoid paying for superseded runs.
- The tvOS workflow generates a placeholder `Rivulet/Config/Secrets.swift` from `Rivulet/Config/Secrets.swift.template` during CI. No DSN or secret is committed.

## Codex GitHub Review

Codex review must be configured through the Codex GitHub integration where available.

Setup expectations:

1. Install or enable the Codex GitHub integration for the repository.
2. Enable automatic Codex review if desired.
3. Use `@codex review` for manual review.
4. Keep repository review guidance in `AGENTS.md`.
5. Keep Codex advisory. Do not add Codex as a required branch-protection check.

Do not create `.github/workflows/codex-pr-review.yml` unless Ryan explicitly approves a custom workflow after confirming the Codex GitHub integration cannot meet the need.

## Claude Code

Claude Code is the implementation agent for Epic 2 onward.

The repository may keep an on-demand Claude Code workflow for `@claude` comments, but it must not be described as a primary reviewer, required check, or merge authority.

## Sentry Seer

Sentry Seer remains optional advisory review.

Use Seer for:

- crash-prone changes
- release-risk review
- playback or diagnostics changes that are likely to produce runtime failures
- post-release hardening

Do not require Seer in branch protection. Do not enable automatic patch PRs unless Ryan explicitly approves that workflow.

Sentry ownership must be resolved before release validation:

- confirm `Secrets.sentryDSN` points at a Rivulet-owned Sentry project, or
- explicitly disable Release Sentry startup before release.

## Greptile

Greptile remains optional secondary advisory review.

If enabled:

- configure through the Greptile GitHub app or `.greptile/` config
- use manual `@greptileai` review when useful
- keep status checks advisory and non-required
- do not use Greptile as merge authority

## PR Size Discipline

PRs should be small, reviewable, testable, and reversible.

- Target: about 200 changed lines.
- Hard review threshold: about 400 changed lines.
- Generated files and `.pbxproj` churn can be excluded from the size discussion, but must still be reviewed semantically.
- One logical change per PR.
- If a change spans two independent concerns, split it.

## Secret Scanning

Required deterministic secret checks:

- Gitleaks scans PR history with `fetch-depth: 0`.
- `.gitleaks.toml` retains the default rules and only allowlists known historical Plex XML `tagKey` metadata false positives.
- Repository pattern guards reject committed local secret files and high-risk literal secret shapes.
- `Rivulet/Config/Secrets.swift` must remain ignored and uncommitted.
- `Rivulet/Config/Secrets.swift.template` may contain placeholders only.

No real Sentry DSN, Plex token, signing certificate, provisioning profile, App Store key, API key, or credential may be committed.

## Privacy And Governance Validation

Required deterministic checks:

- app privacy manifest exists and parses as a plist
- Top Shelf privacy manifest exists and parses as a plist
- both manifests declare `NSPrivacyTracking=false`
- endpoint inventory CSV has required governance fields
- required Epic 0 governance docs exist
- `pull_request_target` is not used
- fake Codex review workflows are absent
- AI review is not documented as required branch protection or merge authority

## Real Apple TV Validation

GitHub Actions cannot replace real Apple TV validation.

Real device validation is required when a PR touches:

- playback routing
- RPlayer or AVPlayer behavior
- focus/navigation
- Top Shelf
- media loading
- player diagnostics
- HDR/Dolby Vision/audio route behavior

The PR must record device, tvOS version, scenario, and result.

## Branch Protection Recommendation

Recommended `main` branch protection:

- require a pull request before merge
- require at least one project-owner/human approval
- require conversation resolution
- require deterministic GitHub Actions checks only
- disable or avoid auto-merge for modernization work
- do not require Codex, Claude Code, Sentry Seer, or Greptile

## Superseded Files

The previous auto Claude review workflow is removed:

- `.github/workflows/claude-code-review.yml`

The previous documentation-only CI/Codex config examples are superseded:

- `Docs/ci.yml`
- `Docs/codex-review.yml`

The canonical GitHub files are:

- `.github/pull_request_template.md`
- `.github/CODEOWNERS`
- `.github/workflows/pr-checks.yml`
- `.github/workflows/secret-scan.yml`
- `.github/workflows/tvos-ci.yml`
