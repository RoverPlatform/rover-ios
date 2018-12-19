//
//  NotificationTapBehavior.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-06-20.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import os

public class NotificationTapBehavior: NSObject, NSCoding {
    public func encode(with aCoder: NSCoder) {
        let error = "NotificationTapBehavior is abstract and should not be persisted."
        os_log("%s", log: .persistence, type: .error, error)
        assertionFailure(error)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        let error = "NotificationTapBehavior is abstract and should not have been persisted."
        os_log("%s", log: .persistence, type: .error, error)
        assertionFailure(error)
        return nil
    }
    
    override init() {
        
    }
}

public class OpenAppTapBehavior: NotificationTapBehavior {
    public override func encode(with aCoder: NSCoder) {
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init()
    }
}

public class OpenURLTapBehavior: NotificationTapBehavior {
    public var url: URL
    
    public required init?(coder aDecoder: NSCoder) {
        
        guard let urlString = aDecoder.decodeObject(forKey: "url") as? String else {
            os_log("OpenURLTapBehavior: URL field missing from NSCoder.", log: .persistence, type: .error)
            return nil
        }
        guard let url = URL(string: urlString) else {
            os_log("OpenURLTapBehavior: URL field invalid from NSCoder.", log: .persistence, type: .error)
            return nil
        }
        self.url = url
        super.init()
    }
}

public class PresentWebsiteTapBehavior: NotificationTapBehavior {
    public var url: URL
    
    public required init?(coder aDecoder: NSCoder) {
        guard let urlString = aDecoder.decodeObject(forKey: "url") as? String else {
            os_log("PresentWebsiteTapBehavior: URL field missing from NSCoder.", log: .persistence, type: .error)
            return nil
        }
        guard let url = URL(string: urlString) else {
            os_log("PresentWebsiteTapBehavior: URL field invalid from NSCoder.", log: .persistence, type: .error)
            return nil
        }
        self.url = url
        super.init()
    }
}
