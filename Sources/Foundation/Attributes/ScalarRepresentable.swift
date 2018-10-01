//
//  ScalarRepresentable.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2018-07-25.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol ScalarRepresentable: AttributeRepresentable {
    var scalarValue: Scalar { get }
}

extension ScalarRepresentable {
    public var attributeValue: AttributeValue {
        return .scalar(self.scalarValue)
    }
}

// MARK: String

extension String: ScalarRepresentable {
    public var scalarValue: Scalar {
        return .string(self)
    }
}

// MARK: Int

extension Int: ScalarRepresentable {
    public var scalarValue: Scalar {
        let value = Double(self)
        return .number(value)
    }
}

extension Int8: ScalarRepresentable {
    public var scalarValue: Scalar {
        let value = Double(self)
        return .number(value)
    }
}

extension Int16: ScalarRepresentable {
    public var scalarValue: Scalar {
        let value = Double(self)
        return .number(value)
    }
}

extension Int32: ScalarRepresentable {
    public var scalarValue: Scalar {
        let value = Double(self)
        return .number(value)
    }
}

extension Int64: ScalarRepresentable {
    public var scalarValue: Scalar {
        let value = Double(self)
        return .number(value)
    }
}

// MARK: Double

extension Double: ScalarRepresentable {
    public var scalarValue: Scalar {
        return .number(self)
    }
}

// MARK: Bool

extension Bool: ScalarRepresentable {
    public var scalarValue: Scalar {
        return .boolean(self)
    }
}

// MARK: Date

extension Date: ScalarRepresentable {
    public var scalarValue: Scalar {
        let value = DateFormatter.rfc3339.string(from: self)
        return .string(value)
    }
}

// MARK: URL

extension URL: ScalarRepresentable {
    public var scalarValue: Scalar {
        return .string(self.absoluteString)
    }
}
