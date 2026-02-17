import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status: \(controller.statusText)")
                .font(.headline)

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

            Toggle(
                "Closed-Lid Mode (Admin)",
                isOn: Binding(
                    get: { controller.isClosedLidToggleOn },
                    set: { controller.requestClosedLidChange($0) }
                )
            )
            .disabled(controller.isApplyingClosedLidChange)

            Toggle(
                "Start automatically at login",
                isOn: Binding(
                    get: { controller.launchAtLoginEnabled },
                    set: { controller.setLaunchAtLoginEnabled($0) }
                )
            )

            Button("Turn Everything Off") {
                Task {
                    await controller.turnEverythingOff()
                }
            }
            .disabled(!controller.isOpenLidEnabled && !controller.isClosedLidToggleOn)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(10)
        .frame(minWidth: 290)
    }
}
