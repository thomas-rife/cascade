//
//  HomeStore.swift
//  cascade
//
//  Created by Thomas Rife on 5/31/26.
//

import Foundation
import JellyfinAPI
import Combine

@MainActor
final class HomeStore: ObservableObject {
    @Published var movies: [BaseItemDto] = []
    @Published var shows: [BaseItemDto] = []
    @Published var resumeItems: [BaseItemDto] = []
    @Published var randomMovies: [BaseItemDto] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var loadedAccountID: String?

    var recentMovies: [BaseItemDto] {
        // Keep Jellyfin's newest-first library order for the Home rail too.
        Array(movies.prefix(10))
    }

    var recentResumeItems: [BaseItemDto] {
        Array(sortedResumeItems.prefix(5))
    }

    var hasMoreResumeItems: Bool {
        sortedResumeItems.count > recentResumeItems.count
    }

    var sortedResumeItems: [BaseItemDto] {
        resumeItems.sorted { lhs, rhs in
            let lhsDate = lhs.userData?.lastPlayedDate ?? .distantPast
            let rhsDate = rhs.userData?.lastPlayedDate ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    func load(using sessionStore: SessionStore) async {
        guard let service = sessionStore.service, let account = sessionStore.activeAccount else {
            errorMessage = "Missing active session."
            return
        }

        guard loadedAccountID != account.id else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let views = try await service.fetchViews(userID: account.userID)
            let movieParentID = views.first(where: { $0.collectionType == .movies })?.id
            let showParentID = views.first(where: { $0.collectionType == .tvshows })?.id

            async let fetchedMovies = service.fetchMovies(userID: account.userID, parentID: movieParentID)
            async let fetchedShows = service.fetchShows(userID: account.userID, parentID: showParentID)
            async let fetchedResumeItems = service.fetchResumeItems(userID: account.userID, limit: 24)

            movies = try await fetchedMovies
            shows = try await fetchedShows
            resumeItems = try await fetchedResumeItems
            randomMovies = Array(movies.shuffled().prefix(10))
            loadedAccountID = account.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        movies = []
        shows = []
        resumeItems = []
        randomMovies = []
        isLoading = false
        errorMessage = nil
        loadedAccountID = nil
    }

    func refreshResumeItems(using sessionStore: SessionStore) async {
        guard let service = sessionStore.service, let account = sessionStore.activeAccount else {
            return
        }

        do {
            resumeItems = try await service.fetchResumeItems(userID: account.userID, limit: 24)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
