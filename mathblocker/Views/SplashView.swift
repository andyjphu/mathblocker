//
//  SplashView.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import LaTeXSwiftUI
import UserNotifications

struct SplashView: View {
    @State private var progress: Double = 0
    @State private var isFinished = false
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            FrostedBackground()

            // Pre-warm MathJax engine so first answer doesn't freeze
            LaTeX("$x$")
                .frame(width: 1, height: 1)
                .opacity(0.01)

            VStack(spacing: 28) {
                Spacer()

                // Logo
                Image("logo4xbg")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)

                Text("MathBlocker")
                    .font(Theme.titleFont(size: 32))

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
        .fontDesign(.serif)
        .task {
            await loadWithProgress()
        }
    }

    private func loadWithProgress() async {
        // Pre-warm haptic engine
        Haptics.prepare()

        // Request notification permission for threshold warnings
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])

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
