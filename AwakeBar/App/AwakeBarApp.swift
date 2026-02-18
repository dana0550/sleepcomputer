import SwiftUI

@main
struct AwakeBarApp: App {
    @StateObject private var controller = MenuBarController()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(controller: controller)
        } label: {
            ZStack {
                Circle()
                    .stroke(controller.fullAwakeSwitchIsOn ? Color.blue : Color.primary.opacity(0.45), lineWidth: 1.8)
                    .frame(width: 14, height: 14)

                if controller.fullAwakeSwitchIsOn {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 16, height: 16)
            .accessibilityLabel(controller.fullAwakeSwitchIsOn ? "Awake On" : "Awake Off")
        }
        .menuBarExtraStyle(.window)

        Settings {
            EmptyView()
        }
    }
}
