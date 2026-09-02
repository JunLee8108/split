//
//  Item.swift
//  Splits
//
//  Created by Jun Lee on 9/2/26.
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
