//
//  mathblockerApp.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import SwiftData

@MainActor
private func refreshShieldState() {
    ShieldManager.shared.refreshState()
    MonitoringManager.shared.refreshFromStorage()
}

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
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showSplash = false
                        }
                    }
                } else if hasCompletedOnboarding {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    OnboardingView()
                        .transition(.opacity)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { @MainActor in
                        refreshShieldState()
                    }
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }

}
