# ADR-004: ATS and Trust Policy

**Date**: 2026-05-31  
**Status**: accepted  
**Owner**: Ryan Foyle  
**Review cadence**: Review before Epic 1 closes, before Epic 5 release validation, and after any trust-model change

## Context

Rivulet currently ships with `NSAllowsArbitraryLoads = true` in `Rivulet/Info.plist`. That disables ATS application-wide. The repo audit also identifies custom trust handling that is broader than acceptable, especially in thumbnail and Plex certificate delegate paths.

Rivulet does need to support local Plex servers, loopback remux playback, and some non-public-network device surfaces. It does not need an unlimited app-wide permission to ignore transport protections.

## Decision

Rivulet will use a scoped ATS and trust model.

The allowed baseline is:

- `NSAllowsLocalNetworking = true` for local-network Plex and device flows
- loopback playback support for local remux paths
- narrowly documented ATS exceptions only where technically required
- trust exceptions only where they can be tied to explicit, approved server identity rules

App-wide `NSAllowsArbitraryLoads` is not an acceptable steady-state configuration.

## Alternatives Considered

### Alternative 1: Keep app-wide `NSAllowsArbitraryLoads`

- **Pros**: Simplest compatibility path; least short-term breakage risk
- **Cons**: Weakens network protections globally; increases App Review risk; makes actual exceptions invisible
- **Why not**: Rejected because it is broader than the product needs and undermines reviewability

### Alternative 2: Enforce full ATS and default trust everywhere immediately

- **Pros**: Strongest default posture
- **Cons**: Could break local Plex, self-signed server workflows, device discovery, and loopback playback if done blindly
- **Why not**: Rejected because Rivulet has legitimate local-network requirements that must be handled explicitly

### Alternative 3: Manage exceptions only in code-level trust delegates

- **Pros**: Keeps `Info.plist` simpler
- **Cons**: Hard to audit; easier to over-broaden trust behavior; duplicates logic
- **Why not**: Rejected because policy should be visible in both configuration and code

## Consequences

### Positive

- ATS behavior becomes auditable
- Local and special-case networking can still be supported without broad global exceptions
- Trust handling becomes a governable security surface instead of ad-hoc local code

### Negative

- Tightening ATS or trust rules may reveal compatibility problems that were previously hidden
- Some local or self-signed configurations may need explicit review or fallback behavior

### Risks

- Scope-down work could break real user flows if the inventory misses a required exception
- Teams may attempt to reintroduce broad trust bypasses when debugging connection issues

Mitigation:

- Keep the network surface inventory current
- Require any trust override to cite this ADR and its inventory entry
- Revalidate local Plex, loopback remux, and Live TV flows after ATS or trust changes
