---
doc_type: feature_spec
id: F-003
name: Closed-Lid Daemon Control
status: active
owner: dshakiba
parent: null
children: []
aliases:
  - Closed-Lid Admin Control
version: 2.0.0
last_reviewed: 2026-02-18
tags:
  - power
  - admin
  - daemon
risk_level: high
dependencies:
  - F-002
  - F-004
---

# [F-003] Closed-Lid Daemon Control

## Summary

Provide closed-lid keep-awake control using a privileged LaunchDaemon + XPC helper with guided setup and no runtime `sudo`/AppleScript fallback.

## Goals

- Remove repeated password prompts during normal closed-lid toggles.
- Keep a narrow privileged command surface (`pmset` and deterministic legacy cleanup).
- Preserve explicit user control and clear setup state in the menu UI.

## Non-Goals

- Promising permanent Touch ID or PAM behavior across macOS variants.
- Supporting legacy runtime paths (`sudo`, AppleScript, ad-hoc PAM edits) after cutover.

## Requirements

- R1: Closed-lid operations must use daemon-backed XPC only; no runtime fallback to legacy privilege paths.
- R2: Setup status must map to `notInApplications`, `notRegistered`, `approvalRequired`, `ready`, or `unavailable`.
- R3: Setup registration must use `SMAppService.daemon(plistName:)` and approval CTA must open Login Items settings.
- R4: Closed-lid control must stay disabled in UI until setup state is `ready`.
- R5: Privileged helper must support `ping`, `setSleepDisabled`, `readSleepDisabled`, and legacy cleanup only.
- R6: App-to-helper and helper-to-app connections must enforce code-signing requirements (bundle identifier + team when configured).
- R7: Legacy cleanup must backup first, remove AwakeBar-owned sudoers artifacts, and only modify PAM when content matches known managed patterns.
- R8: Legacy cleanup must be idempotent via persisted migration marker and run only after helper health is confirmed.
- R9: Relaunch must not auto-enable closed-lid, but must detect external `SleepDisabled=1` when helper is ready.

<!-- AUTOGEN:REQUIREMENTS_CHECKLIST -->
- [x] R1
- [x] R2
- [x] R3
- [x] R4
- [x] R5
- [x] R6
- [x] R7
- [x] R8
- [x] R9

## Acceptance Criteria

- AC1: First-run closed-lid flow shows setup CTA and transitions to `ready` after registration/approval.
- AC2: Once helper is ready, toggling closed-lid mode does not require repeated password prompts.
- AC3: Untrusted XPC clients are rejected.
- AC4: Legacy cleanup backs up files and skips unmanaged PAM content without destructive edits.
- AC5: Runtime code contains no AppleScript/`sudo` closed-lid execution path.

<!-- AUTOGEN:ACCEPTANCE_CHECKLIST -->
- [x] AC1
- [x] AC2
- [x] AC3
- [x] AC4
- [x] AC5

## Traceability

<!-- AUTOGEN:TRACEABILITY -->
| Item | Type | Evidence |
|---|---|---|
| R1 | code | AwakeBar/Services/ClosedLidPmsetController.swift |
| R1 | code | AwakeBar/Services/PrivilegedDaemonClient.swift |
| R2 | code | AwakeBar/Services/ClosedLidSetupController.swift |
| R2 | test | AwakeBarTests/ClosedLidSetupControllerTests.swift |
| R3 | code | AwakeBar/Services/ClosedLidSetupController.swift |
| R4 | code | AwakeBar/UI/MenuContentView.swift |
| R5 | code | AwakeBarShared/AwakeBarPrivilegedServiceXPC.swift |
| R5 | code | AwakeBarPrivilegedHelper/PrivilegedService.swift |
| R6 | code | AwakeBarPrivilegedHelper/main.swift |
| R6 | code | AwakeBarPrivilegedHelper/PrivilegedService.swift |
| R6 | code | AwakeBar/Services/PrivilegedDaemonClient.swift |
| R7 | code | AwakeBarPrivilegedHelper/LegacyCleanupManager.swift |
| R7 | test | AwakeBarPrivilegedHelperTests/LegacyCleanupPolicyTests.swift |
| R8 | code | AwakeBar/App/MenuBarController.swift |
| R8 | code | AwakeBar/State/AppStateStore.swift |
| R9 | code | AwakeBar/App/MenuBarController.swift |
| R9 | test | AwakeBarTests/ClosedLidPmsetControllerTests.swift |
| AC1 | test | AwakeBarTests/ClosedLidSetupControllerTests.swift |
| AC2 | manual | Toggle closed-lid mode repeatedly after setup with no auth prompt |
| AC3 | code | AwakeBarPrivilegedHelper/PrivilegedService.swift |
| AC4 | test | AwakeBarPrivilegedHelperTests/LegacyCleanupPolicyTests.swift |
| AC5 | code | AwakeBar/Services/ClosedLidPmsetController.swift |

## Children

<!-- AUTOGEN:CHILDREN -->
- None

## References

<!-- AUTOGEN:REFERENCES -->
- [F-002]
- [F-004]
- [ADR-0001](../DECISIONS/ADR-0001-privileged-daemon-cutover.md)

## API Contract

<!-- AUTOGEN:API_CONTRACT_SUMMARY -->
- `ClosedLidSetupControlling.refreshStatus()`
- `ClosedLidSetupControlling.startSetup()`
- `ClosedLidSleepControlling.setEnabled(_:)`
- `AwakeBarPrivilegedServiceXPC`

## Impact

<!-- AUTOGEN:IMPACT_MAP -->
- Closed-lid control now depends on helper packaging, registration, and approval lifecycle.
- Migration removes prior local privilege artifacts only after helper readiness.

## Security

<!-- AUTOGEN:SECURITY_CHECKLIST -->
- [x] No credential storage in app/runtime paths
- [x] Narrow helper command surface (`pmset` + cleanup)
- [x] Bidirectional code-signing requirement checks
- [x] Backup-first cleanup with guarded PAM modifications

## Budget

<!-- AUTOGEN:BUDGET_CHECKLIST -->
- [x] No continuous polling; setup checks and probes are event-driven
- [x] Cleanup runs once after readiness and is marked complete

## Table of Contents

<!-- AUTOGEN:TOC -->
- Summary
- Goals
- Requirements
- Acceptance Criteria

<!-- DO NOT EDIT BELOW (AUTOGENERATED) -->

## Changelog

- 2026-02-17: Initial spec created.
- 2026-02-17: Added one-time passwordless setup with prompt fallback behavior.
- 2026-02-18: Hard cutover to LaunchDaemon + XPC helper with setup-gated runtime.
