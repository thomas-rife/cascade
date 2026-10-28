//
//  TVShowsView.swift
//  cascade-tvOS
//
//  Created by Thomas Rife on 6/1/26.
//

import SwiftUI

struct TVShowsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @ObservedObject var homeStore: HomeStore

    var body: some View {
        NavigationStack {
            Group {
                if homeStore.isLoading {
                    ProgressView("Loading Shows...")
                } else if let errorMessage = homeStore.errorMessage {
                    ContentUnavailableView("Unable to Load Shows", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else {
                    TVMediaGridView(
                        title: "",
                        items: homeStore.shows,
                        mediaKind: .show
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
    TVShowsView(homeStore: HomeStore())
        .environmentObject(SessionStore())
}
