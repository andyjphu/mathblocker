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
            Color(.systemBackground)
                .ignoresSafeArea()

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
                        .foregroundStyle(.blue)
                }

                Text("MathBlocker")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Spacer()

                // Loading bar
                VStack(spacing: 10) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
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

        // Load the question bank
        let bank = QuestionBank.shared
        await bank.load()

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
