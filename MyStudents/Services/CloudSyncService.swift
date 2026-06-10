import Foundation

protocol CloudSyncServiceProtocol {
    var configuration: CloudSyncConfiguration { get }

    func prepare()
}

final class CloudKitSyncService: CloudSyncServiceProtocol {
    let configuration: CloudSyncConfiguration

    init(configuration: CloudSyncConfiguration) {
        self.configuration = configuration
    }

    func prepare() {
    }
}
