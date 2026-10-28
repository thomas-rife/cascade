//
//  TVShowDetailView.swift
//  cascade-tvOS
//
//  Created by Thomas Rife on 6/1/26.
//

import AVKit
import SwiftUI
import JellyfinAPI

struct TVShowDetailView: View {
    let show: BaseItemDto
    let posterURL: URL?

    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var seasons: [BaseItemDto] = []
    @State private var episodesBySeasonID: [String: [BaseItemDto]] = [:]
    @State private var isLoadingEpisodes = false
    @State private var episodeError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top, spacing: 40) {
                    poster

                    VStack(alignment: .leading, spacing: 20) {
                        Text(show.name ?? "Untitled")
                            .font(.system(size: 42, weight: .bold))

                        if let metaLine {
                            Text(metaLine)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }

                        if let overview = show.overview, !overview.isEmpty {
                            Text(overview)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineSpacing(6)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if isLoadingEpisodes {
                    ProgressView("Loading Episodes...")
                        .padding(.top, 20)
                } else if let episodeError {
                    Text(episodeError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else {
                    VStack(alignment: .leading, spacing: 32) {
                        ForEach(Array(seasons.enumerated()), id: \.offset) { _, season in
                            if let seasonID = season.id, let episodes = episodesBySeasonID[seasonID], !episodes.isEmpty {
                                TVEpisodeRailSection(
                                    title: season.name ?? "Season",
                                    episodes: episodes
                                )
                            }
                        }
                    }
                }
            }
            .padding(60)
        }
//        .navigationTitle(show.name ?? "Show")
        .task(id: show.id) {
            await loadEpisodes()
        }
    }

    private var metaLine: String? {
        var values: [String] = []
        if let year = show.productionYear {
            values.append(String(year))
        }
        if let status = show.status, !status.isEmpty {
            values.append(status)
        }
        return values.isEmpty ? nil : values.joined(separator: " • ")
    }

    @ViewBuilder
    private var poster: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.secondary.opacity(0.12))

            if let posterURL {
                AsyncImage(url: posterURL) { phase in
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
        }
        .frame(width: 360, height: 540)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.secondary.opacity(0.18))
            .overlay {
                Image(systemName: "tv")
                    .font(.system(size: 54))
                    .foregroundStyle(.secondary)
            }
    }

    @MainActor
    private func loadEpisodes() async {
        guard let service = sessionStore.service,
              let account = sessionStore.activeAccount,
              let showID = show.id else {
            return
        }

        isLoadingEpisodes = true
        episodeError = nil
        defer { isLoadingEpisodes = false }

        do {
            let fetchedSeasons = try await service.fetchSeasons(userID: account.userID, seriesID: showID)
            seasons = fetchedSeasons

            var mappedEpisodes: [String: [BaseItemDto]] = [:]
            for season in fetchedSeasons {
                guard let seasonID = season.id else { continue }
                let episodes = try await service.fetchEpisodes(
                    userID: account.userID,
                    seriesID: showID,
                    seasonID: seasonID
                )
                mappedEpisodes[seasonID] = episodes
            }

            episodesBySeasonID = mappedEpisodes
        } catch {
            episodeError = error.localizedDescription
        }
    }
}

private struct TVEpisodeRailSection: View {
    let title: String
    let episodes: [BaseItemDto]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(Array(episodes.enumerated()), id: \.offset) { _, episode in
                        TVEpisodeCard(episode: episode)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
        }
    }
}

private struct TVEpisodeCard: View {
    let episode: BaseItemDto

    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var player: AVPlayer?
    @State private var playbackReporter: TVPlaybackSessionReporter?
    @State private var isPresentingPlayer = false
    @State private var isPreparingPlayback = false
    @State private var playbackError: String?

    var body: some View {
        Button {
            Task {
                await startPlayback()
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                artwork

                Text(episodeTitle)
                    .font(.headline)
                    .lineLimit(2)

                if let playbackError {
                    Text(playbackError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
            .frame(width: 360, alignment: .leading)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .disabled(isPreparingPlayback)
        .fullScreenCover(isPresented: $isPresentingPlayer, onDismiss: stopPlayback) {
            if let player {
                TVVideoPlayerView(player: player)
                    .ignoresSafeArea()
            }
        }
    }

    private var episodeTitle: String {
        if let index = episode.indexNumber {
            return "E\(index) • \(episode.name ?? "Untitled")"
        }
        return episode.name ?? "Untitled"
    }

    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.secondary.opacity(0.12))

            if let thumbURL = sessionStore.service?.thumbURL(for: episode, maxHeight: 320) {
                AsyncImage(url: thumbURL) { phase in
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
        }
        .frame(width: 360, height: 202)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .focusEffectDisabled()
        .tvFocusCardStyle()
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.secondary.opacity(0.18))
            .overlay {
                Image(systemName: "tv")
                    .font(.system(size: 36))
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
                for: episode,
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
