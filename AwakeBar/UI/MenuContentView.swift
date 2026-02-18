import AppKit
import SwiftUI

struct MenuContentView: View {
    private static let onCircleColor = Color(red: 0.04, green: 0.52, blue: 1.0)

    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            fullAwakeRow

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

            Toggle("", isOn: fullAwakeBinding)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .disabled(controller.isApplyingFullAwakeChange)
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
        .help("ON keeps your Mac awake with the lid open and closed. OFF restores normal macOS sleep settings.")
    }

    private var launchAtLoginRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(controller.launchAtLoginEnabled ? .blue : .secondary)

            Text("Start at Login")
                .font(.system(size: 13, weight: .medium))

            Spacer(minLength: 8)

            Toggle("", isOn: launchAtLoginBinding)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .blue))
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
        .help("Launches AwakeBar automatically after sign in.")
    }

    private var fullAwakeBinding: Binding<Bool> {
        Binding(
            get: { controller.isFullAwakeEnabled },
            set: { controller.requestFullAwakeChange($0) }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { controller.launchAtLoginEnabled },
            set: { controller.setLaunchAtLoginEnabled($0) }
        )
    }

    private var fullAwakeMenuIconName: String {
        MenuIconCatalog.fullAwakeToggleAssetName(isOn: controller.isFullAwakeEnabled)
    }
}
