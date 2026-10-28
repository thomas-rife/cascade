//
//  TVLoginView.swift
//  cascade-tvOS
//
//  Created by Thomas Rife on 6/1/26.
//

import SwiftUI

struct TVLoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        ZStack {
            VStack(spacing: 36) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Add a User")
                        .font(.title)
                    
                    Text("Username")
                        .font(.title3)

                    TextField("Username", text: $username)
                        .font(.title3)
                        .disabled(isSigningIn)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                    
                    Text("Password")
                        .font(.title3)

                    SecureField("Password", text: $password)
                        .font(.title3)
                        .disabled(isSigningIn)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                    
                    Button {
                        Task {
                            isSigningIn = true
                            errorMessage = nil
                            defer { isSigningIn = false }

                            do {
                                try await sessionStore.signIn(username: username, password: password)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if isSigningIn {
                                ProgressView()
                            }

                            Text(isSigningIn ? "Signing In..." : "Sign In")
                                .font(.title3.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isSigningIn || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

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
    TVLoginView()
        .environmentObject(SessionStore())
}
