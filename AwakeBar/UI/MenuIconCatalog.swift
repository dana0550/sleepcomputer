import Foundation

enum MenuIconCatalog {
    private static let offAssetName = "AwakeBarStatusOff"
    private static let fullAwakeAssetName = "AwakeBarStatusClosed"

    static func statusBarAssetName(for mode: KeepAwakeMode) -> String {
        switch mode {
        case .off:
            return offAssetName
        case .fullAwake:
            return fullAwakeAssetName
        }
    }
}
