//
//  MappingOperation.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-28.
//
//

import Foundation

open class MappingOperation<T> : Operation where T : Mappable {
    typealias JSON = [String: Any]
    public typealias ResourceCallback = (T) -> Void
    public typealias CollectionCallback = ([T]) -> Void
    
    open var json: [String: Any]?
    var resourceCompletion: ResourceCallback?
    var collectionCompletion: CollectionCallback?
    open var included: [String: Any]?
    
    public init(resourceCompletion: ResourceCallback?) {
        self.resourceCompletion = resourceCompletion
        super.init()
    }
    
    public init(collectionCompletion: CollectionCallback?) {
        self.collectionCompletion = collectionCompletion
        super.init()
    }
    
    override open func main() {
        // TODO: each return statement should fire completion
        guard let json = json, let data = json["data"] else {
            // As per the above "TODO" this operation should call the completion handler even in cases where the JSON data is nil. Unfortunately we can only do this for collection MappingOperations as there is no way to instantiate a singular Mappable without any JSON data. This will be addressed properly in 2.0 but for now this should at least let reloadInbox calls return control even when the network request fails.
            collectionCompletion?([T]())
            return
        }
        
        switch data {
        case is Array<JSON>:
            let dataArray = data as! [JSON]
            
            var itemsArray = [T]()
            for data in dataArray {
                guard let resource = T.instance(data, included: included) as? T else { continue }
                itemsArray.append(resource)
            }
            
            rvLog("Mapped collection of type \(type(of: T.self))", data: "\(itemsArray.count) items", level: .trace)
            collectionCompletion?(itemsArray)
        case is [String: Any]:
            let resource = T.instance(data as! [String : AnyObject], included: included)
            guard let typedResource = resource as? T else {
                // error couldnt map to type T
                return
            }
            rvLog("Mapped resource of type \(type(of: T.self))", data: nil, level: .trace)
            resourceCompletion?(typedResource)
        default:
            rvLog("Invalid data.", data: data, level: .error)
            break
        }
    }
    

}

public protocol Mappable {
    associatedtype MappableType
    static func instance(_ JSON: [String: Any], included: [String: Any]?) -> MappableType?
}
