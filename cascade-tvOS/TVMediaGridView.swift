//
//  TVMediaGridView.swift
//  cascade-tvOS
//
//  Created by Thomas Rife on 6/1/26.
//

import SwiftUI
import JellyfinAPI

enum TVCardLayout {
    static let spacing: CGFloat = 48
}

enum TVMediaKind {
    case movie
    case show
}

struct TVMediaGridView: View {
    let title: String
    let items: [BaseItemDto]
    let mediaKind: TVMediaKind

    @EnvironmentObject private var sessionStore: SessionStore

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 220), spacing: TVCardLayout.spacing)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .center, spacing: TVCardLayout.spacing) {
                ForEach(items, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 18) {
                        NavigationLink {
                            switch mediaKind {
                            case .movie:
                                TVMovieDetailView(
                                    movie: item,
                                    posterURL: sessionStore.service?.posterURL(for: item, maxHeight: 1200)
                                )
                            case .show:
                                TVShowDetailView(
                                    show: item,
                                    posterURL: sessionStore.service?.posterURL(for: item, maxHeight: 1200)
                                )
                            }
                        } label: {
                            TVPosterCard(
                                posterURL: sessionStore.service?.posterURL(for: item, maxHeight: 600),
                                systemImage: mediaKind == .movie ? "film" : "tv"
                            )
                        }
                        .buttonStyle(.card)
                        .accessibilityLabel(item.name ?? "Untitled")

                        if let year = item.productionYear {
                            Text(String(year))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 220, alignment: .leading)
                }
            }
            .padding(.horizontal, 84)
            .padding(.vertical, 56)
        }
        .navigationTitle(title)
    }
}

private struct TVPosterCard: View {
    let posterURL: URL?
    let systemImage: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.secondary.opacity(0.12))

            if let posterURL {
                CachedAsyncImage(url: posterURL) { phase in
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
        .frame(width: 220, height: 330)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.secondary.opacity(0.18))
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: 42))
                    .foregroundStyle(.secondary)
            }
    }
}
