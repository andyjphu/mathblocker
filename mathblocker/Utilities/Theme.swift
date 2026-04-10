//
//  Theme.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI

/// Central design tokens for the app. All shared colors, fonts,
/// and styling constants live here to keep the UI consistent.
enum Theme {
    /// Off-white card/surface background used across all tabs.
    static let cardBackground = Color(white: 0.98, opacity: 0.85)

    /// Instrument Serif for titles and headers.
    static func titleFont(size: CGFloat) -> Font {
        .custom("InstrumentSerif-Regular", size: size)
    }

    /// Instrument Serif italic variant.
    static func titleFontItalic(size: CGFloat) -> Font {
        .custom("InstrumentSerif-Italic", size: size)
    }

    /// Shared card shadow — one place to tune intensity.
    static let cardShadowColor = Color.black.opacity(0.08)
    static let cardShadowRadius: CGFloat = 6
    static let cardShadowY: CGFloat = 2
}

/// Drop shadow applied to all card-like elements above the background.
struct CardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(
                color: Theme.cardShadowColor,
                radius: Theme.cardShadowRadius,
                x: 0,
                y: Theme.cardShadowY
            )
    }
}

extension View {
    func cardShadow() -> some View {
        modifier(CardShadow())
    }
}
