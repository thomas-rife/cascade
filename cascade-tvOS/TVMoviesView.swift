//
//  TVMoviesView.swift
//  cascade-tvOS
//
//  Created by Thomas Rife on 6/1/26.
//

import SwiftUI

struct TVMoviesView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @ObservedObject var homeStore: HomeStore

    var body: some View {
        NavigationStack {
            Group {
                if homeStore.isLoading {
                    ProgressView("Loading Movies...")
                } else if let errorMessage = homeStore.errorMessage {
                    ContentUnavailableView("Unable to Load Movies", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else {
                    TVMediaGridView(
                        title: "",
                        items: homeStore.movies,
                        mediaKind: .movie
                    )
                }
            }
        }
        .task(id: sessionStore.activeAccount?.id) {
            homeStore.reset()
            await homeStore.load(using: sessionStore)
        }
    }
}

#Preview {
    TVMoviesView(homeStore: HomeStore())
        .environmentObject(SessionStore())
}
