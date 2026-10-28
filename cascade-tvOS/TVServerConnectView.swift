//
//  TVServerConnectView.swift
//  cascade
//
//  Created by Thomas Rife on 6/1/26.
//

import SwiftUI

struct TVServerConnectView: View {
    @State private var serverURL = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?

    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        ZStack {

            VStack(spacing: 36) {
                VStack(alignment: .leading, spacing: 12) {


//                    Text("Enter your server address to start browsing movies and shows on Apple TV.")
//                        .font(.title3)
//                        .foregroundStyle(.secondary)
//                        .multilineTextAlignment(.center)
//                        .frame(maxWidth: 760)
                }

                VStack(alignment: .leading, spacing: 24) {
                    Text("Connect to Jellyfin")
                        .font(.title)
                        
                    
                    Text("Server Address")
                        .font(.title3.weight(.semibold))

                    TextField("Enter an address", text: $serverURL)
                        .font(.title3)
                        .disabled(isConnecting)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    
                    Button {
                        Task {
                            let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)

                            guard let serverURL = URL(string: trimmed) else {
                                errorMessage = "Enter a valid server URL."
                                return
                            }

                            isConnecting = true
                            errorMessage = nil
                            defer { isConnecting = false }

                            do {
                                let device = sessionStore.deviceDetails()
                                try await sessionStore.connect(
                                    to: serverURL,
                                    deviceName: device.deviceName,
                                    deviceID: device.deviceID,
                                    appVersion: device.appVersion
                                )
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if isConnecting {
                                ProgressView()
                            }

                            Text(isConnecting ? "Connecting..." : "Connect")
                                .font(.title3.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isConnecting)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .frame(width: 720, alignment: .leading)
                .padding(36)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .padding(.horizontal, 40)
        }
    }
}

#Preview {
    TVServerConnectView()
        .environmentObject(SessionStore())
}
