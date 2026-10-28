//
//  TVPlaybackSessionReporter.swift
//  cascade-tvOS
//
//  Created by Thomas Rife on 6/1/26.
//

import AVFoundation
import Foundation

final class TVPlaybackSessionReporter {
    private let player: AVPlayer
    private let service: JellyfinService
    private let session: PreparedPlaybackSession

    private var timeObserver: Any?
    private var completionObserver: NSObjectProtocol?
    private var hasStopped = false

    init(
        player: AVPlayer,
        service: JellyfinService,
        session: PreparedPlaybackSession
    ) {
        self.player = player
        self.service = service
        self.session = session

        addTimeObserver()
        addCompletionObserver()

        Task {
            try? await service.reportPlaybackStart(for: session)
        }
    }

    deinit {
        removeObservers()
    }

    func stop(isFailed: Bool = false) {
        Task {
            _ = await stopAndWait(isFailed: isFailed)
        }
    }

    @discardableResult
    func stopAndWait(isFailed: Bool = false) async -> Int {
        guard !hasStopped else { return currentPositionTicks() }
        hasStopped = true

        let positionTicks = currentPositionTicks()
        removeObservers()

        try? await service.reportPlaybackProgress(
            for: session,
            positionTicks: positionTicks,
            isPaused: true
        )

        try? await service.reportPlaybackStopped(
            for: session,
            positionTicks: positionTicks,
            isFailed: isFailed
        )

        return positionTicks
    }

    private func addTimeObserver() {
        let interval = CMTime(seconds: 10, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }

            let positionTicks = self.currentPositionTicks(from: time)
            let isPaused = self.player.timeControlStatus != .playing

            Task {
                try? await self.service.reportPlaybackProgress(
                    for: self.session,
                    positionTicks: positionTicks,
                    isPaused: isPaused
                )
            }
        }
    }

    private func addCompletionObserver() {
        completionObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
        }
    }

    private func removeObservers() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        if let completionObserver {
            NotificationCenter.default.removeObserver(completionObserver)
            self.completionObserver = nil
        }
    }

    private func currentPositionTicks(from time: CMTime? = nil) -> Int {
        let resolvedTime = time ?? player.currentTime()
        let seconds = max(resolvedTime.seconds, 0)
        return Int(seconds * 10_000_000)
    }
}

extension Notification.Name {
    static let tvResumeStateDidChange = Notification.Name("tvResumeStateDidChange")
}
