import Foundation

@objc protocol AwakeBarPrivilegedServiceXPC {
    func ping(_ reply: @escaping (Bool, String?) -> Void)
    func setSleepDisabled(_ disabled: Bool, reply: @escaping (NSError?) -> Void)
    func readSleepDisabled(_ reply: @escaping (NSNumber?, NSError?) -> Void)
    func cleanupLegacyArtifacts(_ reply: @escaping (NSDictionary, NSError?) -> Void)
}
