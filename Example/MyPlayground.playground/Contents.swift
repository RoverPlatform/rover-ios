//: Playground - noun: a place where people can play

import UIKit
import Foundation


let string = "tracklyst://soundcloud/connect"

let pring = string.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLHostAllowedCharacterSet())