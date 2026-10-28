//
//  MainTabView.swift
//  cascade
//
//  Created by Thomas Rife on 5/31/26.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var homeStore = HomeStore()

    var body: some View {
        TabView {
            HomeView(homeStore: homeStore)
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            MoviesView(homeStore: homeStore)
                .tabItem {
                    Label("Movies", systemImage: "film.stack")
                }

            ShowsView(homeStore: homeStore)
                .tabItem {
                    Label("Shows", systemImage: "tv")
                }

            SearchView(homeStore: homeStore)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(SessionStore())
        .environmentObject(SettingsStore())
}
