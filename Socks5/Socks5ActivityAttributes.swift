import ActivityKit
import AppIntents
import Foundation

struct Socks5ActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        var statusText: String
        var proxyAddress: String
        var isRunning: Bool
        var uploadRateText: String
        var downloadRateText: String
        var totalText: String
    }

    var title: String
}

extension Notification.Name {
    static let socks5StopRequested = Notification.Name("Socks5.StopRequested")
}

/// Runs in the app process, so the Live Activity can stop the server without
/// bringing the app to the foreground.
struct StopServerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Server"
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .socks5StopRequested, object: nil)
        return .result()
    }
}
