---
doc_type: adr
adr_id: ADR-0001
title: Replace Legacy Privilege Path with SMAppService Daemon + XPC
status: accepted
deciders:
  - dshakiba
date: 2026-02-18
supersedes: null
superseded_by: null
related_features:
  - F-003
  - F-004
---

# ADR-0001: Replace Legacy Privilege Path with SMAppService Daemon + XPC

## Context

Prior closed-lid control relied on runtime `sudo`/AppleScript/PAM/sudoers behavior that varied across macOS versions, produced repeated authentication prompts, and expanded the runtime attack surface.

## Decision

Adopt a hard cutover to an `SMAppService` LaunchDaemon + XPC helper architecture for privileged closed-lid operations. The app uses guided setup states and blocks closed-lid actions until helper registration and approval are complete. Runtime fallback to legacy privilege paths is removed.

## Consequences

- Closed-lid toggles become daemon-backed operations with predictable command scope.
- User flow requires app installation in `/Applications` for helper setup.
- Migration cleanup must safely backup and remove AwakeBar-owned legacy privilege artifacts.
- Build/release process now requires proper signing and notarization automation.

## Alternatives Considered

- Keep legacy `sudo`/AppleScript/PAM fallback paths (rejected: unstable behavior and larger risk surface).
- Keep mixed mode with daemon primary and legacy fallback (rejected: complexity and security ambiguity).
