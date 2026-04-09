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
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.06, green: 0.06, blue: 0.12, alpha: 1.0),
            icon: UIImage(systemName: "brain.head.profile"),
            title: ShieldConfiguration.Label(
                text: "Time's Up!",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Solve math problems to earn more screen time",
                color: UIColor(white: 0.7, alpha: 1.0)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Solve to Unlock",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0),
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Stay Focused",
                color: UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
            )
        )
    }
}
