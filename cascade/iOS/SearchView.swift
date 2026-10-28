//
//  SearchView.swift
//  cascade
//
//  Created by Thomas Rife on 5/31/26.
//

import SwiftUI
import JellyfinAPI

struct SearchView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @ObservedObject var homeStore: HomeStore
    @State private var query = ""

    var body: some View {
        NavigationStack {
            Group {
                if homeStore.isLoading {
                    ProgressView("Loading library...")
                } else {
                    List {
                        if !trimmedQuery.isEmpty {
                            if !filteredMovies.isEmpty {
                                Section("Movies") {
                                    ForEach(Array(filteredMovies.enumerated()), id: \.offset) { _, movie in
                                        NavigationLink {
                                            MovieDetailView(
                                                movie: movie,
                                                posterURL: sessionStore.service?.posterURL(for: movie, maxHeight: 900)
                                            )
                                        } label: {
                                            SearchResultRow(
                                                title: movie.name ?? "Untitled",
                                                subtitle: movie.productionYear.map(String.init),
                                                posterURL: sessionStore.service?.posterURL(for: movie, maxHeight: 180),
                                                systemImage: "film"
                                            )
                                        }
                                    }
                                }
                            }

                            if !filteredShows.isEmpty {
                                Section("Shows") {
                                    ForEach(Array(filteredShows.enumerated()), id: \.offset) { _, show in
                                        NavigationLink {
                                            ShowDetailView(
                                                show: show,
                                                posterURL: sessionStore.service?.posterURL(for: show, maxHeight: 900)
                                            )
                                        } label: {
                                            SearchResultRow(
                                                title: show.name ?? "Untitled",
                                                subtitle: show.productionYear.map(String.init),
                                                posterURL: sessionStore.service?.posterURL(for: show, maxHeight: 180),
                                                systemImage: "tv"
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .overlay {
                        if !trimmedQuery.isEmpty && filteredMovies.isEmpty && filteredShows.isEmpty {
                            ContentUnavailableView(
                                "No Results",
                                systemImage: "magnifyingglass",
                                description: Text("Try a different title.")
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Search")
        }
        .searchable(text: $query, prompt: "Search movies and shows")
        .task(id: sessionStore.activeAccount?.userID) {
            await homeStore.load(using: sessionStore)
        }
    }

    private var filteredMovies: [BaseItemDto] {
        filter(items: homeStore.movies)
    }

    private var filteredShows: [BaseItemDto] {
        filter(items: homeStore.shows)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func filter(items: [BaseItemDto]) -> [BaseItemDto] {
        guard !trimmedQuery.isEmpty else { return [] }

        return items.filter { item in
            (item.name ?? "").localizedCaseInsensitiveContains(trimmedQuery)
        }
    }
}

#Preview {
    SearchView(homeStore: HomeStore())
        .environmentObject(SessionStore())
}

private struct SearchResultRow: View {
    let title: String
    let subtitle: String?
    let posterURL: URL?
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        Group {
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
        .frame(width: 40, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.secondary.opacity(0.18))
            .overlay {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
            }
    }
}
