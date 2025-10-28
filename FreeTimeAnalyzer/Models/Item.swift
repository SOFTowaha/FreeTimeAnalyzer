//
//  Item.swift
//  FreeTimeAnalyzer
//
//  Created by Syed Omar Faruk Towaha on 2025-10-28.
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
