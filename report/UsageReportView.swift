//
//  UsageReportView.swift
//  report
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI

/// Rendered by the report extension inside the main app's dashboard.
/// Displays total screen time on monitored apps.
struct UsageReportView: View {
    let totalTime: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(totalTime)
                    .font(.system(size: 22, weight: .bold, design: .serif))

                Text("on blocked apps today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
    }
}
