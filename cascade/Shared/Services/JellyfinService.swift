//
//  JellyfinService.swift
//  cascade
//
//  Created by Thomas Rife on 5/30/26.
//

import AVFoundation
import Foundation
import JellyfinAPI
import Get

final class JellyfinService {
    enum PlaybackError: LocalizedError {
        case missingItemID
        case missingMediaSource
        case invalidStreamURL
        case missingTranscodingURL
        case unavailableTrack

        var errorDescription: String? {
            switch self {
            case .missingItemID:
                return "The selected item does not have a valid Jellyfin id."
            case .missingMediaSource:
                return "Jellyfin did not return a playable media source for this item."
            case .invalidStreamURL:
                return "The generated playback URL was invalid."
            case .missingTranscodingURL:
                return "Jellyfin did not return a compatible transcoded stream."
            case .unavailableTrack:
                return "The selected track is no longer available. Reopen Audio & Subtitles and choose a track again."
            }
        }
    }

    private let client: JellyfinClient
    private(set) var currentUser: UserDto?

    init(
        serverURL: URL,
        deviceName: String,
        deviceID: String,
        appVersion: String,
        accessToken: String? = nil,
        sessionConfiguration: URLSessionConfiguration = .default
    ) {
        self.client = JellyfinClient(
            configuration: .init(
                url: serverURL,
                accessToken: accessToken,
                client: "Cascade",
                deviceName: deviceName,
                deviceID: deviceID,
                version: appVersion,
            ),
            sessionConfiguration: sessionConfiguration
        )
    }
    
    func signIn(username: String, password: String) async throws -> AuthenticationResult {
        let auth = try await client.signIn(username: username, password: password)
        currentUser = auth.user
        return auth
    }
    
    func signOut() async throws -> Void {
        try await client.signOut()
    }
    
    func fetchPublicUsers() async throws -> [UserDto] {
        try await client.send(Paths.getPublicUsers).value
    }
    
    func validateServer() async throws -> PublicSystemInfo {
        try await client.send(Paths.getPublicSystemInfo).value
    }
    
    func fetchViews(userID: String) async throws -> [BaseItemDto] {
        let result = try await client.send(
            Paths.getUserViews(parameters: .init(userID: userID))
        ).value

        return result.items ?? []
    }
    
    func fetchMovies(userID: String, parentID: String?) async throws -> [BaseItemDto] {
        let result = try await client.send(
            Paths.getItems(parameters: .init(
                userID: userID,
                isRecursive: true,
                sortOrder: [.descending],
                parentID: parentID,
                fields: [.overview, .mediaStreams, .path, .dateCreated], includeItemTypes: [.movie],
                sortBy: [.dateCreated],
                enableUserData: true, enableImages: true
            ))
        ).value

        return result.items ?? []
    }
    
    func fetchShows(userID: String, parentID: String?) async throws -> [BaseItemDto] {
        let result = try await client.send(
            Paths.getItems(parameters: .init(
                userID: userID,
                isRecursive: true,
                sortOrder: [.descending],
                parentID: parentID,
                fields: [.overview, .mediaStreams, .dateCreated, .dateLastMediaAdded], includeItemTypes: [.series],
                sortBy: [.dateLastContentAdded, .dateCreated],
                enableUserData: true, enableImages: true
            ))
        ).value

        return result.items ?? []
    }

    func fetchResumeItems(userID: String, limit: Int? = nil) async throws -> [BaseItemDto] {
        let result = try await client.send(
            Paths.getResumeItems(
                parameters: .init(
                    userID: userID,
                    limit: limit,
                    fields: [.overview, .mediaStreams],
                    mediaTypes: [.video],
                    enableUserData: true,
                    includeItemTypes: [.movie, .episode],
                    enableImages: true
                )
            )
        ).value

        return result.items ?? []
    }

    func fetchSeasons(userID: String, seriesID: String) async throws -> [BaseItemDto] {
        let result = try await client.send(
            Paths.getSeasons(
                seriesID: seriesID,
                parameters: .init(
                    userID: userID,
                    fields: [.overview, .mediaStreams],
                    enableImages: true,
                    enableUserData: true
                )
            )
        ).value

        return result.items ?? []
    }

