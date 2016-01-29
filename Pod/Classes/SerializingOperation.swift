//
//  SerializingOperation.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-28.
//
//

import Foundation

class SerializingOperation : NSOperation {
    typealias JSONSerializedCompletion = (JSON: [String: AnyObject]) -> Void
    
    let model: Serializable
    let completion: JSONSerializedCompletion
    
    init(model: Serializable, completion: JSONSerializedCompletion) {
        self.model = model
        self.completion = completion
        super.init()
    }
    
    override func main() {
        if let JSON = model.serialize() {
            completion(JSON: JSON)
        } else {
            //fail
        }
    }
}

protocol Serializable {
    func serialize() -> [String: AnyObject]?
}