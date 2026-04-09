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
}
