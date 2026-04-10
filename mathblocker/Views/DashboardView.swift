//
//  DashboardView.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import SwiftData
import DeviceActivity

/// Dashboard answering one question: "how much time do I have,
/// and how do I get more?"
struct DashboardView: View {
    @Query(sort: \DailyStats.date, order: .reverse) private var allStats: [DailyStats]
    @Query private var settings: [UserSettings]

    var goToPractice: () -> Void

    private var budgetMinutes: Int { settings.first?.dailyTimeBudgetMinutes ?? 30 }
    private var perCorrect: Int { settings.first?.minutesPerCorrectAnswer ?? 2 }

    private var todayStats: DailyStats? {
        let today = Calendar.current.startOfDay(for: .now)
        return allStats.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private var streak: Int {
        var count = 0
        let calendar = Calendar.current
        var checkDate = calendar.startOfDay(for: .now)

        for stats in allStats {
            if calendar.isDate(stats.date, inSameDayAs: checkDate) && stats.questionsCorrect > 0 {
                count += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else if stats.date < checkDate {
                break
            }
        }
        return count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero: time earned
                    heroSection

                    // CTA
                    practiceButton

                    // Secondary stats
                    statsRow

                    // Screen time usage (rendered by report extension)
                    if MonitoringManager.shared.isMonitoring {
                        usageReport
                    }

                    // Monitoring status
                    monitoringPill

                    // Weekly history
                    if allStats.count > 1 {
                        recentHistory
                    }
                }
                .padding(.top, 12)
            }
            .fontDesign(.serif)
            .scrollContentBackground(.hidden)
            .background { FrostedBackground() }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Dashboard")
                        .font(Theme.titleFont(size: 20))
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        let earned = todayStats?.minutesEarned ?? 0
        let available = budgetMinutes + earned
        let shieldsUp = ShieldManager.shared.shieldsAreActive

        return VStack(spacing: 16) {
            // Available time — the one number that matters
            VStack(spacing: 4) {
                Text("\(available)")
                    .font(Theme.titleFont(size: 64))
                    .foregroundStyle(shieldsUp ? .orange : .primary)

                Text("minutes available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Breakdown
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("\(budgetMinutes)")
                        .font(Theme.titleFont(size: 22))
                    Text("budget")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 1, height: 28)

                VStack(spacing: 2) {
                    Text("+\(earned)")
                        .font(Theme.titleFont(size: 22))
                        .foregroundStyle(.accent)
                    Text("earned")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            // Status line
            if shieldsUp {
                Text("apps are blocked — solve problems to earn time")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 24)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .cardShadow()
        .padding(.horizontal)
    }

    // MARK: - CTA

    private var practiceButton: some View {
        Button {
            goToPractice()
        } label: {
            HStack {
                Text("solve problems")
                    .fontWeight(.semibold)
                Image(systemName: "arrow.right")
            }
            .font(.body)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .cardShadow()
        .padding(.horizontal)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            miniStat(
                value: "\(todayStats?.questionsCorrect ?? 0)/\(todayStats?.questionsAttempted ?? 0)",
                label: "solved",
                icon: "checkmark.circle.fill",
                color: .green
            )

            miniStat(
                value: String(format: "%.0f%%", (todayStats?.accuracy ?? 0) * 100),
                label: "accuracy",
                icon: "target",
                color: .orange
            )

            miniStat(
                value: "\(streak)",
                label: streak == 1 ? "day" : "days",
                icon: "flame.fill",
                color: .red
            )
        }
        .padding(.horizontal)
    }

    private func miniStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.caption)

            Text(value)
                .font(Theme.titleFont(size: 20))

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .cardShadow()
    }

    // MARK: - Usage Report

    private var usageReport: some View {
        DeviceActivityReport(.init(rawValue: "totalUsage"))
            .frame(height: 60)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .cardShadow()
            .padding(.horizontal)
    }

    // MARK: - Monitoring

    private var monitoringPill: some View {
        HStack(spacing: 6) {
            let monitoring = MonitoringManager.shared.isMonitoring
            Circle()
                .fill(monitoring ? .green : .orange)
                .frame(width: 8, height: 8)
            Text(monitoring ? "monitoring on" : "monitoring off")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - History

    private var recentHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("this week")
                .font(.headline)
                .padding(.horizontal)

            ForEach(allStats.prefix(7)) { stats in
                HStack {
                    Text(stats.date, format: .dateTime.weekday(.wide))
                        .font(.subheadline)
                    Spacer()
                    Text("\(stats.questionsCorrect)/\(stats.questionsAttempted)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ProgressView(value: stats.accuracy)
                        .frame(width: 60)
                        .tint(stats.accuracy >= 0.8 ? .green : stats.accuracy >= 0.5 ? .orange : .red)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .cardShadow()
        .padding(.horizontal)
    }
}

#Preview {
    DashboardView(goToPractice: {})
        .modelContainer(for: [QuestionAttempt.self, DailyStats.self, UserSettings.self], inMemory: true)
}