    func fetchEpisodes(userID: String, seriesID: String, seasonID: String) async throws -> [BaseItemDto] {
        let result = try await client.send(
            Paths.getEpisodes(
                seriesID: seriesID,
                parameters: .init(
                    userID: userID,
                    fields: [.overview, .mediaStreams],
                    seasonID: seasonID,
                    enableImages: true,
                    enableUserData: true,
                    sortBy: .sortName
                )
            )
        ).value

        return result.items ?? []
    }

    func posterURL(for item: BaseItemDto, maxHeight: Int = 420) -> URL? {
        itemImageURL(for: item, imageType: .primary, maxHeight: maxHeight, requiresPosterAspectRatio: true)
    }

    func thumbURL(for item: BaseItemDto, maxHeight: Int = 320) -> URL? {
        itemImageURL(for: item, imageType: .thumb, maxHeight: maxHeight, requiresPosterAspectRatio: false)
            ?? itemImageURL(for: item, imageType: .primary, maxHeight: maxHeight, requiresPosterAspectRatio: false)
    }

    func landscapeArtworkURL(for item: BaseItemDto, maxWidth: Int = 720, maxHeight: Int = 405) -> URL? {
        thumbURL(for: item, maxWidth: maxWidth, maxHeight: maxHeight)
            ?? backdropURL(for: item, maxWidth: maxWidth, maxHeight: maxHeight)
    }

    private func itemImageURL(
        for item: BaseItemDto,
        imageType: ImageType,
        maxWidth: Int? = nil,
        maxHeight: Int,
        requiresPosterAspectRatio: Bool
    ) -> URL? {
        guard let itemID = item.id else { return nil }
        guard let imageTag = item.imageTags?[imageType.rawValue] else { return nil }
        guard !requiresPosterAspectRatio || hasPosterLikeAspectRatio(for: item) else { return nil }

        let request = Paths.getItemImage(
            itemID: itemID,
            imageType: imageType.rawValue,
            parameters: .init(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
                quality: 90,
                tag: imageTag
            )
        )

        return client.url(with: request, queryAPIKey: true)
    }

    private func thumbURL(for item: BaseItemDto, maxWidth: Int, maxHeight: Int) -> URL? {
        itemImageURL(
            for: item,
            imageType: .thumb,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            requiresPosterAspectRatio: false
        )
    }

    private func backdropURL(for item: BaseItemDto, maxWidth: Int, maxHeight: Int) -> URL? {
        guard let itemID = item.id else { return nil }
        guard let tag = item.backdropImageTags?.first else { return nil }

        let request = Paths.getItemImage(
            itemID: itemID,
            imageType: ImageType.backdrop.rawValue,
            parameters: .init(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
                quality: 90,
                tag: tag,
                imageIndex: 0
            )
        )

        return client.url(with: request, queryAPIKey: true)
    }

    func playbackURL(
        for item: BaseItemDto,
        userID: String,
        quality: PlaybackQualityPreset
    ) async throws -> URL {
        let session = try await preparePlaybackSession(for: item, userID: userID, quality: quality)
        return session.streamURL
    }

    func fetchMediaDetails(itemID: String, userID: String) async throws -> BaseItemDto {
        try await client.send(Paths.getItem(itemID: itemID, userID: userID)).value
    }

