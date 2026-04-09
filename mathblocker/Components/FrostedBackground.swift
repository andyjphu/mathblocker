//
//  FrostedBackground.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI

/// Full-bleed background with a blurred image and subtle noise grain overlay.
/// Used behind all main screens to create a frosted glass aesthetic.
struct FrostedBackground: View {
    var image: String = "clean-salad"

    var body: some View {
        ZStack {
            Image(image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 4)
                .opacity(0.65)

            Color.white.opacity(0.10)

            NoiseTexture()
                .blendMode(.screen)
                .opacity(0.7)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

/// Tiled procedural noise texture. Generated once at a small tile size,
/// then repeated across the view for a film-grain effect.
struct NoiseTexture: View {
    var body: some View {
        GeometryReader { geo in
            let img = Self.generateNoise(size: CGSize(width: 200, height: 200))
            if let img {
                Image(uiImage: img)
                    .resizable(resizingMode: .tile)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.3)
            }
        }
        .drawingGroup()
    }

    static func generateNoise(size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let w = Int(size.width)
            let h = Int(size.height)
            for x in stride(from: 0, to: w, by: 2) {
                for y in stride(from: 0, to: h, by: 2) {
                    let brightness = CGFloat.random(in: 0...1)
                    UIColor(white: brightness, alpha: 0.056).setFill()
                    ctx.fill(CGRect(x: x, y: y, width: 2, height: 2))
                }
            }
        }
    }
}
