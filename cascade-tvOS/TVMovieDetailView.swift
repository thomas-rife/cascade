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
    @State private var isSynopsisExpanded = false
    @State private var isPresentingFileInfo = false
    @StateObject private var playbackOptions = MoviePlaybackOptions()

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 52) {
                poster
                movieSummary
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 64)
            .padding(.vertical, 64)
        }
        .fullScreenCover(isPresented: $isPresentingPlayer, onDismiss: stopPlayback) {
            if let player {
                TVVideoPlayerView(player: player)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $isPresentingFileInfo) {
            TVMovieFileInfoSheet(
                fileInfo: fileInfo,
                isLoading: playbackOptions.isLoading,
                errorMessage: playbackOptions.errorMessage,
                retry: { Task { await loadMediaDetails() } }
            )
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
    
    private var movieSummary: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(movie.name ?? "Untitled")
                        .font(.largeTitle.bold())

                    ForEach([metaLine, fileInfo.summary].compactMap { $0 }, id: \.self) { line in
                        Text(line)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
                Button {
                    isPresentingFileInfo = true
                } label: {
                    Label("File Info", systemImage: "info.circle")
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 24) {
                Button {
                    Task { await startPlayback() }
                } label: {
                    if isPreparingPlayback {
                        ProgressView()
                    } else {
                        Label((movie.userData?.playbackPositionTicks ?? 0) > 0 ? "Resume" : "Play",
                              systemImage: "play.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPreparingPlayback)

                MovieTrackSelector(options: playbackOptions) {
                    Task { await loadMediaDetails() }
                }
            }

            if let playbackError {
                Text(playbackError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if let overview = playbackOptions.details?.overview ?? movie.overview, !overview.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(overview)
                        .lineLimit(isSynopsisExpanded ? nil : 3)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        isSynopsisExpanded.toggle()
                    } label: {
                        Label(isSynopsisExpanded ? "Show Less" : "Read More",
                              systemImage: isSynopsisExpanded ? "chevron.up" : "chevron.down")
                    }
                    .font(.callout)
                    .buttonStyle(.bordered)
                }
            }

            technicalDetails

            VStack(alignment: .leading, spacing: 10) {
                credit("Genre", names: genres)
                credit("Directed by", names: people(ofType: .director))
                credit("Starring", names: Array(people(ofType: .actor).prefix(5)))
            }
        }
    }

    private var fileInfo: MovieFileInfo {
        playbackOptions.fileInfo(for: movie, service: sessionStore.service)
    }

    @ViewBuilder
    private var technicalDetails: some View {
        let info = fileInfo
        let rows = info.technicalRows
        if !rows.isEmpty || info.defaultAudioTrackText != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("Technical Details")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                HStack(alignment: .top, spacing: 32) {
                    ForEach(rows, id: \.label) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(row.value)
                                .font(.callout)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                if let track = info.defaultAudioTrackText {
                    credit("Default Audio Track", names: [track])
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private var genres: [String] {
        if let genres = playbackOptions.details?.genres ?? movie.genres, !genres.isEmpty {
            return genres
        }
        return (playbackOptions.details?.genreItems ?? movie.genreItems ?? []).compactMap(\.name)
    }

    private func people(ofType type: PersonKind) -> [String] {
        (playbackOptions.details?.people ?? movie.people ?? [])
            .filter { $0.type == type }
            .compactMap(\.name)
    }

    @ViewBuilder
    private func credit(_ label: String, names: [String]) -> some View {
        if !names.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.callout.weight(.semibold))
                Text(names.joined(separator: ", "))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var poster: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.secondary.opacity(0.12))

            if let posterURL {
                CachedAsyncImage(url: posterURL) { phase in
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

private struct TVMovieFileInfoSheet: View {
    let fileInfo: MovieFileInfo
    let isLoading: Bool
    let errorMessage: String?
    let retry: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Label("File Info", systemImage: "info.circle")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)

                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(fileInfo.rows, id: \.label) { row in
                        infoRow(row.label, value: row.value)
                    }

                    if let track = fileInfo.defaultAudioTrackText {
                        infoRow("Default Audio Track", value: track)
                    }

                    if isLoading {
                        ProgressView("Loading file details…")
                    } else if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                        Button("Try Again", action: retry)
                            .buttonStyle(.bordered)
                    } else if fileInfo.rows.isEmpty {
                        Text("No file details available.")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
            }
            .focusable()
        }
        .padding(48)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
        }
        .accessibilityElement(children: .combine)
    }
}
