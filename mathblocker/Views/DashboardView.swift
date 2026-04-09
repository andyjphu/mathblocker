//
//  DashboardView.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyStats.date, order: .reverse) private var allStats: [DailyStats]
    @Query private var settings: [UserSettings]

    private var budgetMinutes: Int { settings.first?.dailyTimeBudgetMinutes ?? 30 }

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
                VStack(spacing: 20) {
                    // Hero card
                    heroCard

                    // Stats grid
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 14) {
                        StatCard(
                            title: "solved today",
                            value: "\(todayStats?.questionsCorrect ?? 0)",
                            subtitle: "of \(todayStats?.questionsAttempted ?? 0) attempted",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )

                        StatCard(
                            title: "accuracy",
                            value: String(format: "%.0f%%", (todayStats?.accuracy ?? 0) * 100),
                            subtitle: "today",
                            icon: "target",
                            color: .orange
                        )

                        StatCard(
                            title: "time earned",
                            value: "\(todayStats?.minutesEarned ?? 0)m",
                            subtitle: "today",
                            icon: "clock.fill",
                            color: .accent
                        )

                        StatCard(
                            title: "streak",
                            value: "\(streak)",
                            subtitle: streak == 1 ? "day" : "days",
                            icon: "flame.fill",
                            color: .red
                        )
                    }
                    .padding(.horizontal)

                    // Recent history
                    if allStats.count > 1 {
                        recentHistory
                    }
                }
                .padding(.top, 8)
            }
            .scrollContentBackground(.hidden)
            .background { FrostedBackground() }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle("MathBlocker")
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("daily limit")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(budgetMinutes) min")
                        .font(Theme.titleFont(size: 34))
                }
                Spacer()
                CircularProgress(
                    progress: min(1.0, Double(todayStats?.minutesEarned ?? 0) / Double(budgetMinutes)),
                    label: "\(todayStats?.minutesEarned ?? 0)m"
                )
                .frame(width: 72, height: 72)
            }

            // Status pill
            HStack(spacing: 6) {
                let monitoring = MonitoringManager.shared.isMonitoring
                Circle()
                    .fill(monitoring ? .green : .orange)
                    .frame(width: 8, height: 8)
                Text(monitoring ? "monitoring on" : "monitoring off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(20)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Recent History

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
        .padding(.horizontal)
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [QuestionAttempt.self, DailyStats.self, UserSettings.self], inMemory: true)
}
