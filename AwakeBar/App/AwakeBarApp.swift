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
        }
        .menuBarExtraStyle(.menu)

        Settings {
            EmptyView()
        }
    }
}
