# Glossary

- **Full Awake**: Unified ON mode that keeps the Mac awake by enabling both open-lid assertions and closed-lid sleep disable.
- **Closed-Lid Mode**: Privileged system setting path that applies `pmset -a disablesleep 1` through helper XPC.
- **External Closed-Lid Active**: Internal detection that `SleepDisabled=1` is active outside the current app-managed session.
- **Privileged Helper**: LaunchDaemon-installed executable handling `pmset` and migration cleanup through XPC.
- **Setup Required**: Menu state where closed-lid actions are blocked until helper registration/approval is complete.
- **SMAppService**: Apple API used for main app login items and daemon helper registration.
- **Legacy Cleanup**: Backup-first one-time removal of AwakeBar-owned sudoers/PAM artifacts from pre-daemon versions.
- **Template Rendering Intent**: Asset catalog setting allowing menu icons to adopt system tint instead of baked colors.
- **Notarization**: Apple service validation required for trusted macOS app distribution.
