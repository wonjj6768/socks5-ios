//
//  ContentView.swift
//  Socks5
//

import SwiftUI
import HevSocks5Server

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
    @State private var isRunning: Bool = false

    var body: some View {
        VStack {
            Text("Workers:")
                .font(.headline)
                .padding(.bottom, 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("", text: $workersText)
                .padding(.top, 0)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .keyboardType(.numberPad)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(isRunning)

            Text("Listen Address:")
                .font(.headline)
                .padding(.bottom, 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("", text: $listenAddrText)
                .padding(.top, 0)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .frame(maxWidth: .infinity)
                .disabled(isRunning)

            Text("Listen Port:")
                .font(.headline)
                .padding(.bottom, 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("", text: $listenPortText)
                .padding(.top, 0)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .keyboardType(.numberPad)
                .frame(maxWidth: .infinity)
                .disabled(isRunning)

            Text("UDP Listen Address:")
                .font(.headline)
                .padding(.bottom, 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("Optional", text: $udpListenAddrText)
                .padding(.top, 0)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .frame(maxWidth: .infinity)
                .disabled(isRunning)

            Text("UDP Listen Port:")
                .font(.headline)
                .padding(.bottom, 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("", text: $udpListenPortText)
                .padding(.top, 0)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .keyboardType(.numberPad)
                .frame(maxWidth: .infinity)
                .disabled(isRunning)

            Text("Bind IPv4 Address:")
                .font(.headline)
                .padding(.bottom, 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("", text: $bindIpv4AddrText)
                .padding(.top, 0)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .frame(maxWidth: .infinity)
                .disabled(isRunning)

            Text("Bind IPv6 Address:")
                .font(.headline)
                .padding(.bottom, 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("", text: $bindIpv6AddrText)
                .padding(.top, 0)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .frame(maxWidth: .infinity)
                .disabled(isRunning)

            Text("Bind Interface:")
                .font(.headline)
                .padding(.bottom, 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("Optional", text: $bindIfaceText)
                .padding(.top, 0)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .frame(maxWidth: .infinity)
                .disabled(isRunning)

            Text("Auth Username:")
                .font(.headline)
                .padding(.bottom, 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("Optional", text: $authUserText)
                .padding(.top, 0)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .frame(maxWidth: .infinity)
                .disabled(isRunning)

            Text("Auth Password:")
                .font(.headline)
                .padding(.bottom, 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            SecureField("Optional", text: $authPassText)
                .padding(.top, 0)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .frame(maxWidth: .infinity)
                .disabled(isRunning)

            Toggle(isOn: $listenIpv6OnlyToggle) {
                Text("Listen IPv6 only")
                    .font(.headline)
            }
            .toggleStyle(SwitchToggleStyle())
            .frame(maxWidth: .infinity)
            .disabled(isRunning)

            HStack {
                Button(action: {
                    isRunning = true
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
                        let _ = hev_socks5_server_main_from_str(conf, UInt32(strlen(conf)))
                        isRunning = false
                    }
                }) {
                    Text("Start")
                    .font(.headline)
                    .padding()
                    .cornerRadius(10)
                }
                .disabled(isRunning)
                Button(action: {
                    hev_socks5_server_quit ()
                }) {
                    Text("Stop")
                    .font(.headline)
                    .padding()
                    .cornerRadius(10)
                }
                .disabled(!isRunning)
            }

            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
