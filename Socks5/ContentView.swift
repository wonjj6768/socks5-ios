//
//  ContentView.swift
//  Socks5
//

import SwiftUI
import HevSocks5Server
import Network

// MARK: - Network Utility

func getLocalIPAddress() -> String {
    var address = "N/A"
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return address }
    defer { freeifaddrs(ifaddr) }

    for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
        let sa = ptr.pointee.ifa_addr.pointee
        guard sa.sa_family == UInt8(AF_INET) else { continue }
        let name = String(cString: ptr.pointee.ifa_name)
        guard name == "en0" else { continue }
        var addr = ptr.pointee.ifa_addr.pointee
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                getnameinfo(sa, socklen_t(sa.pointee.sa_len),
                            &hostname, socklen_t(hostname.count),
                            nil, 0, NI_NUMERICHOST)
            }
        }
        address = String(cString: hostname)
        break
    }
    return address
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
    @State private var localIP: String = "N/A"
    @State private var showCopied: Bool = false
    @State private var startupVerificationTask: Task<Void, Never>?

    enum ServerStatus {
        case stopped, starting, running, failed
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
            localIP = getLocalIPAddress()
            syncBackgroundAudio(for: serverStatus)
            if autoStart && !isRunning {
                startServer()
            }
        }
        .onChange(of: serverStatus) { newStatus in
            syncBackgroundAudio(for: newStatus)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active && serverStatus == .running {
                BackgroundAudioManager.shared.resume()
            }
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    var addressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Proxy Address")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(proxyAddress)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.semibold)
                .textSelection(.enabled)

            Button(action: copyProxyAddress) {
                Text(showCopied ? "Copied Address" : "Copy Address")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(showCopied ? Color.green : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
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
            .cornerRadius(16)
        }
        .disabled(serverStatus == .starting)
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
        UIPasteboard.general.string = proxyAddress
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }

    func toggleServer() {
        if isRunning {
            stopServer()
        } else {
            startServer()
        }
    }

    // MARK: - Server Control

    func startServer() {
        guard !isRunning else { return }
        isRunning = true
        serverStatus = .starting
        localIP = getLocalIPAddress()
        startupVerificationTask?.cancel()

        DispatchQueue.global().async {
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

            DispatchQueue.main.async {
                beginStartupVerification()
            }

            let result = hev_socks5_server_main_from_str(conf, UInt32(strlen(conf)))

            DispatchQueue.main.async {
                startupVerificationTask?.cancel()
                startupVerificationTask = nil
                isRunning = false
                serverStatus = result == 0 ? .stopped : .failed
            }
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
            var resolved = false

            func finish(_ value: Bool) {
                guard !resolved else { return }
                resolved = true
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

    func syncBackgroundAudio(for status: ServerStatus) {
        switch status {
        case .running:
            BackgroundAudioManager.shared.start()
        case .stopped, .failed:
            BackgroundAudioManager.shared.stop()
        case .starting:
            break
        }

        ServerLiveActivityManager.shared.sync(
            isRunning: status == .running,
            statusText: statusText,
            proxyAddress: proxyAddress
        )
    }
}

#Preview {
    ContentView()
}
