import Foundation
import IOKit
import IOKit.pwr_mgt

enum LidStateMonitorError: LocalizedError {
    case rootDomainUnavailable
    case notificationPortUnavailable
    case interestRegistrationFailed(kern_return_t)

    var errorDescription: String? {
        switch self {
        case .rootDomainUnavailable:
            return "Could not access power management root domain."
        case .notificationPortUnavailable:
            return "Could not create lid state notification channel."
        case .interestRegistrationFailed(let status):
            return "Could not subscribe to lid state changes (\(status))."
        }
    }
}

@MainActor
final class IOKitLidStateMonitor: LidStateMonitoring {
    private nonisolated(unsafe) var notificationPort: IONotificationPortRef?
    private nonisolated(unsafe) var runLoopSource: CFRunLoopSource?
    private nonisolated(unsafe) var notifier: io_object_t = IO_OBJECT_NULL
    private nonisolated(unsafe) var rootDomain: io_registry_entry_t = IO_OBJECT_NULL
    private var onLidStateChange: ((Bool) -> Void)?
    private var lastKnownState: Bool?

    var isSupported: Bool {
        currentLidClosedState() != nil
    }

    deinit {
        if notifier != IO_OBJECT_NULL {
            IOObjectRelease(notifier)
            notifier = IO_OBJECT_NULL
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
            self.runLoopSource = nil
        }

        if let notificationPort {
            IONotificationPortDestroy(notificationPort)
            self.notificationPort = nil
        }

        if rootDomain != IO_OBJECT_NULL {
            IOObjectRelease(rootDomain)
            rootDomain = IO_OBJECT_NULL
        }
    }

    func startMonitoring(onLidStateChange: @escaping (Bool) -> Void) throws {
        stopMonitoring()
        guard isSupported else {
            return
        }

        self.onLidStateChange = onLidStateChange
        lastKnownState = currentLidClosedState()

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != IO_OBJECT_NULL else {
            throw LidStateMonitorError.rootDomainUnavailable
        }
        rootDomain = service

        guard let notificationPort = IONotificationPortCreate(kIOMainPortDefault) else {
            stopMonitoring()
            throw LidStateMonitorError.notificationPortUnavailable
        }
        self.notificationPort = notificationPort

        let source = IONotificationPortGetRunLoopSource(notificationPort).takeUnretainedValue()
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)

        var notifier: io_object_t = IO_OBJECT_NULL
        let result = IOServiceAddInterestNotification(
            notificationPort,
            service,
            kIOGeneralInterest,
            Self.notificationCallback,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &notifier
        )
        guard result == KERN_SUCCESS else {
            stopMonitoring()
            throw LidStateMonitorError.interestRegistrationFailed(result)
        }
        self.notifier = notifier
    }

    func stopMonitoring() {
        if notifier != IO_OBJECT_NULL {
            IOObjectRelease(notifier)
            notifier = IO_OBJECT_NULL
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
            self.runLoopSource = nil
        }

        if let notificationPort {
            IONotificationPortDestroy(notificationPort)
            self.notificationPort = nil
        }

        if rootDomain != IO_OBJECT_NULL {
            IOObjectRelease(rootDomain)
            rootDomain = IO_OBJECT_NULL
        }

        onLidStateChange = nil
        lastKnownState = nil
    }

    private func handleNotification(bitmask: UInt?) {
        let isClosed: Bool
        if let bitmask {
            let decodedState = (bitmask & UInt(kClamshellStateBit)) != 0
            if let currentState = currentLidClosedState(), currentState != decodedState {
                // Ignore unrelated root-domain notifications that share this callback.
                return
            }
            isClosed = decodedState
        } else if let currentState = currentLidClosedState() {
            isClosed = currentState
        } else {
            return
        }

        guard lastKnownState != isClosed else {
            return
        }
        lastKnownState = isClosed
        onLidStateChange?(isClosed)
    }

    private func currentLidClosedState() -> Bool? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != IO_OBJECT_NULL else {
            return nil
        }
        defer {
            IOObjectRelease(service)
        }

        guard let valueRef = IORegistryEntryCreateCFProperty(
            service,
            kAppleClamshellStateKey as CFString,
            kCFAllocatorDefault,
            0
        ) else {
            return nil
        }

        let value = valueRef.takeRetainedValue()
        return (value as? NSNumber)?.boolValue
    }

    private nonisolated static let notificationCallback: IOServiceInterestCallback = {
        refcon,
        _,
        _,
        messageArgument
        in
        guard let refcon else {
            return
        }

        let monitor = Unmanaged<IOKitLidStateMonitor>.fromOpaque(refcon).takeUnretainedValue()
        let bitmask = messageArgument.map { UInt(bitPattern: $0) }

        Task { @MainActor in
            monitor.handleNotification(bitmask: bitmask)
        }
    }
}
