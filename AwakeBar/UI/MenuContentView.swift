import AppKit
import SwiftUI

struct MenuContentView: View {
    private static let onCircleColor = Color(red: 0.04, green: 0.52, blue: 1.0)

    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            fullAwakeRow

            if let setupNotice = fullAwakeSetupNotice {
                setupNoticeRow(setupNotice)
            }

            if let message = controller.state.transientErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            launchAtLoginRow

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit AwakeBar")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Closes the app.")
        }
        .padding(12)
        .frame(minWidth: 260)
    }

    private var fullAwakeRow: some View {
        Button {
            controller.requestFullAwakeChange(!controller.isFullAwakeEnabled)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(controller.isFullAwakeEnabled ? Self.onCircleColor : Color.primary.opacity(0.08))
                        .frame(width: 26, height: 26)

                    Image(fullAwakeMenuIconName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(controller.isFullAwakeEnabled ? .white : .secondary)
                }

                Text("Full Awake")
                    .font(.system(size: 13, weight: .medium))

                Spacer(minLength: 8)

                if controller.isApplyingFullAwakeChange {
                    ProgressView()
                        .controlSize(.small)
                }

                InlineToggle(isOn: controller.isFullAwakeEnabled)
            }
        }
        .buttonStyle(.plain)
        .disabled(controller.isApplyingFullAwakeChange)
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
        .help("ON keeps your Mac awake with the lid open and closed. OFF restores normal macOS sleep settings.")
    }

    private var launchAtLoginRow: some View {
        Button {
            controller.setLaunchAtLoginEnabled(!controller.launchAtLoginEnabled)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(controller.launchAtLoginEnabled ? .blue : .secondary)

                Text("Start at Login")
                    .font(.system(size: 13, weight: .medium))

                Spacer(minLength: 8)

                InlineToggle(isOn: controller.launchAtLoginEnabled)
            }
        }
        .buttonStyle(.plain)
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
        .help("Launches AwakeBar automatically after sign in.")
    }

    @ViewBuilder
    private func setupNoticeRow(_ message: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.blue)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            if case .approvalRequired = controller.closedLidSetupState {
                Button("Open Settings") {
                    controller.openLoginItemsSettingsForApproval()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
        .padding(.horizontal, 8)
    }

    private var fullAwakeMenuIconName: String {
        MenuIconCatalog.fullAwakeToggleAssetName(isOn: controller.isFullAwakeEnabled)
    }

    private var fullAwakeSetupNotice: String? {
        guard !controller.isFullAwakeEnabled else {
            return nil
        }
        return controller.fullAwakeBlockedMessage
    }
}

private struct InlineToggle: View {
    let isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule(style: .continuous)
                .fill(isOn ? Color.blue : Color.secondary.opacity(0.35))
                .frame(width: 36, height: 20)

            Circle()
                .fill(.white)
                .frame(width: 16, height: 16)
                .padding(2)
        }
        .animation(.easeInOut(duration: 0.15), value: isOn)
    }
}
