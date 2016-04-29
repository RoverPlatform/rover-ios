//
//  MappingOperation.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-28.
//
//

import Foundation

class MappingOperation<T where T : Mappable> : NSOperation {
    typealias JSON = [String: AnyObject]
    typealias ResourceCallback = T -> Void
    typealias CollectionCallback = [T] -> Void
    
    var json: [String: AnyObject]?
    var resourceCompletion: ResourceCallback?
    var collectionCompletion: CollectionCallback?
    var included: [String: Any]?
    
    init(resourceCompletion: ResourceCallback?) {
        self.resourceCompletion = resourceCompletion
        super.init()
    }
    
    init(collectionCompletion: CollectionCallback?) {
        self.collectionCompletion = collectionCompletion
        super.init()
    }
    
    override func main() {
        // TODO: each return statement should fire completion
        guard let json = json, let data = json["data"] else {
            cancel()
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
            
            rvLog("Mapped collection of type \(T.self.dynamicType)", data: "\(itemsArray.count) items", level: .Trace)
            collectionCompletion?(itemsArray)
        case is [String: AnyObject]:
            let resource = T.instance(data as! [String : AnyObject], included: included)
            guard let typedResource = resource as? T else {
                // error couldnt map to type T
                return
            }
            rvLog("Mapped resource of type \(T.self.dynamicType)", data: nil, level: .Trace)
            resourceCompletion?(typedResource)
        default:
            rvLog("Invalid data.", data: data, level: .Error)
            break
        }
    }
    

}

protocol Mappable {
    associatedtype MappableType
    static func instance(JSON: [String: AnyObject], included: [String: Any]?) -> MappableType?
}
