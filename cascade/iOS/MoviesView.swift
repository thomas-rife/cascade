//
//  MoviesView.swift
//  cascade
//
//  Created by Thomas Rife on 5/31/26.
//

import SwiftUI
import JellyfinAPI

private enum MovieOrganization: String, CaseIterable, Identifiable {
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

struct MoviesView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @ObservedObject var homeStore: HomeStore

    @State private var organization: MovieOrganization = .recentlyAdded

    private let columns = PosterStyle.gridColumns

    var body: some View {
        NavigationStack {
            Group {
                if homeStore.isLoading {
                    ProgressView("Loading movies...")
                } else {
                    ScrollViewReader { proxy in
                        ZStack(alignment: .trailing) {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 24) {
                                    if groupedMovies.isEmpty {
                                        Text("No movies found.")
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal)
                                    } else {
                                        ForEach(Array(groupedMovies.enumerated()), id: \.offset) { _, group in
                                            VStack(alignment: .leading, spacing: 12) {
                                                if !group.title.isEmpty {
                                                    Text(group.title)
                                                        .font(.title3.weight(.semibold))
                                                        .padding(.horizontal)
                                                }

                                                LazyVGrid(columns: columns, spacing: PosterStyle.verticalSpacing) {
                                                    ForEach(Array(group.movies.enumerated()), id: \.offset) { _, movie in
                                                        MoviePosterCard(
                                                            movie: movie,
                                                            posterURL: sessionStore.service?.posterURL(for: movie),
                                                            layout: .grid
                                                        )
                                                    }
                                                }
                                                .padding(.horizontal)
                                            }
                                            .id(group.title)
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
                            if organization == .alphabetical, !alphabeticalIndexTitles.isEmpty {
                                VStack(spacing: 4) {
                                    ForEach(alphabeticalIndexTitles, id: \.self) { title in
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                proxy.scrollTo(title, anchor: .top)
                                            }
                                        } label: {
                                            Text(title)
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                                .frame(width: 18)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(.trailing, 8)
                            }
                        }
                    }
                    .refreshable {
                        homeStore.reset()
                        await homeStore.load(using: sessionStore)
                    }
                }
            }
            .navigationTitle("Movies")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(MovieOrganization.allCases) { option in
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

    private var groupedMovies: [(title: String, movies: [BaseItemDto])] {
        switch organization {
        case .recentlyAdded:
            let sortedMovies = homeStore.movies.sorted { lhs, rhs in
                sortDate(for: lhs) > sortDate(for: rhs)
            }

            return [("", sortedMovies)]

        case .alphabetical:
            let groups = Dictionary(grouping: homeStore.movies) { movie in
                let first = movie.name?.trimmingCharacters(in: .whitespacesAndNewlines).first
                return first.map { String($0).uppercased() } ?? "#"
            }

            return groups
                .map { (title: $0.key, movies: sortMovies($0.value)) }
                .sorted { $0.title < $1.title }

        case .releaseYear:
            let groups = Dictionary(grouping: homeStore.movies) { movie in
                movie.productionYear.map(String.init) ?? "Unknown Year"
            }

            return groups
                .map { (title: $0.key, movies: sortMovies($0.value)) }
                .sorted { lhs, rhs in
                    if lhs.title == "Unknown Year" { return false }
                    if rhs.title == "Unknown Year" { return true }
                    return lhs.title > rhs.title
                }
        }
    }

    private func sortMovies(_ movies: [BaseItemDto]) -> [BaseItemDto] {
        movies.sorted {
            ($0.name ?? "Untitled").localizedCaseInsensitiveCompare($1.name ?? "Untitled") == .orderedAscending
        }
    }

    private func sortDate(for item: BaseItemDto) -> Date {
        item.dateLastMediaAdded ?? item.dateCreated ?? .distantPast
    }

    private var alphabeticalIndexTitles: [String] {
        groupedMovies.map(\.title).filter { !$0.isEmpty }
    }
}

#Preview {
    MoviesView(homeStore: HomeStore())
        .environmentObject(SessionStore())
}
