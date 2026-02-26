//
//  Socks5App.swift
//  Socks5
//

import SwiftUI

@main
struct Socks5App: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    BackgroundAudioManager.shared.start()
                }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                BackgroundAudioManager.shared.resume()
            default:
                break
            }
        }
    }
}
