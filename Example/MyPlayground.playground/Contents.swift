//: Playground - noun: a place where people can play

import UIKit
import Foundation

var dic: [String : AnyObject] = ["major": 3]

let major = dic["major"] as? Int
let majorNumber = UInt16(major!)