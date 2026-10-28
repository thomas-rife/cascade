//
//  cascadeApp.swift
//  cascade
//
//  Created by Thomas Rife on 5/30/26.
//

import SwiftUI

@main
struct cascadeApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppOrientationDelegate.self) private var appDelegate
    #endif
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionStore)
                .environmentObject(settingsStore)
        }
    }
}
