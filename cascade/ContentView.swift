//
//  ContentView.swift
//  cascade
//
//  Created by Thomas Rife on 5/30/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        Group {
            if sessionStore.activeServer == nil {
                ServerConnectView()
            } else if !sessionStore.isAuthenticated {
                LoginView()
            } else {
                MainTabView()
            }
        }
        .onAppear {
            #if os(iOS)
            AppOrientation.lock(.portrait)
            #endif
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SessionStore())
        .environmentObject(SettingsStore())
}
