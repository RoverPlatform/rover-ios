//
//  TelephonyAssembler.swift
//  RoverTelephony
//
//  Created by Sean Rucker on 2018-10-22.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public class TelephonyAssembler: Assembler {
    public init() { }
    
    public func assemble(container: Container) {
        container.register(TelephonyContextProvider.self) { _ in
            TelephonyManager()
        }
    }
}
