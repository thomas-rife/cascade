//
//  AppTheme.swift
//  cascade
//
//  Created by Thomas Rife on 5/31/26.
//

import Foundation
import SwiftUI

struct AppTheme {
    static let accent = Color.accentColor
    static let secondary = Color.secondary
    static let warning = Color.orange

    static let background = Color(uiColor: .systemBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let divider = Color(uiColor: .separator)
    static let textLabel = Color.secondary

    static let cornerRadius: CGFloat = 12
    static let cardCornerRadius: CGFloat = 16
    
    static let bodyWeight: Font.Weight = .regular
    static let headingWeight: Font.Weight = .bold
    static let buttonWeight: Font.Weight = .semibold
}


enum Theme: CaseIterable {
    case light
    case dark
    case system
    
    var color: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
    
    var name: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .system: return "System"
        }
    }
}


