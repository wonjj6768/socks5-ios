//
//  BackgroundAudioManager.swift
//  Socks5
//

import AVFoundation

final class BackgroundAudioManager {
    static let shared = BackgroundAudioManager()

    private var player: AVAudioPlayer?
    private(set) var isPlaying: Bool = false

    private init() {
        setupAudioSession()
        setupPlayer()
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[BackgroundAudio] Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Player Setup

    private func setupPlayer() {
        guard let url = Bundle.main.url(forResource: "silent", withExtension: "wav") else {
            print("[BackgroundAudio] silent.wav not found in bundle")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.volume = 0.01
            player?.prepareToPlay()
        } catch {
            print("[BackgroundAudio] Failed to init player: \(error)")
        }
    }

    // MARK: - Controls

    func start() {
        guard !isPlaying else { return }
        player?.play()
        isPlaying = true
    }

    func stop() {
        player?.stop()
        isPlaying = false
    }

    /// 앱이 다시 포그라운드로 돌아왔을 때 오디오 세션을 복구
    func resume() {
        setupAudioSession()
        if !(player?.isPlaying ?? false) {
            player?.play()
        }
        isPlaying = true
    }
}
