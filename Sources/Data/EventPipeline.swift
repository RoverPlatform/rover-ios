//
//  EventPipeline.swift
//  RoverData
//
//  Created by Andrew Clunis on 2018-12-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import CoreData
import os

public class EventPipeline {
//    public var observers = ObserverSet<Event>()
    
    public var deviceInfoProvider: DeviceInfoProvider? = nil
    
    private let managedObjectContext: NSManagedObjectContext
//    private var objectsDidChangeObserver: NSObjectProtocol!
    
    
    public init(
        managedObjectContext: NSManagedObjectContext
    ) {
        self.managedObjectContext = managedObjectContext
//        self.objectsDidChangeObserver = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: managedObjectContext, queue: nil) { [weak self] notification in
//            guard let insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSObject> else {
//                return
//            }
//
//            let insertedEvents = insertedObjects
//                .compactMap({ $0 as? Event })
//
//            insertedEvents.forEach({ event in self?.observers.notify(parameters: event) })
//        }
    }
    
//    deinit {
//        NotificationCenter.default.removeObserver(self.objectsDidChangeObserver)
//    }
    
    public func addEvent(_ eventInfo: EventInfo) {
        let event = Event(context: self.managedObjectContext)
        
        
    }
    
    
}
