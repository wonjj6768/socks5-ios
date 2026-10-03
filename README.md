# ProxiFyre iOS SOCKS5 Server

iOS 17.2+ SOCKS5 server for routing ProxiFyre traffic through an iPhone hotspot.

## Features

- TCP/UDP relay over IPv4/IPv6 (default port: `8888`).
- Hotspot-aware proxy address selection and copy.
- Live traffic stats in the app and Dynamic Island.
- Stop from Live Activity, auto-start, and username/password authentication.

## Use

1. Connect your PC to the iPhone hotspot and tap **Start Server** in the app.
2. Set ProxiFyre's SOCKS5 proxy to the app's **Proxy Address**.

## Build

Run **Build Socks5 IPA (Unsigned)** in [Actions](https://github.com/wonjj6768/socks5-ios/actions/workflows/main.yml).
Download `Socks5-IPA-Unsigned` from the completed run and sign the IPA before installing.

For Xcode, download `HevSocks5Server-xcframework-patched` from the same run,
replace the bundled `HevSocks5Server.xcframework`, and open `Socks5.xcodeproj`.

Based on [hev-socks5-server](https://github.com/heiher/hev-socks5-server). [MIT License](LICENSE).
