//
//  ShieldManager.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import Foundation
import ManagedSettings
import FamilyControls

/// Applies and removes ManagedSettings shields on user-selected apps.
/// Shields block app access until the user solves math problems.
class ShieldManager {
    static let shared = ShieldManager()

    private let store = ManagedSettingsStore(
        named: ManagedSettingsStore.Name(rawValue: AppGroupConstants.shieldStoreName)
    )

    func applyShields() {
        let selection = SelectionManager.shared.selection

        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        }
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }
        if !selection.webDomainTokens.isEmpty {
            store.shield.webDomains = selection.webDomainTokens
        }
    }

    func removeShields() {
        store.clearAllSettings()
    }

    var shieldsAreActive: Bool {
        store.shield.applications != nil || store.shield.applicationCategories != nil
    }

}
