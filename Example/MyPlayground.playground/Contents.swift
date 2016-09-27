//: Playground - noun: a place where people can play

import UIKit
import Foundation


let string = "https://barcodes.rover.io/?type=hibcpdf417&text=ROVER&scaleX=5&scaleY=5"

let url = URL(string: string)

let key = url!.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics)