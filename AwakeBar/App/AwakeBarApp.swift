import AppKit
import SwiftUI

@MainActor
final class AwakeBarAppDelegate: NSObject, NSApplicationDelegate {
    weak var controller: MenuBarController?
    private var terminationTask: Task<Void, Never>?

    func attach(controller: MenuBarController) {
        self.controller = controller
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard terminationTask == nil else {
            return .terminateLater
        }
        guard let controller else {
            return .terminateNow
        }

        terminationTask = Task { @MainActor [weak self] in
            await controller.prepareForTermination()
            sender.reply(toApplicationShouldTerminate: true)
            self?.terminationTask = nil
        }
        return .terminateLater
    }
}

@main
struct AwakeBarApp: App {
    @NSApplicationDelegateAdaptor(AwakeBarAppDelegate.self) private var appDelegate
    @StateObject private var controller: MenuBarController

    init() {
        _controller = StateObject(wrappedValue: MenuBarController())
    }

    var body: some Scene {
        let _ = appDelegate.attach(controller: controller)

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
    }
}
