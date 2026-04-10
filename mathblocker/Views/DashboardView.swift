//
//  DashboardView.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import SwiftData
import DeviceActivity
import FamilyControls
import ManagedSettings
import Combine

/// Dashboard answering one question: "how much time do I have,
/// and how do I get more?"
struct DashboardView: View {
    @Query(sort: \DailyStats.date, order: .reverse) private var allStats: [DailyStats]
    @Query private var settings: [UserSettings]
    @State private var showReport = false

    /// `ManagedSettingsStore` doesn't notify cross-process when `dame` writes
    /// the shield, so we poll every 2s while the dashboard is visible. This
    /// catches the case where the user is on the dashboard when the threshold
    /// fires in the extension and shields go up.
    private let shieldRefreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

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

                    // Secondary stats
                    statsRow

                    // Screen time usage (rendered by report extension)
                    if MonitoringManager.shared.isMonitoring {
                        if showReport {
                            usageReport
                        } else {
                            ShimmerView()
                                .frame(height: 280)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .cardShadow()
                                .padding(.horizontal)
                        }
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
            .onAppear {
                // Catch any state the app missed while backgrounded / during startup
                ShieldManager.shared.refreshState()
                MonitoringManager.shared.refreshFromStorage()
                if !showReport {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showReport = true
                    }
                }
            }
            .onReceive(shieldRefreshTimer) { _ in
                // Cross-process sync: `dame` may have just applied shields.
                ShieldManager.shared.refreshState()
            }
            .scrollContentBackground(.hidden)
            .background { FrostedBackground() }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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
        let timerEnd = MonitoringManager.shared.earnedTimerEnd
        let monitoring = MonitoringManager.shared.isMonitoring
        let shieldsUp = ShieldManager.shared.shieldsAreActive && timerEnd == nil

        return VStack(spacing: 16) {
            // Primary display flips based on current state
            if let endDate = timerEnd {
                // State 2: active earned timer
                CountdownView(endDate: endDate)
            } else if shieldsUp {
                // State 3: budget exhausted or earned timer expired
                VStack(spacing: 4) {
                    Text("time's up")
                        .font(Theme.titleFont(size: 56))
                        .foregroundStyle(.orange)
                    Text("solve math to earn more time")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else if !monitoring {
                // State 4: not monitoring
                VStack(spacing: 4) {
                    Text("paused")
                        .font(Theme.titleFont(size: 64))
                        .foregroundStyle(.secondary)
                    Text("turn on blocking in settings to get started")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                // State 1: fresh budget, free access available
                VStack(spacing: 4) {
                    Text("\(budgetMinutes) min")
                        .font(Theme.titleFont(size: 64))
                        .foregroundStyle(.accent)
                    Text("of free app time today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Persistent mechanic explainer — always visible so the two-part
            // model (free budget, then earn-to-unlock) stays clear.
            Text("\(budgetMinutes) min of your real iPhone screen time daily. solve math to earn more when it runs out.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 24)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
        let selection = SelectionManager.shared.selection
        let filter = DeviceActivityFilter(
            segment: .hourly(
                during: DateInterval(
                    start: Calendar.current.startOfDay(for: .now),
                    end: .now
                )
            ),
            users: .all,
            devices: .init([.iPhone]),
            applications: selection.applicationTokens,
            categories: selection.categoryTokens
        )
        return VStack(spacing: 8) {
            DeviceActivityReport(
                DeviceActivityReport.Context("totalUsage"),
                filter: filter
            )
            .frame(height: 280)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .cardShadow()

            HStack(spacing: 4) {
                Text("your usage stays on this iPhone")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Link(destination: URL(string: "https://recursn.com/mathblocker/privacy-policy")!) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Monitoring

    private var monitoringPill: some View {
        HStack(spacing: 6) {
            let monitoring = MonitoringManager.shared.isMonitoring
            Circle()
                .fill(monitoring ? .green : .orange)
                .frame(width: 8, height: 8)
            Text(monitoring ? "blocking is on" : "blocking is off")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Usage

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
    DashboardView()
        .modelContainer(for: [QuestionAttempt.self, DailyStats.self, UserSettings.self], inMemory: true)
}
