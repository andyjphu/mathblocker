//
//  MainTabView.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MathChallengeView()
                .tabItem {
                    Label("Practice", systemImage: "brain.head.profile")
                }
                .tag(0)

            DashboardView(goToPractice: { selectedTab = 0 })
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(.accentColor)
        .fontDesign(.serif)
        .preferredColorScheme(.light)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [QuestionAttempt.self, DailyStats.self, UserSettings.self], inMemory: true)
}
