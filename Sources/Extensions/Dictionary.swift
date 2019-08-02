//
//  Dictionary.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-08-01.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

extension Dictionary {
    func mapValuesWithKey<T>(transform: (Key, Value) throws -> T) throws -> [Key: T] {
        var result = [Key: T]()
        try self.keys.forEach { key in
            result[key] = try transform(key, self[key]!)
        }
        return result
    }
    
    func mapValuesWithKey<T>(transform: (Key, Value) -> T) -> [Key: T] {
            var result = [Key: T]()
            self.keys.forEach { key in
                result[key] = transform(key, self[key]!)
            }
            return result
        }
}
