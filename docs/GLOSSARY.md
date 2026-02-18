# Glossary

- **Full Caffeine**: Open-lid mode that asserts no idle sleep and no display sleep.
- **Closed-Lid Mode**: Privileged system setting that disables system sleep globally.
- **External Closed-Lid Active**: `SleepDisabled=1` detected at startup but not enabled in current app session.
- **Privileged Helper**: LaunchDaemon-installed executable handling `pmset` and migration cleanup through XPC.
- **Setup Required**: Menu state where closed-lid actions are blocked until helper registration/approval is complete.
