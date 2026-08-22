import Foundation

enum AppConfiguration {
    static let baseURL: URL = {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "JEFFOPOLYDEAL_BASE_URL") as? String,
            let url = URL(string: value),
            ["http", "https"].contains(url.scheme?.lowercased())
        else {
            preconditionFailure("JEFFOPOLYDEAL_BASE_URL must be a valid HTTP or HTTPS URL")
        }
        return url
    }()

    static let hubURL = baseURL.appending(path: "hub/game")
}

