import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(controller.statusText)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .help(controller.statusDetailText)

                    Spacer(minLength: 8)

                    Image(systemName: statusSymbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(statusColor)
                }

                Text(controller.statusDetailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let message = controller.state.transientErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Toggle(
                isOn: Binding(
                    get: { controller.isOpenLidEnabled },
                    set: { controller.setOpenLidEnabled($0) }
                )
            ) {
                Label("Full Caffeine", systemImage: "bolt.circle.fill")
            }
            .help("Prevents idle and display sleep while your Mac stays open.")

            Toggle(
                isOn: Binding(
                    get: { controller.isClosedLidToggleOn },
                    set: { controller.requestClosedLidChange($0) }
                )
            ) {
                Label("Closed-Lid Mode (Admin)", systemImage: "lock.shield.fill")
            }
            .disabled(controller.isApplyingClosedLidChange)
            .help("Uses administrator permission to run: pmset -a disablesleep 1 or 0.")

            if controller.isApplyingClosedLidChange {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Waiting for administrator authorization...")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Toggle(
                isOn: Binding(
                    get: { controller.launchAtLoginEnabled },
                    set: { controller.setLaunchAtLoginEnabled($0) }
                )
            ) {
                Label("Start automatically at login", systemImage: "arrow.triangle.2.circlepath")
            }
            .help("Launch AwakeBar automatically after you sign in.")

            Divider()

            Button {
                Task {
                    await controller.turnEverythingOff()
                }
            } label: {
                Label("Turn Everything Off", systemImage: "power.circle")
            }
            .disabled(!controller.isOpenLidEnabled && !controller.isClosedLidToggleOn)
            .help("Turns off Full Caffeine and Closed-Lid Mode.")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "xmark.circle")
            }
            .help("Closes AwakeBar.")

            Text("Hover any control to see quick help.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(minWidth: 340)
    }

    private var statusColor: Color {
        switch controller.mode {
        case .off:
            return .secondary
        case .openLid:
            return .green
        case .closedLid:
            return .orange
        case .externalClosedLid:
            return .yellow
        }
    }

    private var statusSymbol: String {
        switch controller.mode {
        case .off:
            return "moon.zzz"
        case .openLid:
            return "bolt.fill"
        case .closedLid:
            return "lock.fill"
        case .externalClosedLid:
            return "exclamationmark.shield"
        }
    }
}
