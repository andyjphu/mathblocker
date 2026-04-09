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
            backgroundBlurStyle: .systemThinMaterial,
            backgroundColor: UIColor(white: 1.0, alpha: 0.15),
            icon: UIImage(systemName: "brain.head.profile"),
            title: ShieldConfiguration.Label(
                text: "you hit your limit",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "open MathBlocker to earn more time",
                color: UIColor(white: 0.85, alpha: 1.0)
            )
        )
    }
}
