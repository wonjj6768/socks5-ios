import ActivityKit
import Foundation

@MainActor
final class ServerLiveActivityManager {
    static let shared = ServerLiveActivityManager()

    private var lastState: Socks5ActivityAttributes.ContentState?

    private init() {}

    /// `Activity` is not Sendable, so it is looked up per call instead of being
    /// stored across suspension points.
    private var current: Activity<Socks5ActivityAttributes>? {
        Activity<Socks5ActivityAttributes>.activities.first
    }

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

        Task {
            if isRunning {
                await startOrUpdate(with: state)
            } else {
                await end(with: state)
            }
        }
    }

    private func startOrUpdate(with state: Socks5ActivityAttributes.ContentState) async {
        let content = ActivityContent(state: state, staleDate: nil)

        if let current {
            await current.update(content)
            lastState = state
            return
        }

        do {
            _ = try Activity.request(
                attributes: Socks5ActivityAttributes(title: "SOCKS5 Server"),
                content: content,
                pushType: nil
            )
            lastState = state
        } catch {
            print("[LiveActivity] Failed to start activity: \(error)")
        }
    }

    private func end(with state: Socks5ActivityAttributes.ContentState) async {
        guard let current else { return }

        let content = ActivityContent(state: state, staleDate: Date())
        await current.end(content, dismissalPolicy: .immediate)
        lastState = nil
    }
}
