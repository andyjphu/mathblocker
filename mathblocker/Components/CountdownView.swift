//
//  CountdownView.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import Combine

/// Live countdown to a target date. Updates every second.
struct CountdownView: View {
    let endDate: Date

    @State private var now: Date = .now
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var remaining: TimeInterval {
        max(0, endDate.timeIntervalSince(now))
    }

    private var formatted: String {
        let totalSeconds = Int(remaining)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(formatted)
                .font(Theme.titleFont(size: 64))
                .monospacedDigit()
                .foregroundStyle(remaining < 60 ? .orange : .accent)

            Text("minutes remaining")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .onReceive(timer) { date in
            now = date
        }
    }
}
