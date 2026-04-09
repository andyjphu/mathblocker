//
//  ShieldConfigurationExtension.swift
//  shconfig
//
//  Created by Andy Phu on 4/9/26.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfig()
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        makeConfig()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfig()
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        makeConfig()
    }

    private func makeConfig() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 0.85),
            icon: UIImage(named: "shield-icon") ?? UIImage(systemName: "leaf"),
            title: ShieldConfiguration.Label(
                text: "you hit your limit",
                color: UIColor(red: 0.15, green: 0.15, blue: 0.13, alpha: 1.0)
            ),
            subtitle: ShieldConfiguration.Label(
                text: "open MathBlocker to earn more time",
                color: UIColor(red: 0.35, green: 0.35, blue: 0.30, alpha: 1.0)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "leave app",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.76, green: 0.52, blue: 0.28, alpha: 1.0)
        )
    }
}
