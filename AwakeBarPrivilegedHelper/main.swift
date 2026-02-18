import Foundation

let listener = NSXPCListener(machServiceName: PrivilegedServiceConstants.machServiceName)
let delegate = PrivilegedServiceListenerDelegate()

listener.delegate = delegate

if let teamID = CodeSigningRequirementBuilder.configuredTeamID() {
    let requirement = CodeSigningRequirementBuilder.requirement(
        for: PrivilegedServiceConstants.appBundleIdentifier,
        teamID: teamID
    )
    listener.setConnectionCodeSigningRequirement(requirement)
}

listener.activate()
RunLoop.main.run()
