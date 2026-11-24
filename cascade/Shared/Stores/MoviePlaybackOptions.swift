import Combine
import Foundation
import JellyfinAPI

@MainActor
final class MoviePlaybackOptions: ObservableObject {
    @Published private(set) var details: BaseItemDto?
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    @Published var selection = MovieTrackSelection()

    var mediaSource: MediaSourceInfo? { details?.mediaSources?.first }
    var streams: [MediaStream] { mediaSource?.mediaStreams ?? details?.mediaStreams ?? [] }

    func fileInfo(for movie: BaseItemDto, service: JellyfinService?) -> MovieFileInfo {
        MovieFileInfo(
            movie: movie,
            details: details,
            audioStreamIndex: selection.audioStreamIndex,
            subtitleOptions: service?.subtitleOptions(for: details ?? movie) ?? []
        )
    }

    func load(itemID: String?, service: JellyfinService?, userID: String?) async {
        guard !Task.isCancelled else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let itemID, let service, let userID else {
            errorMessage = "File details are unavailable. Try again once connected."
            return
        }

        do {
            let item = try await service.fetchMediaDetails(itemID: itemID, userID: userID)
            try Task.checkCancellation()
            let sourceID = item.mediaSources?.first?.id
            if details?.id != item.id || selection.mediaSourceID != sourceID {
                selection = MovieTrackSelection(mediaSourceID: sourceID)
            }
            details = item
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "Couldn't load file details. \(error.localizedDescription)"
        }
    }
}

/// Formats source file details consistently for the iOS and tvOS movie pages.
struct MovieFileInfo {
    let movie: BaseItemDto
    let details: BaseItemDto?
    let audioStreamIndex: Int?
    let subtitleOptions: [SubtitleOption]

    private var primaryMediaSource: MediaSourceInfo? {
        details?.mediaSources?.first ?? movie.mediaSources?.first
    }

    private var videoStream: MediaStream? {
        primaryMediaSource?.mediaStreams?.first(where: { $0.type == .video })
            ?? movie.mediaStreams?.first(where: { $0.type == .video })
    }

    private var audioStream: MediaStream? {
        audioStreams.first(where: { audioStreamIndex != nil && $0.index == audioStreamIndex })
            ?? defaultAudioStream
    }

    private var audioStreams: [MediaStream] {
        (primaryMediaSource?.mediaStreams ?? details?.mediaStreams ?? movie.mediaStreams ?? [])
            .filter { $0.type == .audio }
    }

    private var defaultAudioStream: MediaStream? {
        let index = primaryMediaSource?.defaultAudioStreamIndex
        return audioStreams.first(where: { index != nil && $0.index == index })
            ?? audioStreams.first(where: { $0.isDefault == true })
            ?? audioStreams.first
    }

    var defaultAudioTrackText: String? {
        guard let stream = defaultAudioStream else { return nil }
        let description = [stream.displayTitle, stream.title, stream.language?.capitalized]
            .compactMap { $0 }
            .first { !$0.isEmpty }
        if let description { return description }
        return stream.index.map { "Track \($0)" }
    }

    var summary: String? {
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
        let streamBitrate = (primaryMediaSource?.mediaStreams ?? movie.mediaStreams ?? [])
            .filter { $0.type == .video || $0.type == .audio }
            .compactMap(\.bitRate).reduce(0, +)
        let bitrate = primaryMediaSource?.bitrate ?? streamBitrate
        guard bitrate > 0 else { return nil }

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

    private var subtitleTracksText: String? {
        let subtitleTitles = subtitleOptions.map { option in
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
        guard let path = primaryMediaSource?.path ?? details?.path ?? movie.path else { return nil }
        return path.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last.map(String.init)
    }

    var technicalRows: [(label: String, value: String)] {
        availableRows([
            ("Resolution", resolutionText),
            ("Bitrate", bitrateText),
            ("Container", containerText),
            ("Video Codec", videoCodecText),
            ("Audio Format", audioFormatText)
        ])
    }

    var rows: [(label: String, value: String)] {
        availableRows([("Filename", filenameText)]) + technicalRows
            + availableRows([("Subtitle Tracks", subtitleTracksText)])
    }

    private func availableRows(_ rows: [(String, String?)]) -> [(label: String, value: String)] {
        rows.compactMap { label, value in
            guard let value, !value.isEmpty else { return nil }
            return (label, value)
        }
    }
}
