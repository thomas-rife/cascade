//
//  ContentView.swift
//  cascade-tvOS
//
//  Created by Thomas Rife on 6/1/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        Group {
            if sessionStore.activeServer == nil {
                TVServerConnectView()
            } else if !sessionStore.isAuthenticated {
                TVLoginView()
            } else {
                TVMainTabView()
            }
        }
        .task {
            sessionStore.restorePersistedSessionIfNeeded()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SessionStore())
        .environmentObject(SettingsStore())
}
