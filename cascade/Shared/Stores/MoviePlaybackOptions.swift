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
