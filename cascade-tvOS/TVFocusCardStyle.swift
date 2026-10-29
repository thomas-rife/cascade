//
//  TVFocusCardStyle.swift
//  cascade-tvOS
//
//  Created by Thomas Rife on 6/1/26.
//

import SwiftUI

struct TVFocusCardModifier: ViewModifier {
    @Environment(\.isFocused) private var isFocused

    func body(content: Content) -> some View {
        content
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .offset(y: isFocused ? -8 : 0)
            .shadow(
                color: .black.opacity(isFocused ? 0.35 : 0),
                radius: isFocused ? 28 : 0,
                y: isFocused ? 18 : 0
            )
//            .overlay {
//                RoundedRectangle(cornerRadius: 24, style: .continuous)
//                    .stroke(.white.opacity(isFocused ? 0.9 : 0), lineWidth: 3)
//            }
            .animation(.easeOut(duration: 0.18), value: isFocused)
    }
}

extension View {
    func tvFocusCardStyle() -> some View {
        modifier(TVFocusCardModifier())
    }
}
