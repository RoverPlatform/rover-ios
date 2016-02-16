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
            
            //guard let typedCollection = itemsArray as? [T] else {
            // error couldnt map collection to type [T]
            //    return
            //}
            collectionCompletion?(itemsArray)
        case is [String: AnyObject]:
            let resource = T.instance(data as! [String : AnyObject], included: included)
            guard let typedResource = resource as? T else {
                // error couldnt map to type T
                return
            }
            resourceCompletion?(typedResource)
        default:
            // error invalid data hash
            break
        }
    }
    

}

protocol Mappable {
    typealias MappableType
    static func instance(JSON: [String: AnyObject], included: [String: Any]?) -> MappableType?
}
