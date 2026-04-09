//
//  SelectionManager.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import FamilyControls
import Foundation

@Observable
class SelectionManager {
    static let shared = SelectionManager()

    var selection = FamilyActivitySelection() {
        didSet { save() }
    }

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
    }

    init() {
        load()
    }

    private func save() {
        guard let defaults = AppGroupConstants.sharedDefaults else { return }
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: AppGroupConstants.selectionKey)
    }

    private func load() {
        guard let defaults = AppGroupConstants.sharedDefaults,
              let data = defaults.data(forKey: AppGroupConstants.selectionKey),
              let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }
        selection = saved
    }
}
