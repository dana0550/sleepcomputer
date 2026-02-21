import Foundation
import IOKit
import IOKit.pwr_mgt

enum LidStateMonitorError: LocalizedError {
    case rootDomainUnavailable
    case notificationPortUnavailable
    case interestRegistrationFailed(kern_return_t)
    case unsupportedHardware

    var errorDescription: String? {
        switch self {
        case .rootDomainUnavailable:
            return "Could not access power management root domain."
        case .notificationPortUnavailable:
            return "Could not create lid state notification channel."
        case .interestRegistrationFailed(let status):
            return "Could not subscribe to lid state changes (\(status))."
        case .unsupportedHardware:
            return "Lid state monitoring is not supported on this Mac."
        }
    }
}

@MainActor
final class IOKitLidStateMonitor: LidStateMonitoring {
    private final class CallbackContext: @unchecked Sendable {
        private let lock = NSLock()
        private weak var monitor: IOKitLidStateMonitor?

        init(monitor: IOKitLidStateMonitor?) {
            self.monitor = monitor
        }

        func updateMonitor(_ monitor: IOKitLidStateMonitor?) {
            lock.lock()
            self.monitor = monitor
            lock.unlock()
        }

        func dispatch(messageType: natural_t, messageArgument: UnsafeMutableRawPointer?) {
            let bitmask = messageArgument.map { UInt(bitPattern: $0) }
            lock.lock()
            let monitor = self.monitor
            lock.unlock()
            guard let monitor else {
                return
            }

            Task { @MainActor [weak monitor] in
                monitor?.handleNotification(messageType: messageType, bitmask: bitmask)
            }
        }
    }

    private enum LidSupportCapability {
        case unknown
        case supported
        case unsupported
    }

    // Matches iokit_family_msg(sub_iokit_powermanagement, 0x100) from IOPM.h.
    nonisolated static let clamshellStateChangeMessage: natural_t = 0xE0034100

    private nonisolated(unsafe) var notificationPort: IONotificationPortRef?
    private nonisolated(unsafe) var runLoopSource: CFRunLoopSource?
    private nonisolated(unsafe) var notifier: io_object_t = IO_OBJECT_NULL
    private nonisolated(unsafe) var rootDomain: io_registry_entry_t = IO_OBJECT_NULL
    private var onLidStateChange: ((Bool) -> Void)?
    private var lastKnownState: Bool?
    private var lidSupportCapability: LidSupportCapability = .unknown
    private nonisolated(unsafe) var callbackRefcon: UnsafeMutableRawPointer?

    var isSupported: Bool {
        switch lidSupportCapability {
        case .supported:
            return true
        case .unsupported:
            return false
        case .unknown:
            guard let resolved = resolveLidSupportCapability() else {
                return false
            }
            lidSupportCapability = resolved
            return resolved == .supported
        }
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

        if let callbackRefcon {
            let context = Unmanaged<CallbackContext>.fromOpaque(callbackRefcon).takeRetainedValue()
            context.updateMonitor(nil)
            self.callbackRefcon = nil
        }
    }

    func startMonitoring(onLidStateChange: @escaping (Bool) -> Void) throws {
        stopMonitoring()
        guard isSupported else {
            throw LidStateMonitorError.unsupportedHardware
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
        let callbackRefcon: UnsafeMutableRawPointer
        if let existingRefcon = self.callbackRefcon {
            let context = Unmanaged<CallbackContext>.fromOpaque(existingRefcon).takeUnretainedValue()
            context.updateMonitor(self)
            callbackRefcon = existingRefcon
        } else {
            let context = CallbackContext(monitor: self)
            let retainedContext = Unmanaged.passRetained(context)
            callbackRefcon = retainedContext.toOpaque()
            self.callbackRefcon = callbackRefcon
        }

        let result = IOServiceAddInterestNotification(
            notificationPort,
            service,
            kIOGeneralInterest,
            Self.notificationCallback,
            callbackRefcon,
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

        if let callbackRefcon {
            let context = Unmanaged<CallbackContext>.fromOpaque(callbackRefcon).takeUnretainedValue()
            context.updateMonitor(nil)
        }

        onLidStateChange = nil
        lastKnownState = nil
    }

    nonisolated static func decodeLidClosedState(messageType: natural_t, bitmask: UInt?, fallbackState: Bool?) -> Bool? {
        guard messageType == clamshellStateChangeMessage else {
            return nil
        }
        if let bitmask {
            return (bitmask & UInt(kClamshellStateBit)) != 0
        }
        return fallbackState
    }

    private func handleNotification(messageType: natural_t, bitmask: UInt?) {
        guard let isClosed = Self.decodeLidClosedState(
            messageType: messageType,
            bitmask: bitmask,
            fallbackState: currentLidClosedState()
        ) else {
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
            lidSupportCapability = .unsupported
            return nil
        }

        let value = valueRef.takeRetainedValue()
        guard let isClosed = (value as? NSNumber)?.boolValue else {
            lidSupportCapability = .unsupported
            return nil
        }
        lidSupportCapability = .supported
        return isClosed
    }

    private func resolveLidSupportCapability() -> LidSupportCapability? {
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
            return .unsupported
        }

        let value = valueRef.takeRetainedValue()
        return value is NSNumber ? .supported : .unsupported
    }

    private nonisolated static let notificationCallback: IOServiceInterestCallback = {
        refcon,
        _,
        messageType,
        messageArgument
        in
        guard let refcon else {
            return
        }

        let context = Unmanaged<CallbackContext>.fromOpaque(refcon).takeUnretainedValue()
        context.dispatch(messageType: messageType, messageArgument: messageArgument)
    }
}
