//
//  UnlockChallengeView.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import SwiftData

struct UnlockChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]

    private var currentSettings: UserSettings? { settings.first }

    var body: some View {
        NavigationStack {
            MathChallengeView(onUnlock: { minutesEarned in
                handleUnlock(minutes: minutesEarned)
            })
            .navigationTitle("Unlock Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Re-apply shields since they didn't complete
                        ShieldManager.shared.applyShields()
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func handleUnlock(minutes: Int) {
        // Remove shields
        ShieldManager.shared.removeShields()

        // Restart monitoring with the earned time as a new threshold
        // This re-shields after the earned minutes are used up
        MonitoringManager.shared.startMonitoring(budgetMinutes: minutes)

        dismiss()
    }
}

#Preview {
    UnlockChallengeView()
        .modelContainer(for: [QuestionAttempt.self, DailyStats.self, UserSettings.self], inMemory: true)
}
