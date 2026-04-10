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
