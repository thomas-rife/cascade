//
//  TVSettingsView.swift
//  cascade
//
//  Created by Thomas Rife on 6/1/26.
//

import SwiftUI

struct TVSettingsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Playback Quality") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(settingsStore.playbackQuality.title)
                            .font(.headline)

                        Picker(
                            "Quality",
                            selection: Binding(
                                get: { settingsStore.playbackQuality },
                                set: { settingsStore.sliderValue = $0.sliderValue }
                            )
                        ) {
                            ForEach(PlaybackQualityPreset.allCases) { preset in
                                Text(preset.title)
                                    .tag(preset)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Servers") {
                    let servers = sessionStore.availableServers()

                    if servers.isEmpty {
                        Text("No saved servers yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(servers, id: \.absoluteString) { serverURL in
                            Button {
                                sessionStore.switchServer(to: serverURL)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(serverLabel(for: serverURL))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    if serverURL == sessionStore.activeServer {
                                        Text("Current")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .tint(.primary)
                        }
                    }
                }

                Section("Users") {
                    let accounts = sessionStore.accountsForCurrentServer()

                    if accounts.isEmpty {
                        Text("No saved users for this server yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(accounts) { account in
                            Button {
                                sessionStore.switchAccount(to: account)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(account.username)
                                    Spacer()
                                    if account.id == sessionStore.activeAccount?.id {
                                        Text("Current")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .tint(.primary)
                        }
                    }

                    Button("Sign In Another User") {
                        sessionStore.prepareForNewUserSignIn()
                        dismiss()
                    }
                }

                Section("Session") {
                    Button("Sign Out", role: .destructive) {
                        Task {
                            do {
                                try await sessionStore.signOut()
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }

                    Button("Disconnect Server", role: .destructive) {
                        sessionStore.disconnect()
                        dismiss()
                    }
                }

                if let errorMessage {
                    Section("Error") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func serverLabel(for url: URL) -> String {
        if let host = url.host(), !host.isEmpty {
            if let port = url.port {
                return "\(host):\(port)"
            }
            return host
        }

        return url.absoluteString
    }
}

#Preview {
    TVSettingsView()
        .environmentObject(SettingsStore())
        .environmentObject(SessionStore())
}
