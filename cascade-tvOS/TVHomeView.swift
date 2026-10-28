//
//  TVHomeView.swift
//  cascade-tvOS
//
//  Created by Thomas Rife on 6/1/26.
//

import AVKit
import JellyfinAPI
import SwiftUI

struct TVHomeView: View {
    @ObservedObject var homeStore: HomeStore

    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        NavigationStack {
            Group {
                if homeStore.isLoading && homeStore.movies.isEmpty && homeStore.resumeItems.isEmpty {
                    ProgressView("Loading Library...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = homeStore.errorMessage,
                          homeStore.movies.isEmpty,
                          homeStore.resumeItems.isEmpty {
                    ContentUnavailableView(
                        "Couldn’t Load Home",
                        systemImage: "wifi.exclamationmark",
                        description: Text(errorMessage)
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 36) {
                            if !homeStore.recentResumeItems.isEmpty {
                                TVLandscapeRailSection(
                                    title: "Continue Watching",
                                    items: homeStore.recentResumeItems,
                                    artwork: { item in
                                        sessionStore.service?.landscapeArtworkURL(for: item, maxWidth: 760, maxHeight: 428)
                                    }
                                )
                                .buttonStyle(.card)
                            }
                            

                            if !homeStore.recentMovies.isEmpty {
                                TVLandscapeRailSection(
                                    title: "Recently Added",
                                    items: homeStore.recentMovies,
                                    artwork: { item in
                                        sessionStore.service?.landscapeArtworkURL(for: item, maxWidth: 760, maxHeight: 428)
                                    }
                                )
                                .buttonStyle(.card)
                            }
                        }
                        .padding(.horizontal, 60)
                        .padding(.vertical, 40)
                    }
                }
            }
        }
        .task(id: sessionStore.activeAccount?.id) {
            homeStore.reset()
            await homeStore.load(using: sessionStore)
        }
        .onReceive(NotificationCenter.default.publisher(for: .tvResumeStateDidChange)) { _ in
            Task {
                await homeStore.refreshResumeItems(using: sessionStore)
            }
        }
    }
}

private struct TVLandscapeRailSection: View {
    let title: String
    let items: [BaseItemDto]
    let artwork: (BaseItemDto) -> URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 28) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        TVLandscapeMediaCard(
                            item: item,
                            artworkURL: artwork(item)
                        )
                    }
                    .buttonStyle(.card)
                }
//                .focusable(true, interactions: .automatic)
//                .padding(.horizontal, 20)
//                .padding(.vertical, 28)
            }
        }
    }
}

private struct TVLandscapeMediaCard: View {
    let item: BaseItemDto
    let artworkURL: URL?

    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var player: AVPlayer?
    @State private var playbackReporter: TVPlaybackSessionReporter?
    @State private var isPresentingPlayer = false
    @State private var isPreparingPlayback = false
    @State private var playbackError: String?

    private var isShowLike: Bool {
        item.type == .series || item.type == .episode
    }

    private var progressFraction: Double? {
        guard
            let playedPercentage = item.userData?.playedPercentage,
            playedPercentage > 0
        else {
            return nil
        }

        return min(max(playedPercentage / 100, 0), 1)
    }

    var body: some View {
        Button {
            Task {
                await startPlayback()
            }
        } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))

                if let artworkURL {
                    AsyncImage(url: artworkURL) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            placeholder
                        case .empty:
                            ZStack {
                                placeholder
                                ProgressView()
                            }
                        @unknown default:
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }

                if let progressFraction {
                    VStack {
                        Spacer()
                        TVProgressBar(progress: progressFraction)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 16)
                    }
                }
            }
            .frame(width: 520, height: 292)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .tvFocusCardStyle()
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .disabled(isPreparingPlayback)
        .overlay(alignment: .topLeading) {
            if isPreparingPlayback {
                ProgressView()
                    .padding(18)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let playbackError {
                Text(playbackError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
            }
        }
        .fullScreenCover(isPresented: $isPresentingPlayer, onDismiss: stopPlayback) {
            if let player {
                TVVideoPlayerView(player: player)
                    .ignoresSafeArea()
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.secondary.opacity(0.18))
            .overlay {
                Image(systemName: isShowLike ? "tv" : "film")
                    .font(.system(size: 46))
                    .foregroundStyle(.secondary)
            }
    }

    @MainActor
    private func startPlayback() async {
        guard let service = sessionStore.service, let account = sessionStore.activeAccount else {
            playbackError = "Missing active session."
            return
        }

        isPreparingPlayback = true
        playbackError = nil
        defer { isPreparingPlayback = false }

        do {
            let playbackSession = try await service.preparePlaybackSession(
                for: item,
                userID: account.userID,
                quality: settingsStore.playbackQuality
            )
            let player = AVPlayer(url: playbackSession.streamURL)
            if let startTimeTicks = playbackSession.startTimeTicks, startTimeTicks > 0 {
                await seek(player: player, to: startTimeTicks)
            }
            self.player = player
            playbackReporter = TVPlaybackSessionReporter(
                player: player,
                service: service,
                session: playbackSession
            )
            isPresentingPlayer = true
            player.play()
        } catch {
            playbackError = error.localizedDescription
        }
    }

    @MainActor
    private func stopPlayback() {
        let reporter = playbackReporter
        playbackReporter = nil
        player?.pause()
        player = nil

        Task {
            _ = await reporter?.stopAndWait()
            NotificationCenter.default.post(name: .tvResumeStateDidChange, object: nil)
        }
    }

    private func seek(player: AVPlayer, to ticks: Int) async {
        let time = CMTime(value: Int64(ticks), timescale: 10_000_000)
        await withCheckedContinuation { continuation in
            player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                continuation.resume()
            }
        }
    }
}

private struct TVProgressBar: View {
    let progress: Double

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.black.opacity(0.35))
                .frame(height: 8)

            GeometryReader { proxy in
                Capsule()
                    .fill(.white)
                    .frame(width: proxy.size.width * progress, height: 8)
            }
        }
        .frame(height: 8)
    }
}

#Preview {
    TVHomeView(homeStore: HomeStore())
        .environmentObject(SessionStore())
        .environmentObject(SettingsStore())
}
