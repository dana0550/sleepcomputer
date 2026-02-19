import SwiftUI

@main
struct AwakeBarApp: App {
    @StateObject private var controller = MenuBarController()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(controller: controller)
        } label: {
            Image(controller.menuIconName)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 19, height: 19)
                .accessibilityLabel(controller.fullAwakeSwitchIsOn ? "Awake On" : "Awake Off")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsContentView(controller: controller)
        }
    }
}
