import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Status")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(controller.statusText)
                .font(.headline)
                .help(controller.statusDetailText)

            Text(controller.statusDetailText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let message = controller.state.transientErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Toggle(
                "Full Caffeine",
                isOn: Binding(
                    get: { controller.isOpenLidEnabled },
                    set: { controller.setOpenLidEnabled($0) }
                )
            )
            .help("Prevents idle and display sleep while your Mac stays open.")

            Toggle(
                "Closed-Lid Mode (Admin)",
                isOn: Binding(
                    get: { controller.isClosedLidToggleOn },
                    set: { controller.requestClosedLidChange($0) }
                )
            )
            .disabled(controller.isApplyingClosedLidChange)
            .help("Uses administrator permission to run: pmset -a disablesleep 1 or 0.")

            if controller.isApplyingClosedLidChange {
                Text("Waiting for administrator authorization...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Toggle(
                "Start automatically at login",
                isOn: Binding(
                    get: { controller.launchAtLoginEnabled },
                    set: { controller.setLaunchAtLoginEnabled($0) }
                )
            )
            .help("Launch AwakeBar automatically after you sign in.")

            Button("Turn Everything Off") {
                Task {
                    await controller.turnEverythingOff()
                }
            }
            .disabled(!controller.isOpenLidEnabled && !controller.isClosedLidToggleOn)
            .help("Turns off Full Caffeine and Closed-Lid Mode.")

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .help("Closes AwakeBar.")

            Text("Tip: hover any control to see a quick explanation.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(minWidth: 320)
    }
}
