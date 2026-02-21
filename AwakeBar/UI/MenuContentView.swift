import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(controller.fullAwakeSwitchIsOn ? Color.blue : Color.secondary.opacity(0.25))
                    .frame(width: 10, height: 10)

                Text(statusText)
                    .font(.system(size: 12, weight: .semibold))

                Spacer(minLength: 6)

                if controller.isApplyingFullAwakeChange {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Toggle(isOn: fullAwakeBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Full Awake")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Keeps your Mac awake with the lid open and closed.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
            .tint(.blue)
            .disabled(controller.isApplyingFullAwakeChange)
            .help("ON keeps your Mac awake with the lid open and closed. OFF restores normal sleep settings.")

            if showsSetupAction {
                Button("Finish Setup…") {
                    controller.openLoginItemsSettingsForApproval()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.blue)
            }

            if let message = stateMessage {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Text("Settings")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            if controller.showsLockOnLidCloseSetting {
                Toggle("Lock Computer on Lid Close", isOn: lockOnLidCloseBinding)
                    .toggleStyle(.switch)
                    .font(.system(size: 12))
                    .disabled(!controller.canEnableLockOnLidClose)
                    .help("Lock your Mac after a lid-close event while Full Awake is ON.")

                if let reason = controller.lockOnLidCloseUnavailableReason {
                    Text("Unavailable on this Mac: \(reason)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Toggle("Launch at Login", isOn: launchAtLoginBinding)
                .toggleStyle(.switch)
                .font(.system(size: 12))
                .help("Automatically start AwakeBar after you sign in.")

            Divider()

            Button("Quit AwakeBar") {
                controller.requestQuit()
            }
            .buttonStyle(.plain)
            .font(.system(size: 13))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 238)
        .onAppear {
            controller.refreshSetupState()
        }
    }

    private var showsSetupAction: Bool {
        guard !controller.isFullAwakeEnabled else {
            return false
        }
        if case .approvalRequired = controller.closedLidSetupState {
            return true
        }
        return false
    }

    private var stateMessage: String? {
        if let blocked = controller.fullAwakeBlockedMessage, !controller.isFullAwakeEnabled {
            return blocked
        }
        if let pendingRestore = controller.pendingRestoreMessage {
            return pendingRestore
        }
        return controller.state.transientErrorMessage
    }

    private var fullAwakeBinding: Binding<Bool> {
        Binding(
            get: { controller.fullAwakeSwitchIsOn },
            set: { isOn in
                controller.requestFullAwakeChange(isOn)
            }
        )
    }

    private var lockOnLidCloseBinding: Binding<Bool> {
        Binding(
            get: { controller.lockOnLidCloseEnabled },
            set: { isOn in
                controller.setLockOnLidCloseEnabled(isOn)
            }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { controller.launchAtLoginEnabled },
            set: { isOn in
                controller.setLaunchAtLoginEnabled(isOn)
            }
        )
    }

    private var statusText: String {
        if controller.isApplyingFullAwakeChange {
            return controller.fullAwakeSwitchIsOn ? "Turning ON…" : "Turning OFF…"
        }
        return controller.isFullAwakeEnabled ? "Awake is ON" : "Awake is OFF"
    }
}
