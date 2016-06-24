//
//  SerializingOperation.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-28.
//
//

import Foundation

public class SerializingOperation : NSOperation {
    public typealias JSONSerializedCompletion = (JSON: [String: AnyObject]) -> Void
    
    let model: Serializable
    let completion: JSONSerializedCompletion
    
    public init(model: Serializable, completion: JSONSerializedCompletion) {
        self.model = model
        self.completion = completion
        super.init()
    }
    
    override public func main() {
        let JSON = model.serialize()
        completion(JSON: JSON)
//        if let JSON = model.serialize() {
//            //completion(JSON: JSON)
//        } else {
//            rvLog("Serialization failed", data: self.model.dynamicType, level: .Error)
//        }
    }
}

public protocol Serializable {
    // TODO: remove the optional from the whole dic
    func serialize() -> [String: AnyObject]
}