//
//  MovieUIComponents.swift
//  cascade
//
//  Created by Thomas Rife on 5/31/26.
//

import AVKit
import SwiftUI
import JellyfinAPI
#if canImport(UIKit)
import UIKit
#endif

enum PosterLayout {
    case rail
    case grid
}

enum PosterStyle {
    static let posterAspectRatio: CGFloat = 2 / 3
    static let horizontalPadding: CGFloat = 16
    static let horizontalSpacing: CGFloat = 16
    static let verticalSpacing: CGFloat = 20
    static let gridColumnCount = 3
    static let cornerRadius: CGFloat = 12

    static var railWidth: CGFloat { cardWidth }

    static var cardWidth: CGFloat {
        #if canImport(UIKit)
        let screenWidth = UIScreen.main.bounds.width
        #else
        let screenWidth: CGFloat = 390
        #endif

        let totalSpacing = (horizontalPadding * 2) + (horizontalSpacing * CGFloat(gridColumnCount - 1))
        return floor((screenWidth - totalSpacing) / CGFloat(gridColumnCount))
    }

    static var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(cardWidth), spacing: horizontalSpacing),
            count: gridColumnCount
        )
    }
}

struct MovieRailSection: View {
    let title: String
    let movies: [BaseItemDto]
    let service: JellyfinService?
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .padding(.horizontal)

            HorizontalMovieRail(
                movies: movies,
                service: service,
                emptyText: emptyText
            )
        }
    }
}

struct HorizontalMovieRail: View {
    let movies: [BaseItemDto]
    let service: JellyfinService?
    let emptyText: String

