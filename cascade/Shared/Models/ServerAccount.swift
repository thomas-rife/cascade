//
//  ServerAccount.swift
//  cascade
//
//  Created by Thomas Rife on 5/30/26.
//

import Foundation

struct ServerAccount: Codable, Equatable, Hashable, Identifiable {
    var id: String {
        "\(serverURL.absoluteString)|\(userID)"
    }

    let serverURL: URL
    let userID: String
    let username: String
    let accessToken: String
}
