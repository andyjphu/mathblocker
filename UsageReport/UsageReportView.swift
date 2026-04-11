//
//  UsageReportView.swift
//  report
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI

struct UsageReportView: View {
    let report: UsageReport

    private var formattedTotal: String {
        let hours = Int(report.totalDuration) / 3600
        let minutes = (Int(report.totalDuration) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Total time
            totalSection

            // Hourly chart
            if report.hourlyData.contains(where: { $0.duration > 0 }) {
                hourlyChart
            }

            // Top apps
            if !report.topApps.isEmpty {
                topAppsSection
            }

            // Pickups
            pickupsSection
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Total

    private var totalSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.title3)
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 2) {
                Text(formattedTotal)
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(.black)

                Text("on blocked apps today")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
    }

    // MARK: - Hourly Chart

    private var hourlyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("today")
                .font(.caption)
                .foregroundColor(.gray)

            let maxDuration = report.hourlyData.map(\.duration).max() ?? 1
            let currentHour = Calendar.current.component(.hour, from: .now)

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(report.hourlyData) { bucket in
                    if bucket.hour <= currentHour {
                        let height = maxDuration > 0 ? CGFloat(bucket.duration / maxDuration) : 0
                        RoundedRectangle(cornerRadius: 2)
                            .fill(bucket.duration > 0 ? Color(red: 0.76, green: 0.52, blue: 0.28) : Color.gray.opacity(0.15))
                            .frame(height: max(2, height * 40))
                    }
                }
            }
            .frame(height: 44)

            // Hour labels
            HStack {
                Text("12a")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
                Spacer()
                Text("12p")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
                Spacer()
                Text("now")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: - Top Apps

    private var topAppsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("most used")
                .font(.caption)
                .foregroundColor(.gray)

            let maxDuration = report.topApps.first?.duration ?? 1

            ForEach(report.topApps) { app in
                HStack(spacing: 10) {
                    Text(app.name)
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(.black)
                        .frame(width: 90, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: 0.76, green: 0.52, blue: 0.28).opacity(0.6))
                            .frame(width: max(4, geo.size.width * CGFloat(app.duration / maxDuration)))
                    }
                    .frame(height: 12)

                    Text(formatDuration(app.duration))
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(.gray)
                        .frame(width: 45, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Pickups

    private var pickupsSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.tap")
                .font(.caption)
                .foregroundColor(.gray)

            Text("\(report.totalPickups) pickups")
                .font(.system(size: 13, design: .serif))
                .foregroundColor(.gray)

            Spacer()
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

/// Formats a number of seconds as a compact duration string.
/// `3722 → "1h 2m"`, `60 → "1m"`, `0 → "0m"`.
private func compactDuration(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds.rounded()) / 60
    if minutes >= 60 {
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
    return "\(minutes)m"
}

/// Tiny view rendered in the dashboard hero when shields are up, showing how
/// far over the daily budget the user has gone. Computed inside the DAR
/// extension process (which is the only process that can read actual screen
/// time) and passed in via `BudgetOverageScene`.
struct BudgetOverageView: View {
    let data: BudgetStatus

    var body: some View {
        if data.overage > 0 {
            VStack(spacing: 4) {
                Text("\(compactDuration(data.overage)) over budget")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(.orange)
                Text("used \(compactDuration(data.usage)) of your \(compactDuration(data.budget)) budget")
                    .font(.system(size: 11, design: .serif))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        } else {
            // Not over budget — render nothing so the hero card stays clean.
            Color.clear.frame(height: 0)
        }
    }
}

/// Data-driven hero used when monitoring is on and no earned timer is
/// running. Automatically flips between "X min left" (under budget) and
/// "time's up" (over budget) based on the DAR scene's computed usage,
/// which is the only source of truth the main app doesn't have access to.
/// This lets the dashboard show the correct state even when
/// `ShieldManager.shieldsAreActive` is stale or lags behind dame's
/// threshold event.
struct BudgetRemainingView: View {
    let data: BudgetStatus

    private static let accentAmber = Color(red: 0.76, green: 0.52, blue: 0.28)

    var body: some View {
        if data.remaining > 0 {
            // Under budget — show how much free time is left
            VStack(spacing: 4) {
                Text(compactDuration(data.remaining))
                    .font(.system(size: 64, weight: .regular, design: .serif))
                    .foregroundColor(Self.accentAmber)
                    .monospacedDigit()
                Text("of free app time today")
                    .font(.system(size: 15, design: .serif))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
        } else {
            // Over budget — show time's up and the overage details
            VStack(spacing: 4) {
                Text("time's up")
                    .font(.system(size: 56, weight: .regular, design: .serif))
                    .foregroundColor(.orange)
                Text("solve math to earn more time")
                    .font(.system(size: 14, design: .serif))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)

                if data.overage > 0 {
                    Text("\(compactDuration(data.overage)) over budget")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundColor(.orange)
                        .padding(.top, 6)
                    Text("used \(compactDuration(data.usage)) of your \(compactDuration(data.budget)) budget")
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