    var body: some View {
        if movies.isEmpty {
            Text(emptyText)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: PosterStyle.horizontalSpacing) {
                    ForEach(Array(movies.enumerated()), id: \.offset) { _, movie in
                        MoviePosterCard(
                            movie: movie,
                            posterURL: service?.posterURL(for: movie),
                            layout: .rail
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct MoviePosterGridView: View {
    let title: String
    let movies: [BaseItemDto]
    let service: JellyfinService?

    private let columns = PosterStyle.gridColumns

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: PosterStyle.verticalSpacing) {
                ForEach(Array(movies.enumerated()), id: \.offset) { _, movie in
                    MoviePosterCard(
                        movie: movie,
                        posterURL: service?.posterURL(for: movie),
                        layout: .grid
                    )
                }
            }
            .padding()
        }
        .navigationTitle(title)
    }
}

struct MoviePosterCard: View {
    let movie: BaseItemDto
    let posterURL: URL?
    let layout: PosterLayout

    var body: some View {
        NavigationLink {
            MovieDetailView(
                movie: movie,
                posterURL: posterURL
            )
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                PosterArtworkBox(
                    title: movie.name ?? "Untitled",
                    systemImageName: "film",
                    posterURL: posterURL
                )
                .frame(width: width)
                .frame(maxWidth: layout == .grid ? .infinity : nil)

                if posterURL == nil {
                    Text(movie.name ?? "Untitled")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                if let year = movie.productionYear {
                    Text(String(year))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: layout == .grid ? .infinity : nil, alignment: .leading)
            .frame(width: width, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var width: CGFloat? {
        switch layout {
        case .rail:
            return PosterStyle.railWidth
        case .grid:
            return PosterStyle.cardWidth
        }
    }
}

struct PosterArtworkBox: View {
    let title: String
    let systemImageName: String
    let posterURL: URL?

    var body: some View {
        RoundedRectangle(cornerRadius: PosterStyle.cornerRadius, style: .continuous)
            .fill(Color.secondary.opacity(0.12))
            .aspectRatio(PosterStyle.posterAspectRatio, contentMode: .fit)
            .overlay {
                content
                    .clipShape(RoundedRectangle(cornerRadius: PosterStyle.cornerRadius, style: .continuous))
            }
            .clipShape(RoundedRectangle(cornerRadius: PosterStyle.cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: PosterStyle.cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        if let posterURL {
            AsyncImage(url: posterURL) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
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
        RoundedRectangle(cornerRadius: PosterStyle.cornerRadius, style: .continuous)
            .fill(Color.secondary.opacity(0.18))
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: systemImageName)
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)

                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .padding(.horizontal, 12)
                }
            }
    }
}

struct MovieDetailView: View {
    let movie: BaseItemDto
    let posterURL: URL?

    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var player: AVPlayer?
    @State private var playbackReporter: PlaybackSessionReporter?
    @State private var isPresentingPlayer = false
    @State private var isPreparingPlayback = false
    @State private var playbackError: String?
    @State private var isExpanded: Bool = false
    @State private var isPresentingMediaInfo = false

    private let topBleedHeight: CGFloat = 220

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        posterContainer

                        heroDetailsSection

                        VStack(alignment: .leading, spacing: 10) {
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

                            if let overview = movie.overview, !overview.isEmpty {
                                Text(overview)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(isExpanded ? nil : 2)
                            } else {
                                Text("No description available.")
                                    .foregroundStyle(.secondary)
                            }

                            if let playbackError {
                                Text(playbackError)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Information")
                                .font(.title3)
                                .bold()

                            if let genres = movie.genres, !genres.isEmpty {
                                InfoRow(label: "Genres", value: genres.joined(separator: ", "))
                            }

                            if let genreItems = movie.genreItems, !genreItems.isEmpty {
                                InfoRow(label: "Genre Items", value: genreItems.compactMap(\.name).joined(separator: ", "))
                            }

                            if let studios = movie.studios, !studios.isEmpty {
                                InfoRow(label: "Studios", value: studios.compactMap(\.name).joined(separator: ", "))
                            }

                            if let taglines = movie.taglines, !taglines.isEmpty {
                                InfoRow(label: "Taglines", value: taglines.joined(separator: " • "))
                            }

                            if let officialRating = movie.officialRating, !officialRating.isEmpty {
                                InfoRow(label: "Official Rating", value: officialRating)
                            }

                            if let communityRating = movie.communityRating {
                                InfoRow(label: "Audience Rating", value: String(format: "%.1f", communityRating))
                            }

                            if let criticRating = movie.criticRating {
                                InfoRow(label: "Critic Rating", value: String(format: "%.1f", criticRating))
                            }

                            if let productionYear = movie.productionYear {
                                InfoRow(label: "Release Year", value: String(productionYear))
                            }

                            if let premiereDate = movie.premiereDate {
                                InfoRow(label: "Premiere Date", value: premiereDate.formatted(date: .abbreviated, time: .omitted))
                            }
                        }
                        .cardSurface()
                        .padding(.horizontal)
                    }
                    .padding(.bottom)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingMediaInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.headline)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .fullScreenCover(isPresented: $isPresentingPlayer, onDismiss: stopPlayback) {
            if let player {
                NativeVideoPlayerView(player: player)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $isPresentingMediaInfo) {
            MovieMediaInfoSheet(rows: mediaInfoRows)
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
            Text(movie.name ?? "Untitled")
                .font(.title.weight(.bold))
                .lineLimit(2)

            HStack(alignment: .top, spacing: 12) {
                HStack(spacing: 12) {
                    if let year = movie.productionYear {
                        Text(String(year))
                    }

//                    if let rating = movie.officialRating, !rating.isEmpty {
//                        Text(rating)
//                    }

                    if let runtime = runtimeText {
                        Text(runtime)
                    }
                }

//                Spacer(minLength: 12)

                if let heroTechnicalSummaryText {
                    Text(heroTechnicalSummaryText)
                        .font(.caption)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

//            if let genres = movie.genres, !genres.isEmpty {
//                Text(genres.joined(separator: " • "))
//                    .font(.footnote.weight(.medium))
//                    .foregroundStyle(.secondary)
//                    .lineLimit(2)
//            }

            Button {
                Task {
                    await startPlayback()
                }
            } label: {
                HStack(spacing: 10) {
                    if isPreparingPlayback {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.headline)
                    }

                    Text(isPreparingPlayback ? "Loading..." : "Play")
                        .font(.headline.weight(.semibold))
                }
                .playButton()
            }
            .buttonStyle(.plain)
            .disabled(isPreparingPlayback)
            .padding(.top, 6)
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
        if let detailPosterURL {
            AsyncImage(url: detailPosterURL) { phase in
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

    private var detailPosterURL: URL? {
        sessionStore.service?.posterURL(for: movie, maxHeight: 1600) ?? posterURL
    }

    private var placeholder: some View {
        Color.secondary.opacity(0.18)
            .overlay {
                Image(systemName: "film")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
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

    private var runtimeText: String? {
        guard let ticks = movie.runTimeTicks, ticks > 0 else { return nil }
        let totalSeconds = ticks / 10_000_000
        let totalMinutes = totalSeconds / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private var primaryMediaSource: MediaSourceInfo? {
        movie.mediaSources?.first
    }

    private var videoStream: MediaStream? {
        primaryMediaSource?.mediaStreams?.first(where: { $0.type == .video })
            ?? movie.mediaStreams?.first(where: { $0.type == .video })
    }

    private var audioStream: MediaStream? {
        primaryMediaSource?.mediaStreams?.first(where: { $0.type == .audio })
            ?? movie.mediaStreams?.first(where: { $0.type == .audio })
    }

    private var technicalSummaryText: String? {
        let parts = [resolutionText, bitrateText, audioFormatText]
            .compactMap { $0 }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " • ")
    }

    private var heroTechnicalSummaryText: String? {
        let parts = [resolutionText, audioFormatText]
            .compactMap { $0 }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " • ")
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

    private var bitrateText: String? {
        guard let bitrate = primaryMediaSource?.bitrate, bitrate > 0 else { return nil }

        let megabits = Double(bitrate) / 1_000_000
        if megabits >= 10 {
            return String(format: "%.0f Mbps", megabits)
        } else {
            return String(format: "%.1f Mbps", megabits)
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
            case 1:
                channelText = "Mono"
            case 2:
                channelText = "Stereo"
            case 6:
                channelText = "5.1"
            case 8:
                channelText = "7.1"
            default:
                channelText = "\(channels)ch"
            }

            parts.append(channelText)
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " ")
    }

    private var defaultAudioText: String? {
        guard let audioStream else { return nil }

        var parts: [String] = []
        if let language = audioStream.language, !language.isEmpty {
            parts.append(language.capitalized)
        }
        if let title = audioStream.displayTitle ?? audioStream.title, !title.isEmpty, !parts.contains(title) {
            parts.append(title)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private var defaultSubtitleText: String? {
        let streams = primaryMediaSource?.mediaStreams ?? movie.mediaStreams ?? []

        guard let subtitleStream = streams.first(where: { ($0.type == .subtitle) && ($0.isDefault ?? false || $0.index == primaryMediaSource?.defaultSubtitleStreamIndex) }) else {
            return nil
        }

        var parts: [String] = []
        if let language = subtitleStream.language, !language.isEmpty {
            parts.append(language.capitalized)
        }
        if let title = subtitleStream.displayTitle ?? subtitleStream.title, !title.isEmpty, !parts.contains(title) {
            parts.append(title)
        }
        if subtitleStream.isForced == true {
            parts.append("Forced")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private var subtitleTracksText: String? {
        guard let service = sessionStore.service else { return nil }

        let subtitleTitles = service.subtitleOptions(for: movie).map { option in
            var parts = [option.language.capitalized]
            if option.isForced {
                parts.append("Forced")
            }
            return parts.joined(separator: " ")
        }

        guard !subtitleTitles.isEmpty else { return nil }
        return subtitleTitles.joined(separator: ", ")
    }

    private var containerText: String? {
        primaryMediaSource?.container?.uppercased() ?? movie.container?.uppercased()
    }

    private var videoCodecText: String? {
        videoStream?.codec?.uppercased()
    }

    private var filenameText: String? {
        guard let path = primaryMediaSource?.path ?? movie.path else { return nil }
        return path.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last.map(String.init)
    }

    private var mediaInfoRows: [(label: String, value: String)] {
        [
            ("Filename", filenameText),
            ("Resolution", resolutionText),
            ("Bitrate", bitrateText),
            ("Container", containerText),
            ("Video Codec", videoCodecText),
            ("Audio Format", audioFormatText),
            ("Default Audio", defaultAudioText),
            ("Default Subtitle", defaultSubtitleText),
            ("Subtitle Tracks", subtitleTracksText)
        ]
        .compactMap { label, value in
            guard let value, !value.isEmpty else { return nil }
            return (label, value)
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
                for: movie,
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

private struct NativeVideoPlayerView: UIViewControllerRepresentable {
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

private struct MovieMediaInfoSheet: View {
    let rows: [(label: String, value: String)]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if rows.isEmpty {
                        Text("No file details available.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.label)
                                    .font(.caption)
                                    .foregroundStyle(.primary)

                                Text(row.value)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("File Info")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
