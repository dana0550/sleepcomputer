import Foundation

let listener = NSXPCListener(machServiceName: PrivilegedServiceConstants.machServiceName)
let delegate = PrivilegedServiceListenerDelegate()

listener.delegate = delegate

let requirement = CodeSigningRequirementBuilder.requirement(
    for: PrivilegedServiceConstants.appBundleIdentifier,
    teamID: CodeSigningRequirementBuilder.configuredTeamID()
)
listener.setConnectionCodeSigningRequirement(requirement)

listener.activate()
RunLoop.main.run()
