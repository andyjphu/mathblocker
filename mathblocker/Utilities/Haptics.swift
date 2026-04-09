//
//  Haptics.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import UIKit

enum Haptics {
    static func correct() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func incorrect() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
