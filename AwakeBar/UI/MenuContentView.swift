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

            if !controller.isClosedLidReady {
                closedLidSetupCard
            }

            if let notice = controller.state.legacyCleanupNotice {
                Label(notice, systemImage: "checkmark.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(spacing: 8) {
                menuButton(
                    title: "Keep Awake (Lid Open)",
                    icon: .asset(openLidMenuIconName),
                    state: controller.isOpenLidEnabled ? .on : .off,
                    isSelected: controller.isOpenLidEnabled,
                    tint: controller.isOpenLidEnabled ? .accentColor : .secondary,
                    helpText: "Keeps your Mac and display awake while the lid is open."
                ) {
                    controller.setOpenLidEnabled(!controller.isOpenLidEnabled)
                }

                menuButton(
                    title: "Keep Awake (Lid Closed)",
                    icon: .asset(closedLidMenuIconName),
                    state: closedLidRowState,
                    isSelected: closedLidRowState.isSelected,
                    tint: closedLidRowState.isSelected ? .accentColor : .secondary,
                    isBusy: controller.isApplyingClosedLidChange,
                    disabled: !controller.isClosedLidReady || controller.isApplyingClosedLidChange,
                    helpText: "Keeps your Mac running with the lid closed. Requires one-time helper setup and approval in System Settings."
                ) {
                    controller.requestClosedLidChange(!controller.isClosedLidToggleOn)
                }

                menuButton(
                    title: "Start at Login",
                    icon: .system("arrow.triangle.2.circlepath"),
                    state: controller.launchAtLoginEnabled ? .on : .off,
                    isSelected: controller.launchAtLoginEnabled,
                    tint: controller.launchAtLoginEnabled ? .accentColor : .secondary,
                    helpText: "Launches AwakeBar automatically after you sign in."
                ) {
                    controller.setLaunchAtLoginEnabled(!controller.launchAtLoginEnabled)
                }
            }

            Divider()

            VStack(spacing: 8) {
                menuButton(
                    title: "Turn Everything Off",
                    icon: .system("power"),
                    state: nil,
                    isSelected: false,
                    tint: .red,
                    disabled: !controller.isOpenLidEnabled && !controller.isClosedLidToggleOn,
                    helpText: "Turns off both Keep Awake modes."
                ) {
                    Task {
                        await controller.turnEverythingOff()
                    }
                }

                menuButton(
                    title: "Quit AwakeBar",
                    icon: .system("xmark"),
                    state: nil,
                    isSelected: false,
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

    private var closedLidSetupCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(controller.closedLidSetupState.title)
                .font(.system(size: 12, weight: .semibold))

            Text(controller.closedLidSetupState.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("Enable Closed-Lid Control") {
                    controller.requestClosedLidSetup()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(controller.closedLidSetupState == .approvalRequired || controller.closedLidSetupState == .notInApplications)

                if controller.closedLidSetupState == .approvalRequired {
                    Button("Open Login Items Settings") {
                        controller.openClosedLidApprovalSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
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
        icon: ActionIcon,
        state: RowState?,
        isSelected: Bool,
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
                isSelected: isSelected,
                tint: tint,
                isBusy: isBusy
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(helpText)
    }

    private var openLidMenuIconName: String {
        MenuIconCatalog.dropdownPair(for: .openLid).assetName(for: controller.isOpenLidEnabled)
    }

    private var closedLidMenuIconName: String {
        MenuIconCatalog.dropdownPair(for: .closedLid).assetName(for: closedLidRowState.isSelected)
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
            return "Normal Sleep"
        case .openLid:
            return "Stay Awake (Lid Open)"
        case .closedLid:
            return "Stay Awake (Lid Closed)"
        case .externalClosedLid:
            return "Stay Awake (External)"
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
    private static let onCircleColor = Color(red: 0.04, green: 0.52, blue: 1.0)

    let title: String
    let icon: ActionIcon
    let state: RowState?
    let isSelected: Bool
    let tint: Color
    let isBusy: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isSelected ? Self.onCircleColor : Color.primary.opacity(0.08))
                    .frame(width: 26, height: 26)

                icon.image(isSelected: isSelected, tint: tint)
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
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

private enum ActionIcon: Equatable {
    case system(String)
    case asset(String)

    @ViewBuilder
    func image(isSelected: Bool, tint: Color) -> some View {
        switch self {
        case .system(let iconName):
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isSelected ? .white : tint)
        case .asset(let assetName):
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(isSelected ? .white : tint)
        }
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

    var isSelected: Bool {
        switch self {
        case .on, .external:
            return true
        case .off:
            return false
        }
    }
}