    func preparePlaybackSession(
        for item: BaseItemDto,
        userID: String,
        quality: PlaybackQualityPreset,
        startTimeTicks: Int? = nil,
        trackSelection: MovieTrackSelection = .init()
    ) async throws -> PreparedPlaybackSession {
        guard let itemID = item.id else {
            throw PlaybackError.missingItemID
        }

        let resolvedStartTimeTicks = startTimeTicks ?? item.userData?.playbackPositionTicks
        let prefersDirectPlayback = quality.allowsDirectPlay && !trackSelection.hasExplicitSelection
        let playbackItem = try await fetchMediaDetails(itemID: itemID, userID: userID)
        
        let selectedMediaSource: MediaSourceInfo?
        if let sourceID = trackSelection.mediaSourceID {
            guard let source = playbackItem.mediaSources?.first(where: { $0.id == sourceID }) else {
                throw PlaybackError.unavailableTrack
            }
            selectedMediaSource = source
        } else {
            selectedMediaSource = playbackItem.mediaSources?.first
        }
        let selectedMediaSourceID = selectedMediaSource?.id
        let streams = selectedMediaSource?.mediaStreams ?? playbackItem.mediaStreams ?? []
        if let index = trackSelection.audioStreamIndex,
           !streams.contains(where: { $0.type == .audio && $0.index == index }) {
            throw PlaybackError.unavailableTrack
        }
        if let index = trackSelection.subtitleStreamIndex, index != -1,
           !streams.contains(where: { $0.type == .subtitle && $0.index == index }) {
            throw PlaybackError.unavailableTrack
        }
        let selectedAudioStreamIndex = trackSelection.audioStreamIndex ?? preferredAudioStreamIndex(
            item: playbackItem,
            mediaSource: selectedMediaSource,
            prefersDirectPlayback: prefersDirectPlayback
        )
        let selectedSubtitleStreamIndex = trackSelection.subtitleStreamIndex ?? preferredSubtitleStreamIndex(
            item: playbackItem,
            mediaSource: selectedMediaSource
        )
        let selectedSubtitle = streams.first { $0.type == .subtitle && $0.index == selectedSubtitleStreamIndex }
        let burnsSubtitles = selectedSubtitle.map { subtitle in
            subtitle.isTextSubtitleStream != true
        } ?? false
        // A static file ignores server-side track choices. Use HLS when the user
        // picks a track; Original can still copy video unless subtitles need burning.
        let allowsVideoCopy = quality.allowsDirectPlay && !burnsSubtitles
        let allowsAudioCopy = quality.allowsDirectPlay
        let info = PlaybackInfoDto(
            allowAudioStreamCopy: allowsAudioCopy,
            allowVideoStreamCopy: allowsVideoCopy,
            audioStreamIndex: selectedAudioStreamIndex,
            deviceProfile: playbackDeviceProfile(for: quality),
            enableDirectPlay: prefersDirectPlayback,
            enableDirectStream: quality.allowsDirectPlay && !burnsSubtitles,
            enableTranscoding: true,
            maxAudioChannels: 6,
            maxStreamingBitrate: quality.preferredPlaybackBitrate,
            mediaSourceID: selectedMediaSourceID,
            startTimeTicks: resolvedStartTimeTicks,
            subtitleStreamIndex: selectedSubtitleStreamIndex,
            userID: userID
        )

        let playbackParameters = Paths.GetPostedPlaybackInfoParameters(
            userID: userID,
            maxStreamingBitrate: quality.preferredPlaybackBitrate,
            startTimeTicks: resolvedStartTimeTicks,
            audioStreamIndex: selectedAudioStreamIndex,
            subtitleStreamIndex: selectedSubtitleStreamIndex,
            maxAudioChannels: 6,
            mediaSourceID: selectedMediaSourceID,
            enableDirectPlay: prefersDirectPlayback,
            enableDirectStream: quality.allowsDirectPlay && !burnsSubtitles,
            enableTranscoding: true,
            allowVideoStreamCopy: allowsVideoCopy,
            allowAudioStreamCopy: allowsAudioCopy
        )

        let playbackInfo = try await client.send(
            Paths.getPostedPlaybackInfo(
                itemID: itemID,
                parameters: playbackParameters,
                info
            )
        ).value
        

        guard let mediaSource = playbackInfo.mediaSources?.first(where: { selectedMediaSourceID == nil || $0.id == selectedMediaSourceID }) else {
            throw PlaybackError.missingMediaSource
        }

        guard let mediaSourceID = mediaSource.id else {
            throw PlaybackError.missingMediaSource
        }
        
        let streamURL: URL
        let playMethod: PlayMethod
        
        if let transcodingURL = mediaSource.transcodingURL,
           let authenticatedTranscodingURL = authenticatedURL(path: transcodingURL) {
            streamURL = authenticatedTranscodingURL
            playMethod = .transcode
        } else if prefersDirectPlayback,
                  let directStreamURL = directStreamURL(
                      itemID: itemID,
                      mediaSourceID: mediaSourceID,
                      playSessionID: playbackInfo.playSessionID,
                      audioStreamIndex: selectedAudioStreamIndex ?? mediaSource.defaultAudioStreamIndex,
                      subtitleStreamIndex: selectedSubtitleStreamIndex
                  ) {
            streamURL = directStreamURL
            playMethod = .directPlay
        } else {
            let request: Request<Data> = Paths.getMasterHlsVideoPlaylist(
                itemID: itemID,
                parameters: .init(
                    isStatic: false,
                    playSessionID: playbackInfo.playSessionID,
                    segmentContainer: "ts",
                    mediaSourceID: mediaSourceID,
                    deviceID: client.configuration.deviceID,
                    audioCodec: "aac",
                    allowVideoStreamCopy: false,
                    allowAudioStreamCopy: false,
                    audioBitRate: 192_000,
                    maxAudioChannels: 6,
                    videoBitRate: quality.preferredPlaybackBitrate - 192_000,
                    subtitleStreamIndex: selectedSubtitleStreamIndex,
                    subtitleMethod: burnsSubtitles ? .encode : .hls,
                    videoCodec: "h264",
                    audioStreamIndex: selectedAudioStreamIndex ?? mediaSource.defaultAudioStreamIndex,
                    enableAdaptiveBitrateStreaming: true
                )
            )
            guard let fallbackStreamURL = client.url(with: request, queryAPIKey: true) else {
                throw PlaybackError.missingTranscodingURL
            }

            streamURL = fallbackStreamURL
            playMethod = .transcode
        }
        

        return PreparedPlaybackSession(
            itemID: itemID,
            mediaSourceID: mediaSourceID,
            playSessionID: playbackInfo.playSessionID,
            audioStreamIndex: selectedAudioStreamIndex ?? mediaSource.defaultAudioStreamIndex,
            subtitleStreamIndex: selectedSubtitleStreamIndex,
            explicitSubtitleStreamIndex: trackSelection.subtitleStreamIndex,
            burnsSubtitles: burnsSubtitles,
            playMethod: playMethod,
            streamURL: streamURL,
            startTimeTicks: resolvedStartTimeTicks
        )
    }

