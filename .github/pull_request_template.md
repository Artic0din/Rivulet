<!-- AGENTS.md governs this repo. Keep PRs small, reversible, and tied to one approved objective. -->

## Objective

Describe the single PR objective and the approved epic/work package it belongs to.

## Scope

- [ ] This PR is one logical change.
- [ ] This PR does not include unrelated refactors.
- [ ] Any generated or `.pbxproj` churn is explained.

## Governance

- Epic/work package:
- Evidence IDs:
- Debt IDs opened/updated/closed:
- Known limitations:
- Dependency assumptions:

## Validation

- [ ] Deterministic CI passes.
- [ ] Relevant local build/test commands are listed below.
- [ ] Privacy manifest impact reviewed.
- [ ] Governance/CSV/docs checks pass where applicable.
- [ ] Secret scan passes.

Commands run:
```text
<paste commands and results>
```

## Security And Privacy

- [ ] No secrets, tokens, DSNs, signing assets, or credentials committed.
- [ ] Token-bearing URLs are not logged or sent to Sentry.
- [ ] Sentry/logging changes follow redaction policy.
- [ ] PrivacyInfo.xcprivacy impact reviewed.

## Playback / Apple TV Validation

Required if the PR touches playback, routing, focus/navigation, Top Shelf, media loading, or player diagnostics.

- [ ] Real Apple TV validation completed.
- [ ] Not applicable because this PR does not affect runtime playback/focus/device-only behavior.

Device validation notes:
```text
<device, tvOS version, scenario, result>
```

## AI Review

- [ ] Codex advisory review requested or automatic Codex review enabled.
- [ ] Sentry Seer review considered if crash/performance risk is relevant.
- [ ] Greptile review considered if secondary advisory review is useful.
- [ ] AI findings are advisory only; deterministic CI and Ryan/project-owner review remain merge authorities.

## Merge

- [ ] Human/project-owner review complete.
- [ ] Required deterministic checks pass.
- [ ] Manual merge only.
