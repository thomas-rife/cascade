//
//  TVMediaGridView.swift
//  cascade-tvOS
//
//  Created by Thomas Rife on 6/1/26.
//

import SwiftUI
import JellyfinAPI

enum TVMediaKind {
    case movie
    case show
}

struct TVMediaGridView: View {
    let title: String
    let items: [BaseItemDto]
    let mediaKind: TVMediaKind

    @EnvironmentObject private var sessionStore: SessionStore

    private let columns = Array(repeating: GridItem(.fixed(220), spacing: 40), count: 7)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .center, spacing: 36) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
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
//                            title: item.name ?? "Untitled",
                            subtitle: item.productionYear.map(String.init),
                            posterURL: sessionStore.service?.posterURL(for: item, maxHeight: 600),
                            systemImage: mediaKind == .movie ? "film" : "tv"
                        )
                    }
                    .buttonStyle(.card)
//                    .focusEffectDisabled()
                }
            }
            .padding(.horizontal, 84)
            .padding(.vertical, 56)
        }
        .navigationTitle(title)
    }
}

private struct TVPosterCard: View {
//    let title: String
    let subtitle: String?
    let posterURL: URL?
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            poster

            VStack(alignment: .leading, spacing: 4) {
//                Text(title)
//                    .font(.headline)
//                    .lineLimit(2)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 220, alignment: .leading)
    }

    private var poster: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.secondary.opacity(0.12))

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
//        .frame(width: 220, height: 330)
//        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
//        .focusEffectDisabled()
//        .tvFocusCardStyle()
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