    func reportPlaybackStart(for session: PreparedPlaybackSession) async throws {
        try await client.send(Paths.reportPlaybackStart(playbackStateInfo(for: session, positionTicks: session.startTimeTicks, isPaused: false)))
    }

    func reportPlaybackProgress(
        for session: PreparedPlaybackSession,
        positionTicks: Int,
        isPaused: Bool
    ) async throws {
        try await client.send(Paths.reportPlaybackProgress(playbackStateInfo(for: session, positionTicks: positionTicks, isPaused: isPaused)))
    }

    func reportPlaybackStopped(
        for session: PreparedPlaybackSession,
        positionTicks: Int,
        isFailed: Bool = false
    ) async throws {
        try await client.send(
            Paths.reportPlaybackStopped(
                .init(
                    isFailed: isFailed,
                    itemID: session.itemID,
                    mediaSourceID: session.mediaSourceID,
                    playSessionID: session.playSessionID,
                    positionTicks: positionTicks
                )
            )
        )
    }

    private func playbackStateInfo(
        for session: PreparedPlaybackSession,
        positionTicks: Int?,
        isPaused: Bool
    ) -> PlaybackStateInfo {
        PlaybackStateInfo(
            audioStreamIndex: session.audioStreamIndex,
            canSeek: true,
            isPaused: isPaused,
            itemID: session.itemID,
            mediaSourceID: session.mediaSourceID,
            playMethod: session.playMethod,
            playSessionID: session.playSessionID,
            positionTicks: positionTicks,
            subtitleStreamIndex: session.subtitleStreamIndex
        )
    }
    
