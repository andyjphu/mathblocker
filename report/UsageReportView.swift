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
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 2) {
                Text(totalTime)
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundColor(.black)

                Text("on blocked apps today")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
