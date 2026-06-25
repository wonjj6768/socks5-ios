# ProxiFyre iOS SOCKS5 Server

An iOS SOCKS5 server build for routing ProxiFyre TCP/UDP traffic through an
iPhone hotspot.

## Features

* IPv4/IPv6. (dual stack)
* Standard `CONNECT` command.
* Standard `UDP ASSOCIATE` command.
* Fixed-port SOCKS5 UDP relay for clients that expect one UDP port.
* Live traffic counters in the app and Dynamic Island.
* Extended `FWD UDP` command. (UDP in TCP)
* Multiple username/password authentication.

## UDP Relay

This repository builds `hev-socks5-server` with
`patches/hev-socks5-server-udp-associate-port0.patch`.

The patch is intended for a single fixed relay port: TCP/UDP `8888`.
ProxiFyre can send `UDP ASSOCIATE 0.0.0.0:0`, and the server still replies
with `BND.PORT = 8888`.

Supported and tested:

* TCP `CONNECT`.
* SOCKS5 `UDP ASSOCIATE 0.0.0.0:0`.
* DNS over UDP.
* STUN / VoIP-style UDP.
* UDP/443 QUIC-style datagrams.
* Multiple concurrent zero-port UDP associations.
* Remote replies from a different UDP source port.

The GitHub Actions build runs a local SOCKS5 UDP smoke test before packaging
the unsigned IPA.

## Traffic Monitor

The app shows 1-second TCP/UDP upload and download rates plus total relayed
bytes. The same counters are also shown in the Live Activity / Dynamic Island.

## Build

### HevSocks5Server.xcframework

```bash
git clone https://github.com/heiher/hev-socks5-server
cd hev-socks5-server
git checkout 52d7e475ef932e93540d1d964e02839f233ad981
git submodule update --init --recursive
git apply ../patches/hev-socks5-server-udp-associate-port0.patch
./build-apple.sh
```

### App

1. Copy HevSocks5Server.xcframework to this project directory.
2. Build it with Xcode.

## Dependencies

* HevSocks5Server - https://github.com/heiher/hev-socks5-server
  (`52d7e475ef932e93540d1d964e02839f233ad981`, patched at build time)

## Contributors

* **hev** - https://hev.cc

## License

MIT
