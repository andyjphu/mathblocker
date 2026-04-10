//
//  MathText.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import LaTeXSwiftUI

/// Renders text that may contain LaTeX math expressions.
/// Text wrapped in `$...$` is rendered as math; everything else
/// uses plain Text with zero LaTeX overhead.
struct MathText: View {
    let text: String

    var body: some View {
        if text.contains("$") {
            LaTeX(text)
                .fontDesign(.serif)
        } else {
            Text(text)
        }
    }
}
