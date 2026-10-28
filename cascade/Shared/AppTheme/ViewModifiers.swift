//
//  ViewModifiers.swift
//  cascade
//
//  Created by Thomas Rife on 5/31/26.
//

import Foundation
import SwiftUI

struct PrimaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .fontWeight(AppTheme.buttonWeight)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(AppTheme.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

struct SecondaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .fontWeight(AppTheme.buttonWeight)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(AppTheme.secondary)
            .foregroundStyle(AppTheme.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

struct DangerButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .fontWeight(AppTheme.buttonWeight)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(.red)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

struct InputFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
//            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(AppTheme.divider, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

struct CardSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
//            .overlay(
//                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
//                    .stroke(.black.opacity(0.2), lineWidth: 0.8)
//            )
            .foregroundStyle(AppTheme.textPrimary)
    }
}

struct PlayButton: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .fontWeight(AppTheme.buttonWeight)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(colorScheme == .dark ? .white : .black)
            .foregroundStyle(colorScheme == .dark ? .black : .white)
            .clipShape(Capsule())
    }
}



extension View {
    func primaryButton() -> some View {
        modifier(PrimaryButtonStyle())
    }
    
    func secondaryButton() -> some View {
        modifier(SecondaryButtonStyle())
    }

    func dangerButton() -> some View {
        modifier(DangerButtonStyle())
    }
    
    func inputField() -> some View {
        modifier(InputFieldStyle())
    }
    
    func cardSurface() -> some View {
        modifier(CardSurfaceModifier())
    }
    
    func playButton() -> some View {
        modifier(PlayButton())
    }
}
