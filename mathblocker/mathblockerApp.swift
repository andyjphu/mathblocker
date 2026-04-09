//
//  mathblockerApp.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import SwiftData

@main
struct mathblockerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            QuestionAttempt.self,
            DailyStats.self,
            UserSettings.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showUnlockChallenge = false
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showSplash = false
                    }
                }
            } else if hasCompletedOnboarding {
                MainTabView()
                    .sheet(isPresented: $showUnlockChallenge) {
                        UnlockChallengeView()
                    }
                    .onOpenURL { url in
                        if url.scheme == AppGroupConstants.urlScheme && url.host == "unlock" {
                            showUnlockChallenge = true
                        }
                    }
                    .onAppear {
                        checkForUnlockRequest()
                    }
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func checkForUnlockRequest() {
        guard let defaults = AppGroupConstants.sharedDefaults,
              let timestamp = defaults.object(forKey: "unlockRequestTimestamp") as? Double
        else { return }

        let requestDate = Date(timeIntervalSince1970: timestamp)
        if Date.now.timeIntervalSince(requestDate) < 30 {
            showUnlockChallenge = true
            defaults.removeObject(forKey: "unlockRequestTimestamp")
        }
    }
}
