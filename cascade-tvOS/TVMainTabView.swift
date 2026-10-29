//
//  TVMainTabView.swift
//  cascade-tvOS
//
//  Created by Thomas Rife on 6/1/26.
//

import SwiftUI

struct TVMainTabView: View {
    @StateObject private var homeStore = HomeStore()

    var body: some View {
        TabView {
            TVHomeView(homeStore: homeStore)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            TVMoviesView(homeStore: homeStore)
                .tabItem {
                    Label("Movies", systemImage: "film")
                }

            TVShowsView(homeStore: homeStore)
                .tabItem {
                    Label("Shows", systemImage: "tv")
                }
            
//            TVShowsView(homeStore: homeStore)
//                .tabItem {
//                    Label("Favorites", systemImage: "star")
//                }
            
            TVSearchView(homeStore: homeStore)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            
            TVSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
            

        }
    }
}

#Preview {
    TVMainTabView()
        .environmentObject(SessionStore())
        .environmentObject(SettingsStore())
}

