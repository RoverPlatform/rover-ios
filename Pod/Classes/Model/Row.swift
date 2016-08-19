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
    
    let backgroundBlock = Block()
    
    init(blocks: [Block]) {
        backgroundBlock.position = .Floating
        backgroundBlock.alignment = Alignment(horizontal: .Fill, vertical: .Fill)
        
        self.blocks = blocks + [backgroundBlock]
        
        super.init()
    }
    
}
