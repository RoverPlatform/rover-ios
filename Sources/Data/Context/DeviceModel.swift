//
//  DeviceModel.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-09-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

enum DeviceModel {
    case simulator
    case iPhone5
    case iPhone5c
    case iPhone5s
    case iPhone6Plus
    case iPhone6
    case iPhone6s
    case iPhone6sPlus
    case iPhoneSE
    case iPhone7
    case iPhone7Plus
    case iPhone8
    case iPhone8Plus
    case iPhoneX
    case iPhoneXR
    case iPhoneXS
    case iPhoneXSMax
    case iPodTouch1stGen
    case iPodTouch2ndGen
    case iPodTouch3rdGen
    case iPodTouch4thGen
    case iPodTouch5thGen
    case iPodTouch6thGen
    case iPad1stGen
    case iPad2
    case iPadMini
    case iPad3rdGen
    case iPad4thGen
    case iPadAir
    case iPadMini2
    case iPadMini3
    case iPadMini4
    case iPadAir2
    case iPadPro1stGen
    case iPad5thGen
    case iPadPro2ndGen
    case iPad6thGen
    
    var description: String {
        switch self {
        case .simulator:
            return "Simulator"
        case .iPhone5:
            return "iPhone 5"
        case .iPhone5c:
            return "iPhone 5c"
        case .iPhone5s:
            return "iPhone 5s"
        case .iPhone6Plus:
            return "iPhone 6 Plus"
        case .iPhone6:
            return "iPhone 6"
        case .iPhone6s:
            return "iPhone 6s"
        case .iPhone6sPlus:
            return "iPhone 6s Plus"
        case .iPhoneSE:
            return "iPhone SE"
        case .iPhone7:
            return "iPhone 7"
        case .iPhone7Plus:
            return "iPhone 7 Plus"
        case .iPhone8:
            return "iPhone 8"
        case .iPhone8Plus:
            return "iPhone 8 Plus"
        case .iPhoneX:
            return "iPhone X"
        case .iPhoneXR:
            return "iPhone XR"
        case .iPhoneXS:
            return "iPhone XS"
        case .iPhoneXSMax:
            return "iPhone XS Max"
        case .iPodTouch1stGen:
            return "iPod Touch 1st Gen"
        case .iPodTouch2ndGen:
            return "iPod Touch 2nd Gen"
        case .iPodTouch3rdGen:
            return "iPod Touch 3rd Gen"
        case .iPodTouch4thGen:
            return "iPod Touch 4th Gen"
        case .iPodTouch5thGen:
            return "iPod Touch 5th Gen"
        case .iPodTouch6thGen:
            return "iPod Touch 6th Gen"
        case .iPad1stGen:
            return "iPad 1st Gen"
        case .iPad2:
            return "iPad 2"
        case .iPadMini:
            return "iPad Mini"
        case .iPad3rdGen:
            return "iPad 3rd Gen"
        case .iPad4thGen:
            return "iPad 4th Gen"
        case .iPadAir:
            return "iPad Air"
        case .iPadMini2:
            return "iPad Mini 2"
        case .iPadMini3:
            return "iPad Mini 3"
        case .iPadMini4:
            return "iPad Mini 4"
        case .iPadAir2:
            return "iPad Air 2"
        case .iPadPro1stGen:
            return "iPad Pro 1st Gen"
        case .iPad5thGen:
            return "iPad 5th Gen"
        case .iPadPro2ndGen:
            return "iPad Pro 2nd Gen"
        case .iPad6thGen:
            return "iPad 6th Gen"
        }
    }
    
    // This is effectively a look-up table in code, not algorithmic behavior, so silence the function length warning.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    init?(modelName: String) {
        switch modelName {
        case "x86_64":
            self = .simulator
        case "iPhone5,1", "iPhone5,2":
            self = .iPhone5
        case "iPhone5,3", "iPhone5,4":
            self = .iPhone5c
        case "iPhone6,1", "iPhone6,2":
            self = .iPhone5s
        case "iPhone7,1":
            self = .iPhone6Plus
        case "iPhone7,2":
            self = .iPhone6
        case "iPhone8,1":
            self = .iPhone6s
        case "iPhone8,2":
            self = .iPhone6sPlus
        case "iPhone8,4":
            self = .iPhoneSE
        case "iPhone9,1", "iPhone9,3":
            self = .iPhone7
        case "iPhone9,2", "iPhone9,4":
            self = .iPhone7Plus
        case "iPhone10,1", "iPhone10,4":
            self = .iPhone8
        case "iPhone10,2", "iPhone10,5":
            self = .iPhone8Plus
        case "iPhone10,3", "iPhone10,6":
            self = .iPhoneX
        case "iPhone11,8":
            self = .iPhoneXR
        case "iPhone11,2":
            self = .iPhoneXS
        case "iPhone11,4", "iPhone11,6":
            self = .iPhoneXSMax
        case "iPod1,1":
            self = .iPodTouch1stGen
        case "iPod2,1":
            self = .iPodTouch2ndGen
        case "iPod3,1":
            self = .iPodTouch3rdGen
        case "iPod4,1":
            self = .iPodTouch4thGen
        case "iPod5,1":
            self = .iPodTouch5thGen
        case "iPod7,1":
            self = .iPodTouch6thGen
        case "iPad1,1":
            self = .iPad1stGen
        case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":
            self = .iPad2
        case "iPad2,5", "iPad2,6", "iPad2,7":
            self = .iPadMini
        case "iPad3,1", "iPad3,2", "iPad3,3":
            self = .iPad3rdGen
        case "iPad3,4", "iPad3,5", "iPad3,6":
            self = .iPad4thGen
        case "iPad4,1", "iPad4,2", "iPad4,3":
            self = .iPadAir
        case "iPad4,4", "iPad4,5", "iPad4,6":
            self = .iPadMini2
        case "iPad4,7", "iPad4,8", "iPad4,9":
            self = .iPadMini3
        case "iPad5,1", "iPad5,2":
            self = .iPadMini4
        case "iPad5,3", "iPad5,4":
            self = .iPadAir2
        case "iPad6,3", "iPad6,4", "iPad6,7", "iPad6,8":
            self = .iPadPro1stGen
        case "iPad6,11", "iPad6,12":
            self = .iPad5thGen
        case "iPad7,1", "iPad7,2", "iPad7,3", "iPad7,4":
            self = .iPadPro2ndGen
        case "iPad7,5", "iPad7,6":
            self = .iPad6thGen
        default:
            return nil
        }
    }
}
