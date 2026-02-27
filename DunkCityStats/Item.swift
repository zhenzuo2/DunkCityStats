//
//  Item.swift
//  DunkCityStats
//
//  Created by Zuo,Zhen on 2/27/26.
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
