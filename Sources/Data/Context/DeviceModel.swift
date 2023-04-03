// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of 
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

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
    case iPhone11
    case iPhone11Pro
    case iPhone11ProMax
    case iPhoneSE2ndGen
    case iPhone12Mini
    case iPhone12
    case iPhone12Pro
    case iPhone12ProMax
    case iPhone13
    case iPhone13Pro
    case iPhone13ProMax
    case iPhone13Mini
    case iPhoneSE3rdGen
    case iPhone14
    case iPhone14Plus
    case iPhone14Pro
    case iPhone14ProMax
    case iPodTouch1stGen
    case iPodTouch2ndGen
    case iPodTouch3rdGen
    case iPodTouch4thGen
    case iPodTouch5thGen
    case iPodTouch6thGen
    case iPodTouch7thGen
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
    case iPad7thGen
    case iPadPro3rdGen
    case iPadPro4thGen
    case iPadMini5thGen
    case iPadAir3rdGen
    case iPad8thGen
    case iPad9thGen
    case iPadMini6thGen
    case iPadAir4thGen
    case iPadPro5thGen
    case iPadAir5thGen
    case iPad10thGen
    case iPadPro6thGen
    
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
        case .iPhone11:
            return "iPhone 11"
        case .iPhone11Pro:
            return "iPhone 11 Pro"
        case .iPhone11ProMax:
            return "iPhone 11 Pro Max"
        case .iPhoneSE2ndGen:
            return "iPhone SE 2nd Gen"
        case .iPhone12Mini:
            return "iPhone 12 Mini"
        case .iPhone12:
            return "iPhone 12"
        case .iPhone12Pro:
            return "iPhone 12 Pro"
        case .iPhone12ProMax:
            return "iPhone 12 Pro Max"
        case .iPhone13:
            return "iPhone 13"
        case .iPhone13Pro:
            return "iPhone 13 Pro"
        case .iPhone13ProMax:
            return "iPhone 13 Pro Max"
        case .iPhone13Mini:
            return "iPhone 13 Mini"
        case .iPhoneSE3rdGen:
            return "iPhone SE 3rd Gen"
        case .iPhone14:
            return "iPhone 14"
        case .iPhone14Plus:
            return "iPhone 14 Plus"
        case .iPhone14Pro:
            return "iPhone 14 Pro"
        case .iPhone14ProMax:
            return "iPhone 14 Pro Max"
        case .iPodTouch7thGen:
            return "iPod Touch 7th Gen"
        case .iPad7thGen:
            return "iPad 7th Gen"
        case .iPadPro3rdGen:
            return "iPad Pro 3rd Gen"
        case .iPadPro4thGen:
            return "iPad Pro 4th Gen"
        case .iPadMini5thGen:
            return "iPad Mini 5th Gen"
        case .iPadAir3rdGen:
            return "iPad Air 3rd Gen"
        case .iPad8thGen:
            return "iPad 8th Gen"
        case .iPad9thGen:
            return "iPad 9th Gen"
        case .iPadMini6thGen:
            return "iPad Mini 6th Gen"
        case .iPadAir4thGen:
            return "iPad Air 4th Gen"
        case .iPadPro5thGen:
            return "iPad Pro 5th Gen"
        case .iPadAir5thGen:
            return "iPad Air 5th Gen"
        case .iPad10thGen:
            return "iPad 10th Gen"
        case .iPadPro6thGen:
            return "iPad Pro 6th Gen"
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
        case "iPhone12,1":
            self = .iPhone11
        case "iPhone12,3":
            self = .iPhone11Pro
        case "iPhone12,5":
            self = .iPhone11ProMax
        case "iPhone12,8":
            self = .iPhoneSE2ndGen
        case "iPhone13,1":
            self = .iPhone12Mini
        case "iPhone13,2":
            self = .iPhone12
        case "iPhone13,3":
            self = .iPhone12Pro
        case "iPhone13,4":
            self = .iPhone12ProMax
        case "iPhone14,2":
            self = .iPhone13Pro
        case "iPhone14,3":
            self = .iPhone13ProMax
        case "iPhone14,4":
            self = .iPhone13Mini
        case "iPhone14,5":
            self = .iPhone13
        case "iPhone14,6":
            self = .iPhoneSE3rdGen
        case "iPhone14,7":
            self = .iPhone14
        case "iPhone14,8":
            self = .iPhone14Plus
        case "iPhone15,2":
            self = .iPhone14Pro
        case "iPhone15,3":
            self = .iPhone14ProMax
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
        case "iPod9,1":
            self = .iPodTouch7thGen
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
        case "iPad7,11", "iPad7,12":
            self = .iPad7thGen
        case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4", "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8":
            self = .iPadPro3rdGen
        case "iPad8,9", "iPad8,10", "iPad8,11", "iPad8,12":
            self = .iPadPro4thGen
        case "iPad11,1", "iPad11,2":
            self = .iPadMini5thGen
        case "iPad11,3", "iPad11,4":
            self = .iPadAir3rdGen
        case "iPad11,6", "iPad11,7":
            self = .iPad8thGen
        case "iPad12,1", "iPad12,2":
            self = .iPad9thGen
        case "iPad13,1", "iPad13,2":
            self = .iPadAir4thGen
        case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7", "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11":
            self = .iPadPro5thGen
        case "iPad13,16", "iPad13,17":
            self = .iPadAir5thGen
        case "iPad13,18", "iPad13,19":
            self = .iPad10thGen
        case "iPad14,1", "iPad14,2":
            self = .iPadMini6thGen
        case "iPad14,3", "iPad14,4", "iPad14,5", "iPad14,6":
            self = .iPadPro6thGen
                        
        default:
            return nil
        }
    }
}
