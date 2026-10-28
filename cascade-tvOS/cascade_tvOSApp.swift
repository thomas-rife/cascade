//
//  cascade_tvOSApp.swift
//  cascade-tvOS
//
//  Created by Thomas Rife on 6/1/26.
//

import SwiftUI

@main
struct cascade_tvOSApp: App {
    @StateObject private var sessionStore = SessionStore(restoreOnLaunch: false)
    @StateObject private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionStore)
                .environmentObject(settingsStore)
        }
    }
}
