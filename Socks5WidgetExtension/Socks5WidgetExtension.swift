import ActivityKit
import SwiftUI
import WidgetKit

struct Socks5LiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Socks5ActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: context.state.isRunning ? "dot.radiowaves.left.and.right" : "pause.circle")
                        .foregroundStyle(context.state.isRunning ? .green : .gray)
                    Text(context.state.statusText)
                        .font(.headline)
                    Spacer()
                }

                Text(context.state.proxyAddress)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)

                HStack {
                    Text("SOCKS5 proxy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if context.state.isRunning {
                        Link(destination: URL(string: "socks5://stop")!) {
                            Label("Stop", systemImage: "stop.fill")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.14))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .activityBackgroundTint(Color(.systemBackground))
            .activitySystemActionForegroundColor(.accentColor)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("SOCKS5", systemImage: "network")
                        .font(.headline)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.statusText)
                        .font(.subheadline)
                        .foregroundStyle(context.state.isRunning ? .green : .secondary)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Proxy Address")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(context.state.proxyAddress)
                                .font(.system(.footnote, design: .monospaced))
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        if context.state.isRunning {
                            Link(destination: URL(string: "socks5://stop")!) {
                                Label("Stop", systemImage: "stop.fill")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color.red.opacity(0.16))
                                    .foregroundStyle(.red)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                Image(systemName: "network")
            } compactTrailing: {
                Image(systemName: context.state.isRunning ? "play.fill" : "pause.fill")
                    .foregroundStyle(context.state.isRunning ? .green : .gray)
            } minimal: {
                Image(systemName: context.state.isRunning ? "network" : "pause")
            }
            .widgetURL(URL(string: "socks5://status"))
            .keylineTint(context.state.isRunning ? .green : .gray)
        }
    }
}

@main
struct Socks5WidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        Socks5LiveActivityWidget()
    }
}
