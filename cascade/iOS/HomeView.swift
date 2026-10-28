//
//  HomeView.swift
//  cascade
//
//  Created by Thomas Rife on 5/31/26.
//

import AVKit
import SwiftUI
import JellyfinAPI

struct HomeView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @ObservedObject var homeStore: HomeStore
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if homeStore.isLoading {
                    ProgressView("Loading library...")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
//                            if let account = sessionStore.activeAccount {
//                                VStack(alignment: .leading, spacing: 4) {
//                                    Text(account.username)
//                                        .font(.title2.weight(.semibold))
//                                    Text(account.serverURL.absoluteString)
//                                        .foregroundStyle(.secondary)
//                                }
//                                .padding(.horizontal)
//                            }

                            MovieRailSection(
                                title: "Recently Added",
                                movies: homeStore.recentMovies,
                                service: sessionStore.service,
                                emptyText: "No recent movies found."
                            )

                            if !homeStore.recentResumeItems.isEmpty {
                                RecentlyWatchedRailSection(
                                    items: homeStore.recentResumeItems,
                                    allItems: homeStore.sortedResumeItems
                                )
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Recommended")
                                        .font(.title3.weight(.semibold))

                                    Spacer()

//                                    NavigationLink("See All") {
//                                        MoviePosterGridView(
//                                            title: "All Movies",
//                                            movies: homeStore.movies,
//                                            service: sessionStore.service
//                                        )
//                                    }
                                }
                                .padding(.horizontal)

                                HorizontalMovieRail(
                                    movies: homeStore.randomMovies,
                                    service: sessionStore.service,
                                    emptyText: "No movies found."
                                )
                            }

                            if let errorMessage = homeStore.errorMessage {
                                Text(errorMessage)
                                    .foregroundStyle(.red)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        homeStore.reset()
                        await homeStore.load(using: sessionStore)
                    }
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
                .environmentObject(sessionStore)
                .environmentObject(settingsStore)
        }
        .task(id: sessionStore.activeAccount?.userID) {
//            homeStore.reset()
            await homeStore.load(using: sessionStore)
        }
    }
}

#Preview {
    HomeView(homeStore: HomeStore())
        .environmentObject(SessionStore())
        .environmentObject(SettingsStore())
}

private struct RecentlyWatchedRailSection: View {
    let items: [BaseItemDto]
    let allItems: [BaseItemDto]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recently Watched")
                    .font(.title3.weight(.semibold))

                Spacer()

                if allItems.count > items.count {
                    NavigationLink {
                        RecentlyWatchedView(items: allItems)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: PosterStyle.horizontalSpacing) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        ResumePlaybackCard(item: item, layout: .rail)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct RecentlyWatchedView: View {
    let items: [BaseItemDto]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    ResumePlaybackCard(item: item, layout: .list)
                }
            }
            .padding()
        }
        .navigationTitle("Recently Watched")
    }
}

private enum ResumeCardLayout {
    case rail
    case list
}

private struct ResumePlaybackCard: View {
    let item: BaseItemDto
    let layout: ResumeCardLayout

    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var player: AVPlayer?
    @State private var playbackReporter: PlaybackSessionReporter?
    @State private var isPresentingPlayer = false
    @State private var isPreparingPlayback = false
    @State private var playbackError: String?

    var body: some View {
        Button {
            Task {
                await startPlayback()
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))

                    artwork

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.82)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            if let subtitleText {
                                Text(subtitleText)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.82))
                                    .lineLimit(1)
                            }

                            Text(item.name ?? "Untitled")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }

                        progressBar
                    }
                    .padding(12)
                }
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if let playbackError {
                    Text(playbackError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: layout == .list ? .infinity : nil, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(isPreparingPlayback)
        .fullScreenCover(isPresented: $isPresentingPlayer, onDismiss: stopPlayback) {
            if let player {
                ResumeNativeVideoPlayerView(player: player)
                    .ignoresSafeArea()
            }
        }
    }

    private var cardWidth: CGFloat {
        switch layout {
        case .rail:
            return 240
        case .list:
            return max(UIScreen.main.bounds.width - 32, 0)
        }
    }

    private var cardHeight: CGFloat {
        switch layout {
        case .rail:
            return 135
        case .list:
            return min(220, cardWidth * 0.56)
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let artworkURL = sessionStore.service?.landscapeArtworkURL(for: item) {
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
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.secondary.opacity(0.18))
            .overlay {
                Image(systemName: "play.rectangle")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
            }
    }

    private var subtitleText: String? {
        if let seriesName = item.seriesName, !seriesName.isEmpty {
            if let index = item.indexNumber {
                return "\(seriesName) • E\(index)"
            }

            return seriesName
        }

        return nil
    }

    private var playbackProgress: Double {
        if let playedPercentage = item.userData?.playedPercentage {
            return min(max(playedPercentage / 100, 0), 1)
        }

        if
            let playbackPositionTicks = item.userData?.playbackPositionTicks,
            let runTimeTicks = item.runTimeTicks,
            runTimeTicks > 0
        {
            return min(max(Double(playbackPositionTicks) / Double(runTimeTicks), 0), 1)
        }

        return 0
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            let progressWidth = max(proxy.size.width * playbackProgress, 0)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.26))

                Capsule()
                    .fill(.white)
                    .frame(width: progressWidth)
            }
        }
        .frame(height: 4)
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
                quality: settingsStore.playbackQuality,
                startTimeTicks: item.userData?.playbackPositionTicks
            )

            let player = AVPlayer(url: playbackSession.streamURL)
            if let startTimeTicks = playbackSession.startTimeTicks, startTimeTicks > 0 {
                await seek(player: player, to: startTimeTicks)
            }
            #if os(iOS)
            AppOrientation.lock(.allButUpsideDown)
            #endif
            self.player = player
            playbackReporter = PlaybackSessionReporter(
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
        playbackReporter?.stop()
        playbackReporter = nil
        player?.pause()
        player = nil
        #if os(iOS)
        AppOrientation.lock(.portrait)
        #endif
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

private struct ResumeNativeVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.entersFullScreenWhenPlaybackBegins = true
        controller.exitsFullScreenWhenPlaybackEnds = true
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
    }
}
