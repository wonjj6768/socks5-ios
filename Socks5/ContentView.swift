//
//  ContentView.swift
//  Socks5
//

import SwiftUI
import HevSocks5Server
import Network
import Combine

// MARK: - Network Utility

struct NetworkAddress: Identifiable, Equatable {
    let interface: String
    let address: String

    var id: String { interface }
}

/// Single-resume guard for the startup probe continuation.
final class ProbeResult: @unchecked Sendable {
    var resolved = false
}

/// Reachable IPv4 addresses, personal hotspot first.
///
/// `bridge100` is the interface iOS creates while Personal Hotspot is on, and
/// it carries the address that tethered clients actually connect to.
func localIPAddresses() -> [NetworkAddress] {
    var found: [NetworkAddress] = []
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return found }
    defer { freeifaddrs(ifaddr) }

    for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
        guard let ifaAddr = ptr.pointee.ifa_addr else { continue }
        guard ifaAddr.pointee.sa_family == UInt8(AF_INET) else { continue }
        guard ptr.pointee.ifa_flags & UInt32(IFF_UP) != 0,
              ptr.pointee.ifa_flags & UInt32(IFF_LOOPBACK) == 0 else { continue }

        let name = String(cString: ptr.pointee.ifa_name)
        guard name.hasPrefix("en") || name.hasPrefix("bridge")
                || name.hasPrefix("pdp_ip") else { continue }

        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let res = getnameinfo(ifaAddr, socklen_t(ifaAddr.pointee.sa_len),
                              &hostname, socklen_t(hostname.count),
                              nil, 0, NI_NUMERICHOST)
        guard res == 0 else { continue }

        let bytes = hostname.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        let text = String(decoding: bytes, as: UTF8.self)
        found.append(NetworkAddress(interface: name, address: text))
    }

    func rank(_ name: String) -> Int {
        if name.hasPrefix("bridge") { return 0 }
        if name == "en0" { return 1 }
        if name.hasPrefix("en") { return 2 }
        return 3
    }

    return found.sorted { rank($0.interface) < rank($1.interface) }
}

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("socks5_workers") private var workersText: String = "4"
    @AppStorage("socks5_listenAddr") private var listenAddrText: String = "::"
    @AppStorage("socks5_listenPort") private var listenPortText: String = "8888"
    @AppStorage("socks5_udpListenAddr") private var udpListenAddrText: String = ""
    @AppStorage("socks5_udpListenPort") private var udpListenPortText: String = "8888"
    @AppStorage("socks5_bindIpv4Addr") private var bindIpv4AddrText: String = "0.0.0.0"
    @AppStorage("socks5_bindIpv6Addr") private var bindIpv6AddrText: String = "::"
    @AppStorage("socks5_bindIface") private var bindIfaceText: String = ""
    @AppStorage("socks5_authUser") private var authUserText: String = ""
    @AppStorage("socks5_authPass") private var authPassText: String = ""
    @AppStorage("socks5_listenIpv6Only") private var listenIpv6OnlyToggle: Bool = false
    @AppStorage("socks5_autoStart") private var autoStart: Bool = false

    @State private var isRunning: Bool = false
    @State private var serverStatus: ServerStatus = .stopped
    @State private var addresses: [NetworkAddress] = []
    @State private var selectedInterface: String = ""
    @State private var copiedAddress: String?
    @State private var startupVerificationTask: Task<Void, Never>?
    @State private var traffic = TrafficDisplay.zero
    @State private var lastUploadBytes: UInt64 = 0
    @State private var lastDownloadBytes: UInt64 = 0
    @State private var lastTrafficDate = Date()
    @State private var lastLiveActivityDate = Date.distantPast

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum ServerStatus {
        case stopped, starting, running, failed
    }

    struct TrafficDisplay: Equatable {
        var uploadRateText: String
        var downloadRateText: String
        var totalText: String

        static let zero = TrafficDisplay(
            uploadRateText: "0 B/s",
            downloadRateText: "0 B/s",
            totalText: "0 B"
        )
    }

    var localIP: String {
        guard !addresses.isEmpty else { return "N/A" }
        if let match = addresses.first(where: { $0.interface == selectedInterface }) {
            return match.address
        }
        return addresses[0].address
    }

    var proxyAddress: String {
        "\(localIP):\(listenPortText)"
    }

    var primaryButtonTitle: String {
        switch serverStatus {
        case .running:
            return "Stop Server"
        case .starting:
            return "Starting..."
        case .stopped, .failed:
            return "Start Server"
        }
    }

    var primaryButtonColor: Color {
        switch serverStatus {
        case .running:
            return .red
        case .starting:
            return .orange
        case .stopped, .failed:
            return .green
        }
    }

    var statusDetailText: String {
        switch serverStatus {
        case .stopped:
            return "The SOCKS5 server is offline."
        case .starting:
            return "Launching the server and waiting for the listener to respond."
        case .running:
            return "Background keepalive is enabled only while the server is active."
        case .failed:
            return "The previous launch ended unexpectedly. Check the settings and try again."
        }
    }

    /// The listen port has to be a usable TCP port: the server silently fails
    /// to bind otherwise.
    var portError: String? {
        guard let port = UInt16(listenPortText), port > 0 else {
            return "Listen Port must be between 1 and 65535."
        }
        guard udpListenPortText.isEmpty
                || (UInt16(udpListenPortText) ?? 0) > 0 else {
            return "UDP Listen Port must be between 1 and 65535."
        }
        guard let workers = Int(workersText), workers > 0 else {
            return "Workers must be 1 or more."
        }
        return nil
    }

    var statusColor: Color {
        switch serverStatus {
        case .stopped: return .gray
        case .starting: return .orange
        case .running: return .green
        case .failed: return .red
        }
    }

    var statusText: String {
        switch serverStatus {
        case .stopped: return "Stopped"
        case .starting: return "Starting..."
        case .running: return "Running"
        case .failed: return "Failed"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statusCard
                addressCard
                primaryActionButton

                // MARK: - Auto Start Toggle
                Toggle(isOn: $autoStart) {
                    Text("Auto Start on Launch")
                        .font(.headline)
                }
                .toggleStyle(SwitchToggleStyle())
                .padding(.horizontal)

                Divider()

                // MARK: - Settings Fields
                Group {
                    settingsField("Workers:", text: $workersText, keyboard: .numberPad)
                    settingsField("Listen Address:", text: $listenAddrText)
                    settingsField("Listen Port:", text: $listenPortText, keyboard: .numberPad)
                    settingsField("UDP Listen Address:", text: $udpListenAddrText, placeholder: "Optional")
                    settingsField("UDP Listen Port:", text: $udpListenPortText, keyboard: .numberPad)
                    settingsField("Bind IPv4 Address:", text: $bindIpv4AddrText)
                    settingsField("Bind IPv6 Address:", text: $bindIpv6AddrText)
                    settingsField("Bind Interface:", text: $bindIfaceText, placeholder: "Optional")
                    settingsField("Auth Username:", text: $authUserText, placeholder: "Optional")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Auth Password:")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SecureField("Optional", text: $authPassText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disabled(isRunning)
                }

                Toggle(isOn: $listenIpv6OnlyToggle) {
                    Text("Listen IPv6 only")
                        .font(.headline)
                }
                .toggleStyle(SwitchToggleStyle())
                .disabled(isRunning)
            }
            .padding()
        }
        .onAppear {
            refreshAddresses()
            syncBackgroundAudio(for: serverStatus)
            if autoStart && !isRunning {
                startServer()
            }
        }
        .onChange(of: serverStatus) { _, newStatus in
            syncBackgroundAudio(for: newStatus)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            if serverStatus == .running {
                BackgroundAudioManager.shared.resume()
            }
            refreshAddresses()
        }
        .onReceive(tick) { _ in
            refreshTrafficStats()
            refreshAddresses()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .socks5StopRequested)) { _ in
            stopServer()
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    // MARK: - Helper Views

    var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                Text(statusText)
                    .font(.headline)
                    .foregroundColor(statusColor)
                Spacer()
            }

            Text(statusDetailText)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let portError, !isRunning {
                Label(portError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if serverStatus == .running || traffic != .zero {
                HStack(spacing: 12) {
                    Label(traffic.uploadRateText, systemImage: "arrow.up")
                    Label(traffic.downloadRateText, systemImage: "arrow.down")
                    Spacer()
                    Text(traffic.totalText)
                }
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    var addressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Proxy Address")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if addresses.count > 1 {
                    Picker("", selection: $selectedInterface) {
                        ForEach(addresses) { entry in
                            Text(interfaceLabel(entry.interface))
                                .tag(entry.interface)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }

            Text(proxyAddress)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.semibold)
                .textSelection(.enabled)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Button(action: copyProxyAddress) {
                Label(copiedAddress == proxyAddress ? "Copied" : "Copy",
                      systemImage: copiedAddress == proxyAddress
                        ? "checkmark" : "doc.on.doc")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(copiedAddress == proxyAddress
                                ? Color.green : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(addresses.isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    var primaryActionButton: some View {
        Button(action: toggleServer) {
            HStack {
                Image(systemName: serverStatus == .running ? "stop.fill" : "play.fill")
                Text(primaryButtonTitle)
                    .fontWeight(.bold)
            }
            .font(.title3)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(primaryButtonColor)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(serverStatus == .starting
                  || (!isRunning && portError != nil))
    }

    @ViewBuilder
    func settingsField(_ label: String, text: Binding<String>, placeholder: String = "", keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField(placeholder, text: text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .keyboardType(keyboard)
                .disabled(isRunning)
        }
    }

    func copyProxyAddress() {
        let value = proxyAddress
        UIPasteboard.general.string = value
        copiedAddress = value
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedAddress == value {
                copiedAddress = nil
            }
        }
    }

    func interfaceLabel(_ name: String) -> String {
        if name.hasPrefix("bridge") { return "Hotspot" }
        if name == "en0" { return "Wi-Fi" }
        if name.hasPrefix("pdp_ip") { return "Cellular" }
        return name
    }

    func refreshAddresses() {
        let found = localIPAddresses()
        guard found != addresses else { return }

        addresses = found
        if !found.contains(where: { $0.interface == selectedInterface }) {
            selectedInterface = found.first?.interface ?? ""
        }
    }

    func toggleServer() {
        if isRunning {
            stopServer()
        } else {
            startServer()
        }
    }

    func handleDeepLink(_ url: URL) {
        guard url.scheme == "socks5" else { return }

        switch url.host {
        case "stop":
            stopServer()
        case "start":
            startServer()
        default:
            break
        }
    }

    // MARK: - Server Control

    func startServer() {
        guard !isRunning else { return }
        hev_socks5_server_reset_traffic_stats()
        traffic = .zero
        lastUploadBytes = 0
        lastDownloadBytes = 0
        lastTrafficDate = Date()
        lastLiveActivityDate = .distantPast
        isRunning = true
        serverStatus = .starting
        refreshAddresses()
        startupVerificationTask?.cancel()
        beginStartupVerification()

        // The config is built here so the worker closure never touches
        // main-actor state.
        let conf = """
            main:
              workers: \(workersText)
              port: \(listenPortText)
              listen-address: '\(listenAddrText)'
              udp-port: \(udpListenPortText)
              udp-listen-address: '\(udpListenAddrText)'
              listen-ipv6-only: \(listenIpv6OnlyToggle)
              bind-address-v4: '\(bindIpv4AddrText)'
              bind-address-v6: '\(bindIpv6AddrText)'
              bind-interface: '\(bindIfaceText)'
            auth:
              username: '\(authUserText)'
              password: '\(authPassText)'
            """

        Task {
            // hev_socks5_server_main_from_str blocks until the server stops.
            let result = await Task.detached {
                conf.withCString { ptr in
                    hev_socks5_server_main_from_str(ptr, UInt32(strlen(ptr)))
                }
            }.value

            startupVerificationTask?.cancel()
            startupVerificationTask = nil
            isRunning = false
            serverStatus = result == 0 ? .stopped : .failed
        }
    }

    func stopServer() {
        guard isRunning else { return }
        startupVerificationTask?.cancel()
        startupVerificationTask = nil
        hev_socks5_server_quit()
    }

    func beginStartupVerification() {
        startupVerificationTask?.cancel()
        startupVerificationTask = Task {
            for _ in 0..<20 {
                if Task.isCancelled || !isRunning || serverStatus != .starting {
                    return
                }

                if await isServerReachable() {
                    guard !Task.isCancelled, isRunning, serverStatus == .starting else { return }
                    serverStatus = .running
                    return
                }

                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    func isServerReachable() async -> Bool {
        guard let portValue = UInt16(listenPortText), let port = NWEndpoint.Port(rawValue: portValue) else {
            return false
        }

        let host = probeHost()
        let connection = NWConnection(host: host, port: port, using: .tcp)

        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "Socks5.StartupProbe")
            // Both the state handler and the timeout run on `queue`, so a plain
            // reference box is enough to resume the continuation exactly once.
            let probe = ProbeResult()

            let finish: @Sendable (Bool) -> Void = { value in
                guard !probe.resolved else { return }
                probe.resolved = true
                connection.cancel()
                continuation.resume(returning: value)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(true)
                case .failed, .cancelled:
                    finish(false)
                default:
                    break
                }
            }

            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + 0.2) {
                finish(false)
            }
        }
    }

    func probeHost() -> NWEndpoint.Host {
        if listenAddrText == "::1" {
            return "::1"
        }

        if listenAddrText == "127.0.0.1" || listenAddrText == "localhost" {
            return "127.0.0.1"
        }

        if listenAddrText.contains(":") && listenIpv6OnlyToggle {
            return "::1"
        }

        return "127.0.0.1"
    }

    func refreshTrafficStats() {
        guard serverStatus == .running else {
            // Keep the session total on screen, but stop showing a live rate.
            if traffic.uploadRateText != "0 B/s"
                || traffic.downloadRateText != "0 B/s" {
                traffic.uploadRateText = "0 B/s"
                traffic.downloadRateText = "0 B/s"
            }
            return
        }

        var tcpUpload: UInt64 = 0
        var tcpDownload: UInt64 = 0
        var udpUpload: UInt64 = 0
        var udpDownload: UInt64 = 0
        hev_socks5_server_get_traffic_stats(
            &tcpUpload,
            &tcpDownload,
            &udpUpload,
            &udpDownload
        )

        let upload = tcpUpload + udpUpload
        let download = tcpDownload + udpDownload
        let now = Date()
        let seconds = max(now.timeIntervalSince(lastTrafficDate), 0.001)
        let uploadDelta = upload >= lastUploadBytes ? upload - lastUploadBytes : 0
        let downloadDelta = download >= lastDownloadBytes ? download - lastDownloadBytes : 0
        let uploadRate = UInt64(Double(uploadDelta) / seconds)
        let downloadRate = UInt64(Double(downloadDelta) / seconds)

        traffic = TrafficDisplay(
            uploadRateText: "\(formatBytes(uploadRate))/s",
            downloadRateText: "\(formatBytes(downloadRate))/s",
            totalText: formatBytes(upload + download)
        )
        lastUploadBytes = upload
        lastDownloadBytes = download
        lastTrafficDate = now
        if now.timeIntervalSince(lastLiveActivityDate) >= 3 {
            lastLiveActivityDate = now
            syncLiveActivity()
        }
    }

    func formatBytes(_ bytes: UInt64) -> String {
        let value = min(bytes, UInt64(Int64.max))
        return ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .binary)
    }

    func syncBackgroundAudio(for status: ServerStatus) {
        switch status {
        case .running:
            BackgroundAudioManager.shared.start()
        case .stopped, .failed:
            BackgroundAudioManager.shared.stop()
        case .starting:
            break
        }

        syncLiveActivity()
    }

    func syncLiveActivity() {
        ServerLiveActivityManager.shared.sync(
            isRunning: serverStatus == .running,
            statusText: statusText,
            proxyAddress: proxyAddress,
            uploadRateText: traffic.uploadRateText,
            downloadRateText: traffic.downloadRateText,
            totalText: traffic.totalText
        )
    }
}

#Preview {
    ContentView()
}
