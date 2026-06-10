import Foundation

struct CloudSyncConfiguration {
    let isEnabled: Bool
    let containerIdentifier: String?

    static let disabled = CloudSyncConfiguration(
        isEnabled: false,
        containerIdentifier: nil
    )

    static func enabled(containerIdentifier: String) -> CloudSyncConfiguration {
        CloudSyncConfiguration(
            isEnabled: true,
            containerIdentifier: containerIdentifier
        )
    }
}
