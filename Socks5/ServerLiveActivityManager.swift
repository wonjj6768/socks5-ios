import ActivityKit
import Foundation

/// ActivityKit's `Activity` is not Sendable, so every use of it stays inside a
/// single nonisolated function and never crosses an isolation boundary.
private nonisolated func pushActivityUpdate(
    _ state: Socks5ActivityAttributes.ContentState
) async {
    let content = ActivityContent(state: state, staleDate: nil)

    if let activity = Activity<Socks5ActivityAttributes>.activities.first {
        await activity.update(content)
        return
    }

    do {
        _ = try Activity.request(
            attributes: Socks5ActivityAttributes(title: "SOCKS5 Server"),
            content: content,
            pushType: nil
        )
    } catch {
        print("[LiveActivity] Failed to start activity: \(error)")
    }
}

private nonisolated func endActivity(
    _ state: Socks5ActivityAttributes.ContentState
) async {
    guard let activity = Activity<Socks5ActivityAttributes>.activities.first else {
        return
    }

    let content = ActivityContent(state: state, staleDate: Date())
    await activity.end(content, dismissalPolicy: .immediate)
}

@MainActor
final class ServerLiveActivityManager {
    static let shared = ServerLiveActivityManager()

    private var lastState: Socks5ActivityAttributes.ContentState?

    private init() {}

    func sync(isRunning: Bool, statusText: String, proxyAddress: String,
              uploadRateText: String, downloadRateText: String,
              totalText: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = Socks5ActivityAttributes.ContentState(
            statusText: statusText,
            proxyAddress: proxyAddress,
            isRunning: isRunning,
            uploadRateText: uploadRateText,
            downloadRateText: downloadRateText,
            totalText: totalText
        )
        guard state != lastState else { return }
        lastState = isRunning ? state : nil

        Task {
            if isRunning {
                await pushActivityUpdate(state)
            } else {
                await endActivity(state)
            }
        }
    }
}
