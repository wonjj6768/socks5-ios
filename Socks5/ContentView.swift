//
//  ContentView.swift
//  Socks5
//

import SwiftUI
import HevSocks5Server

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
    @AppStorage("socks5_workers") private var workersText: String = "4"
    @AppStorage("socks5_listenAddr") private var listenAddrText: String = "::"
    @AppStorage("socks5_listenPort") private var listenPortText: String = "1080"
    @AppStorage("socks5_udpListenAddr") private var udpListenAddrText: String = ""
    @AppStorage("socks5_udpListenPort") private var udpListenPortText: String = "1080"
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

    enum ServerStatus {
        case stopped, starting, running, failed
    }

    var proxyAddress: String {
        "\(localIP):\(listenPortText)"
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
            VStack(spacing: 12) {

                // MARK: - Status & IP Section
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 12, height: 12)
                        Text(statusText)
                            .font(.headline)
                            .foregroundColor(statusColor)
                        Spacer()
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Proxy Address")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(proxyAddress)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                        }
                        Spacer()
                        Button(action: {
                            UIPasteboard.general.string = proxyAddress
                            showCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showCopied = false
                            }
                        }) {
                            Text(showCopied ? "Copied!" : "Copy")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(showCopied ? Color.green : Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // MARK: - Controls
                HStack(spacing: 16) {
                    Button(action: { startServer() }) {
                        Text("Start")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isRunning ? Color.gray : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(isRunning)

                    Button(action: {
                        hev_socks5_server_quit()
                    }) {
                        Text("Stop")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(!isRunning ? Color.gray : Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!isRunning)
                }

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
            if autoStart && !isRunning {
                startServer()
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    // MARK: - Helper Views

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

    // MARK: - Server Control

    func startServer() {
        isRunning = true
        serverStatus = .starting
        localIP = getLocalIPAddress()

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

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if isRunning {
                    serverStatus = .running
                }
            }

            let result = hev_socks5_server_main_from_str(conf, UInt32(strlen(conf)))

            DispatchQueue.main.async {
                isRunning = false
                serverStatus = result == 0 ? .stopped : .failed
            }
        }
    }
}

#Preview {
    ContentView()
}
