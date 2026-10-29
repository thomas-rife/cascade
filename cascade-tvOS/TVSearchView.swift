//
//  TVSearchView.swift
//  cascade-tvOS
//
//  Created by Thomas Rife on 6/1/26.
//

import SwiftUI
import JellyfinAPI

struct TVSearchView: View {
    @ObservedObject var homeStore: HomeStore
    @State private var query = ""

    private var filteredMovies: [BaseItemDto] {
        filter(items: homeStore.movies)
    }

    private var filteredShows: [BaseItemDto] {
        filter(items: homeStore.shows)
    }

    var body: some View {
        NavigationStack {
            List {
                if !filteredMovies.isEmpty {
                    Section("Movies") {
                        ForEach(filteredMovies, id: \.id) { movie in
                            NavigationLink {
                                TVMovieDetailView(
                                    movie: movie,
                                    posterURL: homeStorePosterURL(for: movie)
                                )
                            } label: {
                                Text(movie.name ?? "Untitled Movie")
                            }
                        }
                    }
                }

                if !filteredShows.isEmpty {
                    Section("Shows") {
                        ForEach(filteredShows, id: \.id) { show in
                            NavigationLink {
                                TVShowDetailView(
                                    show: show,
                                    posterURL: homeStorePosterURL(for: show)
                                )
                            } label: {
                                Text(show.name ?? "Untitled Show")
                            }
                        }
                    }
                }

                if !query.isEmpty && filteredMovies.isEmpty && filteredShows.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different title.")
                    )
                }
            }
            .searchable(text: $query, prompt: "Search")
            .navigationTitle("Search")
        }
    }

    @EnvironmentObject private var sessionStore: SessionStore

    private func filter(items: [BaseItemDto]) -> [BaseItemDto] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        return items.filter { item in
            (item.name ?? "").localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private func homeStorePosterURL(for item: BaseItemDto) -> URL? {
        sessionStore.service?.posterURL(for: item)
    }
}

#Preview {
    TVSearchView(homeStore: HomeStore())
        .environmentObject(SessionStore())
        .environmentObject(SettingsStore())
}
