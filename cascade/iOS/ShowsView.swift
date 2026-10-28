//
//  ShowsView.swift
//  cascade
//
//  Created by Thomas Rife on 5/31/26.
//

import AVKit
import SwiftUI
import JellyfinAPI

private enum ShowOrganization: String, CaseIterable, Identifiable {
    case recentlyAdded
    case alphabetical
    case releaseYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recentlyAdded:
            return "Recently Added"
        case .alphabetical:
            return "Alphabetical"
        case .releaseYear:
            return "Release Year"
        }
    }
}

struct ShowsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @ObservedObject var homeStore: HomeStore

    @State private var organization: ShowOrganization = .recentlyAdded

    private let columns = PosterStyle.gridColumns

    var body: some View {
        NavigationStack {
            Group {
                if homeStore.isLoading {
                    ProgressView("Loading shows...")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if groupedShows.isEmpty {
                                Text("No shows found.")
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                            } else {
                                ForEach(Array(groupedShows.enumerated()), id: \.offset) { _, group in
                                    VStack(alignment: .leading, spacing: 12) {
                                        if !group.title.isEmpty {
                                            Text(group.title)
                                                .font(.title3.weight(.semibold))
                                                .padding(.horizontal)
                                        }

                                        LazyVGrid(columns: columns, spacing: PosterStyle.verticalSpacing) {
                                            ForEach(Array(group.shows.enumerated()), id: \.offset) { _, show in
                                                NavigationLink {
                                                    ShowDetailView(
                                                        show: show,
                                                        posterURL: sessionStore.service?.posterURL(for: show, maxHeight: 900)
                                                    )
                                                } label: {
                                                    ShowPosterCard(
                                                        show: show,
                                                        posterURL: sessionStore.service?.posterURL(for: show)
                                                    )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
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
            .navigationTitle("Shows")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(ShowOrganization.allCases) { option in
                            Button {
                                organization = option
                            } label: {
                                if organization == option {
                                    Label(option.title, systemImage: "checkmark")
                                } else {
                                    Text(option.title)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                }
            }
        }
        .task(id: sessionStore.activeAccount?.userID) {
            await homeStore.load(using: sessionStore)
        }
    }

    private var groupedShows: [(title: String, shows: [BaseItemDto])] {
        switch organization {
        case .recentlyAdded:
            let sortedShows = homeStore.shows.sorted { lhs, rhs in
                sortDate(for: lhs) > sortDate(for: rhs)
            }

            return [("", sortedShows)]

        case .alphabetical:
            let groups = Dictionary(grouping: homeStore.shows) { show in
                let first = show.name?.trimmingCharacters(in: .whitespacesAndNewlines).first
                return first.map { String($0).uppercased() } ?? "#"
            }

            return groups
                .map { (title: $0.key, shows: sortShows($0.value)) }
                .sorted { $0.title < $1.title }

        case .releaseYear:
            let groups = Dictionary(grouping: homeStore.shows) { show in
                show.productionYear.map(String.init) ?? "Unknown Year"
            }

            return groups
                .map { (title: $0.key, shows: sortShows($0.value)) }
                .sorted { lhs, rhs in
                    if lhs.title == "Unknown Year" { return false }
                    if rhs.title == "Unknown Year" { return true }
                    return lhs.title > rhs.title
                }
        }
    }

    private func sortShows(_ shows: [BaseItemDto]) -> [BaseItemDto] {
        shows.sorted {
            ($0.name ?? "Untitled").localizedCaseInsensitiveCompare($1.name ?? "Untitled") == .orderedAscending
        }
    }

    private func sortDate(for item: BaseItemDto) -> Date {
        item.dateLastMediaAdded ?? item.dateCreated ?? .distantPast
    }
}

#Preview {
    ShowsView(homeStore: HomeStore())
        .environmentObject(SessionStore())
}

private struct ShowPosterCard: View {
    let show: BaseItemDto
    let posterURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PosterArtworkBox(
                title: show.name ?? "Untitled",
                systemImageName: "tv",
                posterURL: posterURL
            )
            .frame(maxWidth: .infinity)

            if posterURL == nil {
                Text(show.name ?? "Untitled")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if let year = show.productionYear {
                Text(String(year))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

struct ShowDetailView: View {
    let show: BaseItemDto
    let posterURL: URL?

    @EnvironmentObject private var sessionStore: SessionStore

    @State private var seasons: [BaseItemDto] = []
    @State private var episodesBySeasonID: [String: [BaseItemDto]] = [:]
    @State private var isLoadingEpisodes = false
    @State private var episodeError: String?
    @State private var isExpanded: Bool = false

    private let topBleedHeight: CGFloat = 220
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    posterContainer

                    heroDetailsSection

                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment:.leading, spacing:10) {
                            HStack {
                                Text("About")
                                    .font(.title3)
                                    .bold()

                                Spacer()

                                Button(action: {
                                    isExpanded.toggle()
                                }) {
                                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                }
                                .buttonStyle(.plain)
                            }

                            if let overview = show.overview, !overview.isEmpty {
                                Text(overview)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(isExpanded ? nil : 2)
                            } else {
                                Text("No description available.")
                                    .foregroundStyle(.secondary)
                            }

                        }

                        if isLoadingEpisodes {
                            ProgressView("Loading episodes...")
                                .padding(.top)
                        } else {
                            ForEach(Array(seasons.enumerated()), id: \.offset) { _, season in
                                if let seasonID = season.id,
                                   let episodes = episodesBySeasonID[seasonID],
                                   !episodes.isEmpty {
                                    EpisodeRailSection(
                                        title: season.name ?? "Season",
                                        episodes: episodes,
                                        service: sessionStore.service
                                    )
                                }
                            }
                        }

                        if let episodeError {
                            Text(episodeError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Information")
                        .font(.title3)
                        .bold()

                    if let genres = show.genres, !genres.isEmpty {
                        InfoRow(label: "Genres", value: genres.joined(separator: ", "))
                    }

                    if let genreItems = show.genreItems, !genreItems.isEmpty {
                        InfoRow(label: "Genre Items", value: genreItems.compactMap(\.name).joined(separator: ", "))
                    }

                    if let studios = show.studios, !studios.isEmpty {
                        InfoRow(label: "Studios", value: studios.compactMap(\.name).joined(separator: ", "))
                    }

                    if let taglines = show.taglines, !taglines.isEmpty {
                        InfoRow(label: "Taglines", value: taglines.joined(separator: " • "))
                    }

                    if let officialRating = show.officialRating, !officialRating.isEmpty {
                        InfoRow(label: "Official Rating", value: officialRating)
                    }

                    if let communityRating = show.communityRating {
                        InfoRow(label: "Audience Rating", value: String(format: "%.1f", communityRating))
                    }

                    if let criticRating = show.criticRating {
                        InfoRow(label: "Critic Rating", value: String(format: "%.1f", criticRating))
                    }

                    if let productionYear = show.productionYear {
                        InfoRow(label: "Production Year", value: String(productionYear))
                    }

                    if let premiereDate = show.premiereDate {
                        InfoRow(label: "Premiere Date", value: premiereDate.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()
                .padding()
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .ignoresSafeArea(edges: .top)
        .task(id: show.id) {
            await loadEpisodes()
        }
    }

    private var posterContainer: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.12))
            .frame(maxWidth: .infinity)
            .frame(height: 620)
            .background(alignment: .top) {
                topBleedBackground
                    .offset(y: -topBleedHeight)
            }
            .overlay {
                poster
            }
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [
                        .black.opacity(0.55),
                        .black.opacity(0.18),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 160)
                .allowsHitTesting(false)
            }
    }

    private var heroDetailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(show.name ?? "Untitled")
                .font(.title.weight(.bold))
                .lineLimit(2)

            HStack(spacing: 12) {
                if let year = show.productionYear {
                    Text(String(year))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let genres = show.genres, !genres.isEmpty {
                Text(genres.joined(separator: " • "))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal)
    }

    private var topBleedBackground: some View {
        poster
            .frame(maxWidth: .infinity)
            .frame(height: topBleedHeight)
            .blur(radius: 22)
            .clipped()
            .overlay {
                LinearGradient(
                    colors: [
                        .black.opacity(0.45),
                        .black.opacity(0.22),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var poster: some View {
        if let posterURL {
            AsyncImage(url: posterURL) { phase in
                switch phase {
                case let .success(image):
                    GeometryReader { proxy in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    }
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
        Color.secondary.opacity(0.18)
            .overlay {
                Image(systemName: "tv")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
            }
    }

    @MainActor
    private func loadEpisodes() async {
        guard let service = sessionStore.service,
              let account = sessionStore.activeAccount,
              let showID = show.id
        else {
            episodeError = "Missing active session."
            return
        }

        isLoadingEpisodes = true
        episodeError = nil
        defer { isLoadingEpisodes = false }

        do {
            let seasons = try await service.fetchSeasons(userID: account.userID, seriesID: showID)
            self.seasons = seasons

            var loadedEpisodes: [String: [BaseItemDto]] = [:]
            for season in seasons {
                guard let seasonID = season.id else { continue }
                loadedEpisodes[seasonID] = try await service.fetchEpisodes(
                    userID: account.userID,
                    seriesID: showID,
                    seasonID: seasonID
                )
            }

            episodesBySeasonID = loadedEpisodes
        } catch {
            episodeError = error.localizedDescription
        }
    }
}

private struct EpisodeRailSection: View {
    let title: String
    let episodes: [BaseItemDto]
    let service: JellyfinService?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: PosterStyle.horizontalSpacing) {
                    ForEach(Array(episodes.enumerated()), id: \.offset) { _, episode in
                        EpisodeCard(
                            episode: episode,
                            artworkURL: service?.thumbURL(for: episode)
                        )
                    }
                }
            }
        }
    }
}

private struct EpisodeCard: View {
    let episode: BaseItemDto
    let artworkURL: URL?

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
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))

                    if let artworkURL {
                        AsyncImage(url: artworkURL) { phase in
                            switch phase {
                            case let .success(image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                episodePlaceholder
                            case .empty:
                                ZStack {
                                    episodePlaceholder
                                    ProgressView()
                                }
                            @unknown default:
                                episodePlaceholder
                            }
                        }
                    } else {
                        episodePlaceholder
                    }
                }
                .frame(width: 240, height: 135)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(episodeTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                if let episodeDuration {
                    Text(episodeDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let overview = episode.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                if let playbackError {
                    Text(playbackError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
            .frame(width: 240, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(isPreparingPlayback)
        .fullScreenCover(isPresented: $isPresentingPlayer, onDismiss: stopPlayback) {
            if let player {
                EpisodeVideoPlayerView(player: player)
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

    private var episodeDuration: String? {
        guard let runTimeTicks = episode.runTimeTicks, runTimeTicks > 0 else {
            return nil
        }

        let totalSeconds = runTimeTicks / 10_000_000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }

    private var episodePlaceholder: some View {
        Color.secondary.opacity(0.18)
            .overlay {
                Image(systemName: "tv")
                    .font(.system(size: 28))
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

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.primary)
            
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct EpisodeVideoPlayerView: UIViewControllerRepresentable {
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
