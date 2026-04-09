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

    init() {
        // Preload question bank in background so Practice tab is instant
        Task.detached(priority: .utility) {
            await QuestionBank.shared.load()
        }
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
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
            } else {
                OnboardingView()
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func checkForUnlockRequest() {
        guard let defaults = AppGroupConstants.sharedDefaults,
              let timestamp = defaults.object(forKey: "unlockRequestTimestamp") as? Double
        else { return }

        let requestDate = Date(timeIntervalSince1970: timestamp)
        // Only honor requests from the last 30 seconds
        if Date.now.timeIntervalSince(requestDate) < 30 {
            showUnlockChallenge = true
            defaults.removeObject(forKey: "unlockRequestTimestamp")
        }
    }
}
