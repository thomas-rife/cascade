//
//  LoginView.swift
//  cascade
//
//  Created by Thomas Rife on 5/31/26.
//

import Foundation
import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        VStack(alignment:.leading, spacing: 10) {
            Text("Add a User")
                .padding(.horizontal)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            TextField("Username", text: $username)
                .autocorrectionDisabled()
                .autocapitalization(.none)
                .inputField()
                .padding()
                .disabled(isSigningIn)
            
            SecureField("Password", text: $password)
                .autocorrectionDisabled()
                .autocapitalization(.none)
                .inputField()
                .padding(.horizontal)
                .disabled(isSigningIn)
            
            Button {
                Task {
                    isSigningIn = true
                    errorMessage = nil
                    defer { isSigningIn = false }
                    do {
                        try await sessionStore.signIn(
                            username: username,
                            password: password
                        )
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if isSigningIn {
                        ProgressView()
                    }

                    Text(isSigningIn ? "Signing In..." : "Sign In")
                }
            }
            .primaryButton()
            .padding()
            .disabled(isSigningIn)


            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
    }
    
}

#Preview {
    LoginView()
        .environmentObject(SessionStore())
}
