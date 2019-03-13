//
//  AttributeRepresentable.swift
//  Rover
//
//  Created by Sean Rucker on 2018-07-25.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol AttributeRepresentable {
    var attributeValue: AttributeValue { get }
}

// MARK: Attributes

extension Attributes: AttributeRepresentable {
    public var attributeValue: AttributeValue {
        return .object(self)
    }
}

// MARK: AttributeValue

extension AttributeValue: AttributeRepresentable {
    public var attributeValue: AttributeValue {
        return self
    }
}

// MARK: Array

extension Array: AttributeRepresentable where Element: ScalarRepresentable {
    public var attributeValue: AttributeValue {
        let value = self.map { $0.scalarValue }
        return .array(value)
    }
}

// MARK: Dictionary

extension Dictionary: AttributeRepresentable where Key == AttributeKey, Value: AttributeRepresentable {
    public var attributeValue: AttributeValue {
        let value = self.reduce(into: Attributes()) { $0[$1.0] = $1.1.attributeValue }
        return .object(value)
    }
}
