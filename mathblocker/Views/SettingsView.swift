//
//  SettingsView.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import SwiftData
import FamilyControls

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]

    private var currentSettings: UserSettings {
        if let existing = settings.first { return existing }
        let new = UserSettings()
        modelContext.insert(new)
        return new
    }

    @State private var authManager = AuthorizationManager.shared
    @State private var selectionManager = SelectionManager.shared
    @State private var monitoringManager = MonitoringManager.shared
    @State private var showingAppPicker = false
    @State private var showingResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // Screen Time section
                screenTimeSection
                    .listRowBackground(Theme.cardBackground)

                // Time settings
                timeSection
                    .listRowBackground(Theme.cardBackground)

                // Difficulty
                difficultySection
                    .listRowBackground(Theme.cardBackground)

                // Data
                dataSection
                    .listRowBackground(Theme.cardBackground)

                // Debug
                DebugSection()
                    .listRowBackground(Theme.cardBackground)
            }
            .fontDesign(.serif)
            .scrollContentBackground(.hidden)
            .background { FrostedBackground(image: "olive-mountain") }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle("Settings")
        }
        .confirmationDialog("Reset all stats?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { resetStats() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("this wipes all your stats and history. no undo.")
        }
    }

    // MARK: - Screen Time

    private var screenTimeSection: some View {
        Section {
            // Authorization status
            HStack {
                Label("Screen Time Access", systemImage: "hourglass")
                Spacer()
                if authManager.isAuthorized {
                    Label("Authorized", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                } else {
                    Button("Authorize") {
                        Task { await authManager.requestAuthorization() }
                    }
                    .font(.subheadline)
                }
            }

            if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // App picker
            if authManager.isAuthorized {
                Button {
                    showingAppPicker = true
                } label: {
                    HStack {
                        Label("Blocked Apps", systemImage: "apps.iphone")
                        Spacer()
                        Text(selectionManager.hasSelection ? "Configured" : "Not set")
                            .foregroundStyle(selectionManager.hasSelection ? .green : .secondary)
                    }
                }
                .familyActivityPicker(
                    isPresented: $showingAppPicker,
                    selection: $selectionManager.selection
                )

                // Monitoring toggle
                if selectionManager.hasSelection {
                    Toggle(isOn: Binding(
                        get: { monitoringManager.isMonitoring },
                        set: { newValue in
                            if newValue {
                                monitoringManager.startMonitoring(
                                    budgetMinutes: currentSettings.dailyTimeBudgetMinutes
                                )
                                currentSettings.isMonitoringEnabled = true
                            } else {
                                monitoringManager.stopMonitoring()
                                ShieldManager.shared.removeShields()
                                currentSettings.isMonitoringEnabled = false
                            }
                        }
                    )) {
                        Label("Monitoring", systemImage: "shield.checkered")
                    }
                }
            }
        } header: {
            Text("App Blocking")
        } footer: {
            if !authManager.isAuthorized {
                Text("authorize Screen Time to get started")
            } else if !selectionManager.hasSelection {
                Text("pick which apps get blocked when you go over your limit")
            } else if !monitoringManager.isMonitoring {
                Text("turn on monitoring to start tracking and blocking")
            }
        }
    }

    // MARK: - Time

    private var timeSection: some View {
        Section {
            Stepper(value: Bindable(currentSettings).dailyTimeBudgetMinutes, in: 0...120, step: 5) {
                HStack {
                    Label("Daily Budget", systemImage: "clock")
                    Spacer()
                    Text("\(currentSettings.dailyTimeBudgetMinutes) min")
                        .foregroundStyle(.secondary)
                }
            }

            Stepper(value: Bindable(currentSettings).minutesPerCorrectAnswer, in: 0...10) {
                HStack {
                    Label("Per Right Answer", systemImage: "plus.circle")
                    Spacer()
                    Text("\(currentSettings.minutesPerCorrectAnswer) min")
                        .foregroundStyle(.secondary)
                }
            }

            Stepper(value: Bindable(currentSettings).questionsPerSession, in: 3...10) {
                HStack {
                    Label("Questions/Session", systemImage: "number")
                    Spacer()
                    Text("\(currentSettings.questionsPerSession)")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Time")
        }
    }

    // MARK: - Difficulty

    private var difficultySection: some View {
        Section {
            Picker(selection: Bindable(currentSettings).difficultyLevel) {
                Text("Pre-Algebra").tag(1)
                Text("Elementary Algebra").tag(2)
                Text("Intermediate Algebra").tag(3)
                Text("Coordinate Geometry").tag(4)
                Text("Trigonometry").tag(5)
            } label: {
                Label("Difficulty", systemImage: "chart.bar.fill")
            }
        } header: {
            Text("Math")
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                showingResetConfirmation = true
            } label: {
                Label("Reset All Stats", systemImage: "trash")
            }
        } header: {
            Text("Data")
        }
    }


    private func resetStats() {
        try? modelContext.delete(model: QuestionAttempt.self)
        try? modelContext.delete(model: DailyStats.self)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [QuestionAttempt.self, DailyStats.self, UserSettings.self], inMemory: true)
}
