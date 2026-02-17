import Foundation
import IOKit
import IOKit.pwr_mgt

enum OpenLidAssertionError: Error {
    case createAssertionFailed(IOReturn)
    case releaseAssertionFailed(IOReturn)
}

@MainActor
final class OpenLidAssertionController: OpenLidSleepControlling {
    private var idleAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0

    private(set) var isEnabled: Bool = false

    func setEnabled(_ enabled: Bool) throws {
        guard enabled != isEnabled else {
            return
        }

        if enabled {
            do {
                try createAssertions()
                isEnabled = true
            } catch {
                try? releaseAssertions()
                throw error
            }
        } else {
            try releaseAssertions()
            isEnabled = false
        }
    }

    private func createAssertions() throws {
        let reason = "AwakeBar Full Caffeine" as CFString

        var idleID: IOPMAssertionID = 0
        let idleResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &idleID
        )
        guard idleResult == kIOReturnSuccess else {
            throw OpenLidAssertionError.createAssertionFailed(idleResult)
        }

        var displayID: IOPMAssertionID = 0
        let displayResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &displayID
        )

        guard displayResult == kIOReturnSuccess else {
            _ = IOPMAssertionRelease(idleID)
            throw OpenLidAssertionError.createAssertionFailed(displayResult)
        }

        idleAssertionID = idleID
        displayAssertionID = displayID
    }

    private func releaseAssertions() throws {
        var releaseError: IOReturn?

        if idleAssertionID != 0 {
            let result = IOPMAssertionRelease(idleAssertionID)
            if result != kIOReturnSuccess {
                releaseError = result
            }
            idleAssertionID = 0
        }

        if displayAssertionID != 0 {
            let result = IOPMAssertionRelease(displayAssertionID)
            if result != kIOReturnSuccess {
                releaseError = result
            }
            displayAssertionID = 0
        }

        if let releaseError {
            throw OpenLidAssertionError.releaseAssertionFailed(releaseError)
        }
    }
}
