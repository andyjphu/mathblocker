//
//  Haptics.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import UIKit

/// Reuses a single feedback generator to avoid first-call initialization lag.
enum Haptics {
    private static let notification = UINotificationFeedbackGenerator()
    private static let selection = UISelectionFeedbackGenerator()
    private static let impact = UIImpactFeedbackGenerator(style: .medium)

    /// Call once at startup to warm the haptic engine.
    static func prepare() {
        notification.prepare()
        selection.prepare()
        impact.prepare()
    }

    static func correct() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    static func incorrect() {
        notification.notificationOccurred(.error)
        notification.prepare()
    }

    static func tap() {
        selection.selectionChanged()
        selection.prepare()
    }

    static func bump(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred()
    }
}
