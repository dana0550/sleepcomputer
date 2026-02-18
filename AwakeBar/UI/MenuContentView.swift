import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerCard

            if let message = controller.state.transientErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(spacing: 8) {
                menuButton(
                    title: "Full Caffeine",
                    icon: "bolt.fill",
                    state: controller.isOpenLidEnabled ? .on : .off,
                    helpText: "Keeps your Mac awake while the lid is open (prevents idle and display sleep)."
                ) {
                    controller.setOpenLidEnabled(!controller.isOpenLidEnabled)
                }

                menuButton(
                    title: "Closed Lid (Admin)",
                    icon: "lock.fill",
                    state: closedLidRowState,
                    isBusy: controller.isApplyingClosedLidChange,
                    disabled: controller.isApplyingClosedLidChange,
                    helpText: "Uses one-time admin setup for passwordless toggles. If unavailable, macOS will prompt for admin access."
                ) {
                    controller.requestClosedLidChange(!controller.isClosedLidToggleOn)
                }

                menuButton(
                    title: "Start at Login",
                    icon: "arrow.triangle.2.circlepath",
                    state: controller.launchAtLoginEnabled ? .on : .off,
                    helpText: "Launches AwakeBar automatically after you sign in."
                ) {
                    controller.setLaunchAtLoginEnabled(!controller.launchAtLoginEnabled)
                }
            }

            Divider()

            VStack(spacing: 8) {
                menuButton(
                    title: "Turn Everything Off",
                    icon: "power",
                    state: nil,
                    tint: .red,
                    disabled: !controller.isOpenLidEnabled && !controller.isClosedLidToggleOn,
                    helpText: "Turns off Full Caffeine and Closed Lid mode."
                ) {
                    Task {
                        await controller.turnEverythingOff()
                    }
                }

                menuButton(
                    title: "Quit AwakeBar",
                    icon: "xmark",
                    state: nil,
                    tint: .secondary,
                    helpText: "Closes the app."
                ) {
                    NSApplication.shared.terminate(nil)
                }
            }

            Text("Hover any button for details.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(minWidth: 338)
    }

    private var headerCard: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 24, height: 24)

                Image(systemName: statusSymbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("AwakeBar")
                    .font(.system(size: 13, weight: .semibold))

                Text(modeSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .help(controller.statusDetailText)

            Spacer(minLength: 8)

            StateBadge(state: modeRowState)
        }
    }

    private func menuButton(
        title: String,
        icon: String,
        state: RowState?,
        tint: Color = .accentColor,
        isBusy: Bool = false,
        disabled: Bool = false,
        helpText: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ActionRow(
                title: title,
                icon: icon,
                state: state,
                tint: tint,
                isBusy: isBusy
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(helpText)
    }

    private var closedLidRowState: RowState {
        if controller.state.closedLidEnabledByApp {
            return .on
        }
        if controller.state.externalClosedLidDetected {
            return .external
        }
        return .off
    }

    private var modeSummaryText: String {
        switch controller.mode {
        case .off:
            return "Sleep Normal"
        case .openLid:
            return "Open-Lid Awake"
        case .closedLid:
            return "Closed-Lid Awake"
        case .externalClosedLid:
            return "External Sleep Lock"
        }
    }

    private var modeRowState: RowState {
        switch controller.mode {
        case .off:
            return .off
        case .openLid, .closedLid:
            return .on
        case .externalClosedLid:
            return .external
        }
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

private struct ActionRow: View {
    let title: String
    let icon: String
    let state: RowState?
    let tint: Color
    let isBusy: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 22, height: 22)

                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(title)
                .font(.system(size: 13, weight: .medium))

            Spacer(minLength: 8)

            if isBusy {
                ProgressView()
                    .controlSize(.small)
            }

            if let state {
                StateBadge(state: state)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

private struct StateBadge: View {
    let state: RowState

    var body: some View {
        Text(state.title)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(state.color.opacity(0.18))
            )
            .foregroundStyle(state.color)
    }
}

private enum RowState {
    case on
    case off
    case external

    var title: String {
        switch self {
        case .on:
            return "ON"
        case .off:
            return "OFF"
        case .external:
            return "EXT"
        }
    }

    var color: Color {
        switch self {
        case .on:
            return .green
        case .off:
            return .secondary
        case .external:
            return .orange
        }
    }
}
