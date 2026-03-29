import ActivityKit

struct Socks5ActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var statusText: String
        var proxyAddress: String
        var isRunning: Bool
    }

    var title: String
}
