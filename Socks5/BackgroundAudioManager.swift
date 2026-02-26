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
        setupNotifications()
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

    // MARK: - Interruption & Route Change Handling

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // 전화, 알람 등으로 인터럽트 시작 — 재생이 자동으로 멈춤
            print("[BackgroundAudio] Interruption began")

        case .ended:
            // 인터럽트 종료 — 오디오 세션 복구 후 재생 재개
            print("[BackgroundAudio] Interruption ended, resuming playback")
            setupAudioSession()
            player?.play()

        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        // 블루투스 해제, 이어폰 뽑기 등으로 재생이 멈출 수 있음 → 복구
        if reason == .oldDeviceUnavailable {
            print("[BackgroundAudio] Audio route changed, resuming playback")
            player?.play()
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