    private func playbackDeviceProfile(for quality: PlaybackQualityPreset) -> DeviceProfile {
        DeviceProfile(
            directPlayProfiles: quality.allowsDirectPlay ? [
                DirectPlayProfile(
                    audioCodec: "aac,ac3,eac3,mp3,alac",
                    container: "mp4,m4v,mov",
                    type: .video,
                    videoCodec: "h264,hevc"
                )
            ] : [],
            maxStreamingBitrate: quality.preferredPlaybackBitrate,
            name: "Cascade",
            subtitleProfiles: [
                SubtitleProfile(format: "vtt", method: .hls),
                SubtitleProfile(format: "srt", method: .hls),
                SubtitleProfile(format: "subrip", method: .hls),
                SubtitleProfile(format: "ass", method: .hls),
                SubtitleProfile(format: "ssa", method: .hls),
                SubtitleProfile(format: "dvbsub", method: .encode),
                SubtitleProfile(format: "dvdsub", method: .encode),
                SubtitleProfile(format: "pgs", method: .encode),
                SubtitleProfile(format: "pgssub", method: .encode),
                SubtitleProfile(format: "xsub", method: .encode)
            ],
            transcodingProfiles: [
                TranscodingProfile(
                    protocol: .hls,
                    audioCodec: "aac",
                    container: "ts",
                    context: .streaming,
                    enableSubtitlesInManifest: true,
                    type: .video,
                    videoCodec: "h264"
                )
            ]
        )
    }

    func subtitleOptions(for item: BaseItemDto) -> [SubtitleOption] {
        let streams = item.mediaStreams ?? item.mediaSources?.first?.mediaStreams ?? []

        return streams
            .filter { $0.type == .subtitle }
            .compactMap { stream in
                guard let index = stream.index else { return nil }

                return SubtitleOption(
                    index: index,
                    language: stream.language ?? "Unknown",
                    title: stream.displayTitle ?? stream.title ?? stream.language ?? "Subtitle",
                    isDefault: stream.isDefault ?? false,
                    isForced: stream.isForced ?? false
                )
            }
    }

    private func hasPosterLikeAspectRatio(for item: BaseItemDto) -> Bool {
        guard let aspectRatio = item.primaryImageAspectRatio else {
            return true
        }

        return (0.45...0.85).contains(aspectRatio)
    }

    private func mediaSourceLooksAppleCompatible(_ mediaSource: MediaSourceInfo?) -> Bool {
        guard let mediaSource else { return false }

        let container = mediaSource.container?.lowercased()
        let allowedContainers = Set(["mp4", "m4v", "mov"])
        guard let container, allowedContainers.contains(container) else {
            return false
        }

        let streams = mediaSource.mediaStreams ?? []
        let videoStreams = streams.filter { $0.type == .video }
        let audioStreams = streams.filter { $0.type == .audio }

        let allowedVideoCodecs = Set(["h264", "hevc"])
        let allowedAudioCodecs = Set(["aac", "ac3", "eac3", "mp3", "alac"])

        let videoIsCompatible = videoStreams.isEmpty || videoStreams.allSatisfy { stream in
            guard let codec = stream.codec?.lowercased() else { return false }
            return allowedVideoCodecs.contains(codec)
        }

        let audioIsCompatible = audioStreams.isEmpty || audioStreams.allSatisfy { stream in
            guard let codec = stream.codec?.lowercased() else { return false }
            return allowedAudioCodecs.contains(codec)
        }

        return videoIsCompatible && audioIsCompatible
    }

    private func directStreamURL(
        itemID: String,
        mediaSourceID: String,
        playSessionID: String?,
        audioStreamIndex: Int?,
        subtitleStreamIndex: Int?
    ) -> URL? {
        let request: Request<Data> = Paths.getVideoStream(
            itemID: itemID,
            parameters: .init(
                isStatic: true,
                playSessionID: playSessionID,
                mediaSourceID: mediaSourceID,
                deviceID: client.configuration.deviceID,
                subtitleStreamIndex: subtitleStreamIndex,
                audioStreamIndex: audioStreamIndex
            )
        )

        return client.url(with: request, queryAPIKey: true)
    }

