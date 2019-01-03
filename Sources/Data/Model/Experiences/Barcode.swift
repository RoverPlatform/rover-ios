//
//  Barcode.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-04-13.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public struct Barcode: Codable {
    public enum Format: String, Codable {
        case qrCode = "QR_CODE"
        case aztecCode = "AZTEC_CODE"
        case pdf417 = "PDF417"
        case code128 = "CODE_128"
    }

    public var text: String
    public var format: Format
    
    public init(text: String, format: Format) {
        self.text = text
        self.format = format
    }
}
