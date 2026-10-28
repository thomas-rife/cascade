//
//  ServerConnectView.swift
//  cascade
//
//  Created by Thomas Rife on 5/31/26.
//

import Foundation
import SwiftUI

struct ServerConnectView: View {
    @State private var serverURL: String = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Enter Server URL")
                .padding(.horizontal)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            TextField("Server URL", text: $serverURL)
                .autocorrectionDisabled()
                .autocapitalization(.none)
                .keyboardType(.URL)
                .inputField()
                .padding(.horizontal)
                .disabled(isConnecting)
            
            Button {
                Task {
                    let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    guard let serverURL = URL(string: trimmed) else {
                        return
                    }
                    isConnecting = true
                    errorMessage = nil
                    defer { isConnecting = false }
                    do {
                        let device = sessionStore.deviceDetails()
                        try await sessionStore.connect(to: serverURL, deviceName: device.deviceName, deviceID: device.deviceID, appVersion: device.appVersion)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if isConnecting {
                        ProgressView()
                    }

                    Text(isConnecting ? "Connecting..." : "Connect")
                }
            }
            .primaryButton()
            .padding(.horizontal)
            .disabled(isConnecting)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }

    }
}


#Preview {
    ServerConnectView()
        .environmentObject(SessionStore())
}
