//
//  AuthorizationManager.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import FamilyControls
import SwiftUI

/// Manages Family Controls authorization state.
/// Wraps AuthorizationCenter and exposes reactive status for the UI.
@Observable
class AuthorizationManager {
    static let shared = AuthorizationManager()

    var authorizationStatus: AuthorizationStatus = .notDetermined
    var errorMessage: String?

    init() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    var isAuthorized: Bool {
        authorizationStatus == .approved
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            await MainActor.run {
                self.authorizationStatus = AuthorizationCenter.shared.authorizationStatus
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.authorizationStatus = AuthorizationCenter.shared.authorizationStatus
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func refreshStatus() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }
}
