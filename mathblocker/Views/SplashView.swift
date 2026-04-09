//
//  SplashView.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI

struct SplashView: View {
    @State private var progress: Double = 0
    @State private var isFinished = false
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            FrostedBackground()

            VStack(spacing: 28) {
                Spacer()

                // App icon
                if let icon = UIImage(named: "AppIcon") {
                    Image(uiImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                } else {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 72))
                        .foregroundStyle(.accent)
                }

                Text("MathBlocker")
                    .font(.system(size: 32, weight: .bold, design: .serif))

                Spacer()

                // Loading bar
                VStack(spacing: 10) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(.accent)
                        .frame(width: 200)

                    Text(progress < 1.0 ? "loading..." : "ready")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 60)
            }
        }
        .task {
            await loadWithProgress()
        }
    }

    private func loadWithProgress() async {
        // Animate to 30% quickly (file read)
        withAnimation(.easeOut(duration: 0.3)) {
            progress = 0.3
        }

        // Load question bank and rationales
        let bank = QuestionBank.shared
        await bank.load()
        await RationaleBank.shared.load()

        // Animate to 100%
        withAnimation(.easeOut(duration: 0.3)) {
            progress = 1.0
        }

        // Brief pause to show "Ready!"
        try? await Task.sleep(for: .milliseconds(400))

        withAnimation(.easeInOut(duration: 0.3)) {
            isFinished = true
        }

        onComplete()
    }
}

#Preview {
    SplashView(onComplete: {})
}
