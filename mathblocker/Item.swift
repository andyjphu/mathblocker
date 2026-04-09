//
//  Item.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
