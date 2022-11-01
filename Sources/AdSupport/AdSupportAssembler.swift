//
//  AdSupportAssembler.swift
//  RoverAdSupport
//
//  Created by Sean Rucker on 2018-10-22.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

#if !COCOAPODS
import RoverFoundation
import RoverData
#endif

public class AdSupportAssembler: Assembler {
    public init() { }
    
    public func assemble(container: Container) {
        container.register(AdSupportContextProvider.self) { _ in
            AdSupportManager()
        }
    }
}
