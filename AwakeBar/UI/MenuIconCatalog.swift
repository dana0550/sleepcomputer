import Foundation

enum MenuIconCatalog {
    enum ModeRow: String, CaseIterable {
        case openLid
        case closedLid
    }

    struct DropdownIconPair: Equatable {
        let offAssetName: String
        let onAssetName: String

        func assetName(for isOn: Bool) -> String {
            isOn ? onAssetName : offAssetName
        }
    }

    static func statusBarAssetName(for mode: KeepAwakeMode) -> String {
        switch mode {
        case .off:
            return "AwakeBarStatusOff"
        case .openLid:
            return "AwakeBarStatusOpen"
        case .closedLid, .externalClosedLid:
            return "AwakeBarStatusClosed"
        }
    }

    static func dropdownPair(for row: ModeRow) -> DropdownIconPair {
        switch row {
        case .openLid:
            return DropdownIconPair(
                offAssetName: "AwakeBarStatusOff",
                onAssetName: "AwakeBarStatusOpen"
            )
        case .closedLid:
            return DropdownIconPair(
                offAssetName: "AwakeBarStatusOff",
                onAssetName: "AwakeBarStatusClosed"
            )
        }
    }
}
