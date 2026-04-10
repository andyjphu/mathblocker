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
@Observable
class ShieldManager {
    static let shared = ShieldManager()

    private let store = ManagedSettingsStore(
        named: ManagedSettingsStore.Name(rawValue: AppGroupConstants.shieldStoreName)
    )

    /// Observable copy of the shield state. Updated whenever apply/remove
    /// is called so SwiftUI views can react to changes.
    private(set) var shieldsAreActive: Bool = false

    init() {
        refreshState()
    }

    /// Re-reads the underlying store to sync `shieldsAreActive`.
    /// Call this when the app becomes active to catch state changes
    /// that happened in extensions.
    func refreshState() {
        shieldsAreActive = store.shield.applications != nil
            || store.shield.applicationCategories != nil
    }

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
        refreshState()
    }

    func removeShields() {
        store.clearAllSettings()
        refreshState()
    }
}
