//
//  Barcode.swift
//  Rover
//
//  Created by Sean Rucker on 2018-04-13.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreImage
import os

public struct Barcode: Decodable {
    public enum Format: String, Decodable {
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

// MARK: Convenience Initializers

extension Barcode {
    /**
     * Render the Barcode to a CGImage.
     *
     * Note that what length and sort of text is valid depends on the Barcode format.
     *
     * Note: you are responsible for freeing the returned CGImage when you are finished with it.
     */
    var cgImage: CGImage? {
        let filterName: String
        switch format {
        case .aztecCode:
            filterName = "CIAztecCodeGenerator"
        case .code128:
            filterName = "CICode128BarcodeGenerator"
        case .pdf417:
            filterName = "CIPDF417BarcodeGenerator"
        case .qrCode:
            filterName = "CIQRCodeGenerator"
        }
        
        let data = text.data(using: String.Encoding.ascii)!
        
        var params: [String: Any] = {
            switch format {
            case .pdf417:
                return [
                    "inputCorrectionLevel": 2,
                    "inputPreferredAspectRatio": 4
                    // inputQuietSpace appears to be 2-ish, but is not configurable.
                ]
            case .qrCode:
                return [
                    // // we want a quiet space of 1, however it's not configurable. Thankfully, 1 is the default.
                    // "inputQuietSpace": 1.0,
                    "inputCorrectionLevel": "M"
                ]
            case .code128:
                return [
                    "inputQuietSpace": 1
                ]
            case .aztecCode:
                return [
                    "inputCompactStyle": true,
                    // inputQuietSpace appears to be 2-ish, but is not configurable.
                    // must be set to 0 or nil, but there is a bug in iOS that prevents us setting it explicitly.
                    // However, it is the default.
                    // "inputLayers": nil,
                    "inputCorrectionLevel": 33
                ]
            }
        }()
        
        params["inputMessage"] = data
        
        #if swift(>=4.2)
        let filter = CIFilter(name: filterName, parameters: params)!
        #else
        let filter = CIFilter(name: filterName, withInputParameters: params)!
        #endif
        
        guard let outputImage = filter.outputImage else {
            os_log("Unable to render barcode - see logs emitted directly by CIFilter for details", log: .rover, type: .error)
            return nil
        }
        
        let context = CIContext(options: nil)
        
        let renderedBarcode = context.createCGImage(outputImage, from: outputImage.extent)!
        
        return renderedBarcode
    }
}
