# Glossary

- **Full Caffeine**: Open-lid mode that asserts no idle sleep and no display sleep.
- **Closed-Lid Mode**: Privileged system setting path that applies `pmset -a disablesleep 1` through helper XPC.
- **External Closed-Lid Active**: `SleepDisabled=1` detected at startup but not enabled in current app session.
- **Privileged Helper**: LaunchDaemon-installed executable handling `pmset` and migration cleanup through XPC.
- **Setup Required**: Menu state where closed-lid actions are blocked until helper registration/approval is complete.
- **SMAppService**: Apple API used for main app login items and daemon helper registration.
- **Legacy Cleanup**: Backup-first one-time removal of AwakeBar-owned sudoers/PAM artifacts from pre-daemon versions.
- **Template Rendering Intent**: Asset catalog setting allowing menu icons to adopt system tint instead of baked colors.
- **Notarization**: Apple service validation required for trusted macOS app distribution.
