//
//  Row.swift
//  Pods
//
//  Created by Ata Namvari on 2016-05-02.
//
//

import Foundation

@objc
public class Row: NSObject {
    let blocks: [Block]
    
    var height: Unit?
    
    init(blocks: [Block]) {
        self.blocks = blocks
        
        super.init()
    }
    
}
