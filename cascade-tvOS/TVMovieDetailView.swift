//
//  TVMovieDetailView.swift
//  cascade-tvOS
//
//  Created by Thomas Rife on 6/1/26.
//

import AVKit
import SwiftUI
import JellyfinAPI

struct TVMovieDetailView: View {
    let movie: BaseItemDto
    let posterURL: URL?

    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var player: AVPlayer?
    @State private var playbackReporter: TVPlaybackSessionReporter?
    @State private var isPresentingPlayer = false
    @State private var isPreparingPlayback = false
    @State private var playbackError: String?
    @StateObject private var playbackOptions = MoviePlaybackOptions()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top, spacing: 40) {
                    poster

                    VStack(alignment: .leading, spacing: 20) {
                        Text(movie.name ?? "Untitled")
                            .font(.title)

                        if let metaLine {
                            Text(metaLine)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let metadata {
                            Text(metadata)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        MovieTrackSelector(options: playbackOptions) {
                            Task { await loadMediaDetails() }
                        }

                        Button {
                            Task {
                                await startPlayback()
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if isPreparingPlayback {
                                    ProgressView()
                                }

                                Text(isPreparingPlayback ? "Loading..." : "Play")
                                    .font(.title3.weight(.semibold))
                            }
                            .frame(width: 240)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isPreparingPlayback)

                        if let playbackError {
                            Text(playbackError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        if let overview = movie.overview, !overview.isEmpty {
                            Text(overview)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineSpacing(6)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(60)
        }
//        .navigationTitle(movie.name ?? "Movie")
        .fullScreenCover(isPresented: $isPresentingPlayer, onDismiss: stopPlayback) {
            if let player {
                TVVideoPlayerView(player: player)
                    .ignoresSafeArea()
            }
        }
        .task(id: movie.id) {
            await loadMediaDetails()
        }
    }

    private var metaLine: String? {
        var values: [String] = []
        if let year = movie.productionYear {
            values.append(String(year))
        }
        if let rating = movie.officialRating, !rating.isEmpty {
            values.append(rating)
        }
        if let runtimeText {
            values.append(runtimeText)
        }
        return values.isEmpty ? nil : values.joined(separator: " • ")
    }

    private var runtimeText: String? {
        guard let runTimeTicks = movie.runTimeTicks, runTimeTicks > 0 else { return nil }
        let totalMinutes = runTimeTicks / 10_000_000 / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    private var metadata: String? {
        let values = [resolutionText, audioFormatText]
            .compactMap { $0 }

        return values.isEmpty ? nil : values.joined(separator: " • ")
    }
    
    private var primaryMediaSource: MediaSourceInfo? {
        playbackOptions.mediaSource ?? movie.mediaSources?.first
    }

    private var videoStream: MediaStream? {
        primaryMediaSource?.mediaStreams?.first(where: { $0.type == .video })
            ?? movie.mediaStreams?.first(where: { $0.type == .video })
    }

    private var audioStream: MediaStream? {
        let streams = primaryMediaSource?.mediaStreams ?? movie.mediaStreams ?? []
        let index = playbackOptions.selection.audioStreamIndex ?? primaryMediaSource?.defaultAudioStreamIndex
        return streams.first(where: { $0.type == .audio && $0.index == index })
            ?? streams.first(where: { $0.type == .audio })
    }

    private var resolutionText: String? {
        let width = videoStream?.width ?? movie.width
        let height = videoStream?.height ?? movie.height

        guard let width, let height else { return nil }

        if width >= 3800 || height >= 2100 {
            return "4K"
        } else if width >= 2500 || height >= 1400 {
            return "1440p"
        } else if width >= 1900 || height >= 1000 {
            return "1080p"
        } else if width >= 1200 || height >= 700 {
            return "720p"
        } else {
            return "\(height)p"
        }
    }

    private var audioFormatText: String? {
        guard let audioStream else { return nil }

        var parts: [String] = []

        if let codec = audioStream.codec?.uppercased(), !codec.isEmpty {
            parts.append(codec)
        }

        if let channels = audioStream.channels {
            let channelText: String
            switch channels {
            case 1: channelText = "Mono"
            case 2: channelText = "Stereo"
            case 6: channelText = "5.1"
            case 8: channelText = "7.1"
            default: channelText = "\(channels)ch"
            }

            parts.append(channelText)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " ")
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
                Image(systemName: "film")
                    .font(.system(size: 54))
                    .foregroundStyle(.secondary)
            }
    }

    @MainActor
    private func loadMediaDetails() async {
        await playbackOptions.load(
            itemID: movie.id,
            service: sessionStore.service,
            userID: sessionStore.activeAccount?.userID
        )
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
                for: movie,
                userID: account.userID,
                quality: settingsStore.playbackQuality,
                trackSelection: playbackOptions.selection
            )
            let player = try await playbackSession.makePlayer()
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
