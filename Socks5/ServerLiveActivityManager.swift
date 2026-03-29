import ActivityKit
import Foundation

@MainActor
final class ServerLiveActivityManager {
    static let shared = ServerLiveActivityManager()

    private var activity: Activity<Socks5ActivityAttributes>?

    private init() {}

    func sync(isRunning: Bool, statusText: String, proxyAddress: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = Socks5ActivityAttributes.ContentState(
            statusText: statusText,
            proxyAddress: proxyAddress,
            isRunning: isRunning
        )

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

        if let activity {
            await activity.update(content)
            return
        }

        do {
            activity = try Activity.request(
                attributes: Socks5ActivityAttributes(title: "SOCKS5 Server"),
                content: content,
                pushType: nil
            )
        } catch {
            print("[LiveActivity] Failed to start activity: \(error)")
        }
    }

    private func end(with state: Socks5ActivityAttributes.ContentState) async {
        guard let activity else { return }

        let content = ActivityContent(state: state, staleDate: Date())
        await activity.end(content, dismissalPolicy: .immediate)
        self.activity = nil
    }
}
