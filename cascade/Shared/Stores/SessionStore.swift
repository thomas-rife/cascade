//
//  SessionStore.swift
//  cascade
//
//  Created by Thomas Rife on 5/30/26.
//

import Foundation
import Combine
import JellyfinAPI
import SwiftUI
import Network
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class SessionStore: ObservableObject {
    enum SessionStoreError: Error {
        case missingService
        case invalidAuthenticationResponse
    }

    private enum Keys {
        static let savedAccounts = "savedAccounts"
        static let lastActiveAccountID = "lastActiveAccountID"
    }

    @Published var activeAccount: ServerAccount?
    @Published var activeServer: URL?
    @Published var service: JellyfinService?
    @Published private(set) var savedAccounts: [ServerAccount] = []

    init(restoreOnLaunch: Bool = true) {
        loadSavedAccounts()

        if restoreOnLaunch {
            restoreLastSession()
        }
    }
    
    var isAuthenticated: Bool {
        activeAccount != nil
    }
    
    func connect(to serverURL: URL, deviceName: String, deviceID: String, appVersion: String) async throws {
        let normalizedServerURL = canonicalServerURL(serverURL)
        let service = JellyfinService(
            serverURL: normalizedServerURL,
            deviceName: deviceName,
            deviceID: deviceID,
            appVersion: appVersion
        )
        
        _ = try await service.validateServer()
        
        self.service = service
        self.activeServer = normalizedServerURL
    }
    
    func signIn(username: String, password: String) async throws {
        guard let service else {
            throw SessionStoreError.missingService
        }

        let auth = try await service.signIn(username: username, password: password)
        guard
            let serverURL = activeServer,
            let userID = auth.user?.id,
            let username = auth.user?.name,
            let accessToken = auth.accessToken
        else {
            throw SessionStoreError.invalidAuthenticationResponse
        }

        let account = ServerAccount(
            serverURL: canonicalServerURL(serverURL),
            userID: userID,
            username: username,
            accessToken: accessToken
        )

        activeAccount = account
        remember(account)
        persistLastActiveAccountID(account.id)
    }
    
    func signOut() async throws {
        guard let service else { return }
        let signedOutAccount = activeAccount
        
        try await service.signOut()
        activeAccount = nil

        if let signedOutAccount {
            savedAccounts.removeAll { $0.id == signedOutAccount.id }
            persistSavedAccounts()
            clearLastActiveAccountID()
        }
    }

    func accountsForCurrentServer() -> [ServerAccount] {
        guard let activeServer else { return [] }
        let normalizedActiveServer = canonicalServerURL(activeServer)
        return savedAccounts.filter { canonicalServerURL($0.serverURL) == normalizedActiveServer }
    }

    func availableServers() -> [URL] {
        var uniqueServersByKey: [String: URL] = [:]

        for serverURL in savedAccounts.map(\.serverURL) {
            let normalizedServerURL = canonicalServerURL(serverURL)
            uniqueServersByKey[normalizedServerURL.absoluteString] = normalizedServerURL
        }

        if let activeServer {
            let normalizedActiveServer = canonicalServerURL(activeServer)
            uniqueServersByKey[normalizedActiveServer.absoluteString] = normalizedActiveServer
        }

        return uniqueServersByKey.values.sorted {
            $0.absoluteString.localizedCaseInsensitiveCompare($1.absoluteString) == .orderedAscending
        }
    }

    func prepareForNewUserSignIn() {
        guard let activeServer else {
            activeAccount = nil
            service = nil
            clearLastActiveAccountID()
            return
        }

        let device = deviceDetails()

        service = JellyfinService(
            serverURL: activeServer,
            deviceName: device.deviceName,
            deviceID: device.deviceID,
            appVersion: device.appVersion
        )
        activeAccount = nil
        clearLastActiveAccountID()
    }

    func switchAccount(to account: ServerAccount) {
        restoreSession(from: account)
        activeAccount = account
        persistLastActiveAccountID(account.id)
    }

    func switchServer(to serverURL: URL) {
        let normalizedServerURL = canonicalServerURL(serverURL)

        if let account = savedAccounts.first(where: { canonicalServerURL($0.serverURL) == normalizedServerURL }) {
            restoreSession(from: account)
            activeAccount = account
            persistLastActiveAccountID(account.id)
        } else {
            let device = deviceDetails()
            service = JellyfinService(
                serverURL: normalizedServerURL,
                deviceName: device.deviceName,
                deviceID: device.deviceID,
                appVersion: device.appVersion
            )
            activeServer = normalizedServerURL
            activeAccount = nil
            clearLastActiveAccountID()
        }
    }
    
    func disconnect() {
        activeAccount = nil
        activeServer = nil
        service = nil
        clearLastActiveAccountID()
    }
    
    func deviceDetails() -> Device {
        let deviceName: String
        
        #if os(macOS)
        deviceName = ProcessInfo.processInfo.hostName

        #else
        deviceName = UIDevice.current.name
        #endif
        
        let deviceID: String

        if let saved = UserDefaults.standard.string(forKey: "deviceID") {
            deviceID = saved
        } else {
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: "deviceID")
            deviceID = newID
        }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

        let device = Device(
            deviceName: deviceName,
            deviceID: deviceID,
            appVersion: appVersion
        )
        
        return device
    }

    private func remember(_ account: ServerAccount) {
        let normalizedAccount = ServerAccount(
            serverURL: canonicalServerURL(account.serverURL),
            userID: account.userID,
            username: account.username,
            accessToken: account.accessToken
        )

        if let index = savedAccounts.firstIndex(where: { $0.id == normalizedAccount.id }) {
            savedAccounts[index] = normalizedAccount
        } else {
            savedAccounts.append(normalizedAccount)
        }

        deduplicateSavedAccounts()
        persistSavedAccounts()
    }

    private func loadSavedAccounts() {
        guard let data = UserDefaults.standard.data(forKey: Keys.savedAccounts) else { return }
        savedAccounts = (try? JSONDecoder().decode([ServerAccount].self, from: data)) ?? []
        deduplicateSavedAccounts()
        persistSavedAccounts()
    }

    private func persistSavedAccounts() {
        guard let data = try? JSONEncoder().encode(savedAccounts) else { return }
        UserDefaults.standard.set(data, forKey: Keys.savedAccounts)
    }

    private func restoreLastSession() {
        guard
            let accountID = UserDefaults.standard.string(forKey: Keys.lastActiveAccountID),
            let account = savedAccounts.first(where: { $0.id == accountID })
        else {
            return
        }

        restoreSession(from: account)
        activeAccount = account
    }

    func restorePersistedSessionIfNeeded() {
        guard activeAccount == nil, activeServer == nil, service == nil else { return }
        restoreLastSession()
    }

    private func restoreSession(from account: ServerAccount) {
        let device = deviceDetails()
        let normalizedServerURL = canonicalServerURL(account.serverURL)

        service = JellyfinService(
            serverURL: normalizedServerURL,
            deviceName: device.deviceName,
            deviceID: device.deviceID,
            appVersion: device.appVersion,
            accessToken: account.accessToken
        )
        activeServer = normalizedServerURL
    }

    private func persistLastActiveAccountID(_ accountID: String) {
        UserDefaults.standard.set(accountID, forKey: Keys.lastActiveAccountID)
    }

    private func clearLastActiveAccountID() {
        UserDefaults.standard.removeObject(forKey: Keys.lastActiveAccountID)
    }

    private func deduplicateSavedAccounts() {
        var uniqueAccountsByID: [String: ServerAccount] = [:]

        for account in savedAccounts {
            let normalizedAccount = ServerAccount(
                serverURL: canonicalServerURL(account.serverURL),
                userID: account.userID,
                username: account.username,
                accessToken: account.accessToken
            )
            uniqueAccountsByID[normalizedAccount.id] = normalizedAccount
        }

        savedAccounts = uniqueAccountsByID.values.sorted {
            if $0.serverURL.absoluteString == $1.serverURL.absoluteString {
                return $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending
            }

            return $0.serverURL.absoluteString.localizedCaseInsensitiveCompare($1.serverURL.absoluteString) == .orderedAscending
        }
    }

    private func canonicalServerURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        components.query = nil
        components.fragment = nil

        if !components.path.isEmpty, components.path != "/" {
            components.path = components.path.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
            if components.path.isEmpty {
                components.path = "/"
            }
        } else {
            components.path = ""
        }

        return components.url ?? url
    }
}