    private func authenticatedURL(path: String) -> URL? {
        guard let pathComponents = URLComponents(string: path) else { return nil }

        let relativePath = String(pathComponents.path.drop(while: { $0 == "/" }))
        let url = client.configuration.url.appending(path: relativePath, directoryHint: .notDirectory)

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        var queryItems = components.queryItems ?? []
        if let pathQueryItems = pathComponents.queryItems {
            queryItems.append(contentsOf: pathQueryItems)
        }
        let hasAPIKey = queryItems.contains { $0.name.caseInsensitiveCompare("api_key") == .orderedSame }
        if !hasAPIKey, let accessToken = client.accessToken {
            queryItems.append(URLQueryItem(name: "api_key", value: accessToken))
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url
    }

    private func preferredAudioStreamIndex(
        item: BaseItemDto,
        mediaSource: MediaSourceInfo?,
        prefersDirectPlayback: Bool
    ) -> Int? {
        let audioStreams = (mediaSource?.mediaStreams ?? item.mediaStreams ?? []).filter { $0.type == .audio }
        let defaultIndex = mediaSource?.defaultAudioStreamIndex
            ?? audioStreams.first(where: { $0.isDefault == true })?.index
            ?? audioStreams.first?.index
        guard !audioStreams.isEmpty else { return defaultIndex }

        if prefersDirectPlayback {
            return defaultIndex
        }

        let ranked = audioStreams.compactMap { stream -> (index: Int, score: Int)? in
            guard let index = stream.index else { return nil }

            let codec = stream.codec?.lowercased() ?? ""
            let title = [
                stream.title?.lowercased(),
                stream.displayTitle?.lowercased()
            ]
            .compactMap { $0 }
            .joined(separator: " ")

            var score = 0

            if title.contains("commentary") {
                score -= 1_000
            }

            switch codec {
            case "aac":
                score += 120
            case "ac3":
                score += 110
            case "eac3":
                score += 100
            case "mp3":
                score += 90
            case "alac":
                score += 70
            case "truehd", "dts", "dca", "dtshd_ma", "dtshd_hra", "flac":
                score -= 100
            default:
                score += 10
            }

            let channels = stream.channels ?? 2
            switch channels {
            case ...2:
                score += 20
            case 3...6:
                score += 35
            default:
                score -= 25
            }

            if index == defaultIndex {
                score += 5
            }
            if stream.isDefault == true {
                score += 5
            }

            return (index, score)
        }

        return ranked.max { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.index > rhs.index
            }
            return lhs.score < rhs.score
        }?.index ?? defaultIndex ?? audioStreams.first?.index
    }

    private func preferredSubtitleStreamIndex(
        item: BaseItemDto,
        mediaSource: MediaSourceInfo?
    ) -> Int? {
        let subtitleStreams = (mediaSource?.mediaStreams ?? item.mediaStreams ?? [])
            .filter { $0.type == .subtitle }

        return mediaSource?.defaultSubtitleStreamIndex
            ?? subtitleStreams.first(where: { $0.isDefault == true })?.index
            ?? subtitleStreams.first(where: { $0.isForced == true })?.index
    }
}

struct SubtitleOption: Identifiable, Hashable {
    let index: Int
    let language: String
    let title: String
    let isDefault: Bool
    let isForced: Bool

    var id: Int { index }
}

struct PreparedPlaybackSession {
    let itemID: String
    let mediaSourceID: String
    let playSessionID: String?
    let audioStreamIndex: Int?
    let subtitleStreamIndex: Int?
    let explicitSubtitleStreamIndex: Int?
    let burnsSubtitles: Bool
    let playMethod: PlayMethod
    let streamURL: URL
    let startTimeTicks: Int?

    @MainActor
    func makePlayer() async throws -> AVPlayer {
        let player = AVPlayer(url: streamURL)
        guard let index = explicitSubtitleStreamIndex, !burnsSubtitles,
              let item = player.currentItem else { return player }

        // Keep the explicit movie-page choice from being replaced by OS language preferences.
        player.appliesMediaSelectionCriteriaAutomatically = false
        if let group = try await item.asset.loadMediaSelectionGroup(for: .legible) {
            if index == -1 {
                item.select(nil, in: group)
            } else if let option = group.defaultOption {
                item.select(option, in: group)
            } else {
                throw JellyfinService.PlaybackError.unavailableTrack
            }
        } else if index != -1 {
            throw JellyfinService.PlaybackError.unavailableTrack
        }
        return player
    }
}

nonisolated struct MovieTrackSelection {
    var mediaSourceID: String?
    var audioStreamIndex: Int?
    // nil follows Jellyfin's preference; -1 explicitly disables subtitles.
    var subtitleStreamIndex: Int?

    var hasExplicitSelection: Bool {
        audioStreamIndex != nil || subtitleStreamIndex != nil
    }
}
