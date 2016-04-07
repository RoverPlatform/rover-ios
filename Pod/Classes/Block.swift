//
//  Block.swift
//  Pods
//
//  Created by Ata Namvari on 2016-03-17.
//
//

import UIKit

enum Unit {
    case Points(Double)
    case Percentage(Double)
}

class Block: NSObject {
    
    enum HorizontalAlignment {
        case Left
        case Center
        case Right
    }
    
    enum VerticalAlignment {
        case Top
        case Middle
        case Bottom
    }
    
    enum Position {
        case Stacked
        case Floating
    }
    
    var position: Position?
    
    var height: Unit?
    var width: Unit?
    
    var horizontalAlignment: HorizontalAlignment?
    var verticalAlignment: VerticalAlignment?
    
    var leftOffset: Unit?
    var topOffset: Unit?
    var rightOffset: Unit?
    var bottomOffset: Unit?
    var middleOffset: Unit?
    var centerOffset: Unit?

    override init() {
        super.init()
    }
    
}


class Row: NSObject {
    
    var blocks: [Block]?
    
    var height: Unit?
    
    override init() {
        super.init()
    }
    
}