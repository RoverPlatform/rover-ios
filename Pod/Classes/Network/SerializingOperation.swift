//
//  SerializingOperation.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-28.
//
//

import Foundation

open class SerializingOperation : Operation {
    public typealias JSONSerializedCompletion = (_ JSON: [String: Any]) -> Void
    
    let model: Serializable
    let completion: JSONSerializedCompletion
    
    public init(model: Serializable, completion: @escaping JSONSerializedCompletion) {
        self.model = model
        self.completion = completion
        super.init()
    }
    
    override open func main() {
        let JSON = model.serialize()
        completion(JSON)
//        if let JSON = model.serialize() {
//            //completion(JSON: JSON)
//        } else {
//            rvLog("Serialization failed", data: self.model.dynamicType, level: .Error)
//        }
    }
}

public protocol Serializable {
    // TODO: remove the optional from the whole dic
    func serialize() -> [String: Any]
}
