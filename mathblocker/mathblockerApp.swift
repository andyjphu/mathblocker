//
//  mathblockerApp.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import SwiftData

@MainActor
private func reconcileShields(modelContext: ModelContext) {
    let descriptor = FetchDescriptor<UserSettings>()
    guard let settings = try? modelContext.fetch(descriptor).first else { return }

    let today = Calendar.current.startOfDay(for: .now)
    let statsDescriptor = FetchDescriptor<DailyStats>(
        predicate: #Predicate { $0.date == today }
    )
    let earned = (try? modelContext.fetch(statsDescriptor).first?.minutesEarned) ?? 0
    let used = MonitoringManager.shared.usedMinutesToday
    let totalAllowed = settings.dailyTimeBudgetMinutes + earned

    ShieldManager.shared.refreshState()

    // If user has remaining time but shields are up, clear them
    if used < totalAllowed && ShieldManager.shared.shieldsAreActive {
        ShieldManager.shared.removeShields()
        if MonitoringManager.shared.isMonitoring {
            MonitoringManager.shared.startMonitoring(budgetMinutes: totalAllowed)
        }
    }
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
                        reconcileShields(modelContext: sharedModelContainer.mainContext)
                    }
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }

}
