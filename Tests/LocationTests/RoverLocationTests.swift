//
//  RoverLocationTests.swift
//  RoverLocationTests
//
//  Created by Sean Rucker on 2018-03-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData
import CoreLocation
@testable import RoverLocation
import XCTest

class RoverLocationTests: XCTestCase {
    struct GeofenceNode: Codable, Hashable {
        static func == (lhs: GeofenceNode, rhs: GeofenceNode) -> Bool {
            return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude && lhs.radius == rhs.radius
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(self.latitude)
            hasher.combine(self.longitude)
            hasher.combine(self.radius)
        }
        
        var name: String
        var address: String
        var city: String
        var province: String
        var country: String
        var latitude: Double
        var longitude: Double
        var radius: Double
        var tags: [String]
    }
    
    static var geofenceNodes: [GeofenceNode]
    
    var geofenceNodes: [GeofenceNode] {
        return RoverLocationTests.geofenceNodes
    }
    
    struct BeaconNode {
        var id: String
        var major: Int32
        var minor: Int32
        var uuid: UUID
        var tags: [String]
    }
    
    static var beaconNodes: [BeaconNode]
    
    static var context: NSManagedObjectContext
    
    var context: NSManagedObjectContext {
        return RoverLocationTests.context
    }
    
    override class func setUp() {
        let bundle = Bundle(for: RoverLocationTests.self)
        let fileURL = bundle.url(forResource: "Geofences", withExtension: "plist")!
        let fileData = try! Data(contentsOf: fileURL)
        RoverLocationTests.geofenceNodes = try! PropertyListDecoder().decode([GeofenceNode].self, from: fileData)
        
        let bundles = [Bundle(for: LocationAssembler.self)]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles) else {
            fatalError("Model not found")
        }
        
        let container = NSPersistentContainer(name: "RoverLocation", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            precondition(description.type == NSInMemoryStoreType)
            
            guard error == nil else {
                fatalError("Failed to load store: \(error!)")
            }
        }
        
        RoverLocationTests.context = container.viewContext
    }
    
    override func tearDown() {
        context.performAndWait {
            let fetchGeofences: NSFetchRequest<Geofence> = Geofence.fetchRequest()
            let geofences = try! self.context.fetch(fetchGeofences)
            for geofence in geofences {
                context.delete(geofence)
            }
            
            let fetchBeacons: NSFetchRequest<Beacon> = Beacon.fetchRequest()
            let beacons = try! self.context.fetch(fetchBeacons)
            for beacon in beacons {
                context.delete(beacon)
            }
            
            try! context.save()
        }
    }

    final class MockRegionManager: RegionManager {
        let context: NSManagedObjectContext
        
        init(context: NSManagedObjectContext) {
            self.context = context
        }
    }
    
    func testRegionManager() {
        let uuids = (1...3).map { _ in UUID() }
        self.context.performAndWait {
            for n: Int32 in 1...100 {
                let beacon = Beacon(context: self.context)
                beacon.id = "\(n)"
                beacon.major = n
                beacon.minor = n
                beacon.uuid = uuids.randomElement()!
                beacon.tags = []
            }
            
            geofenceNodes.forEach { node in
                let geofence = Geofence(context: self.context)
                geofence.id = UUID().uuidString
                geofence.latitude = node.latitude
                geofence.longitude = node.longitude
                geofence.radius = node.radius
                geofence.tags = node.tags
            }
            
            try! self.context.save()
        }
        
        final class MockRegionManager: RegionManager {
            let context: NSManagedObjectContext
            
            init(context: NSManagedObjectContext) {
                self.context = context
            }
        }
        
        let regionManager = MockRegionManager(context: self.context)
        
        let wildcardBeaconRegions = regionManager.wilcardBeaconRegions(maxLength: 20)
        XCTAssertEqual(wildcardBeaconRegions.count, 3)
        
        let rogersCenter = CLLocation(latitude: 43.641_4, longitude: 79.389_4)
        let circularRegions = regionManager.circularRegions(closestTo: rogersCenter.coordinate, maxLength: 20)
        XCTAssertEqual(circularRegions.count, 20)
        
        let randomCircularRegions = regionManager.randomCircularRegions(maxLength: 20)
        XCTAssertEqual(randomCircularRegions.count, 20)
        
        let regions = regionManager.regionsToMonitor(currentLocation: nil)
        XCTAssertEqual(regions.count, 20)
    }
    
    func testDistanceSorting() {
        self.context.performAndWait {
            geofenceNodes.forEach { node in
                let geofence = Geofence(context: self.context)
                geofence.id = UUID().uuidString
                geofence.latitude = node.latitude
                geofence.longitude = node.longitude
                geofence.radius = node.radius
                geofence.tags = node.tags
            }
            
            try! self.context.save()
        }
        
        let fetchRequest: NSFetchRequest<Geofence> = Geofence.fetchRequest()
        var geofences = try! self.context.fetch(fetchRequest)
        XCTAssertEqual(geofences.count, geofenceNodes.count)
        XCTAssertGreaterThan(geofences.count, 3_000)
        
        let rogersCenter = CLLocation(latitude: 43.641_4, longitude: 79.389_4)
        
        self.measure {
            geofences.sortByDistance(from: rogersCenter.coordinate)
        }
        
        var a: CLLocationDistance?
        for geofence in geofences {
            let b = rogersCenter.coordinate.distanceTo(geofence: geofence)
            
            if let a = a {
                XCTAssertLessThanOrEqual(a, b)
            }
            
            a = b
        }
    }
    
    func testBeaconIDConstraint() {
        self.context.performAndWait {
            let a = Beacon(context: self.context)
            a.id = "1"
            a.uuid = UUID()
            a.major = 1
            a.minor = 1
            
            let b = Beacon(context: self.context)
            b.id = "2"
            b.uuid = UUID()
            b.major = 2
            b.minor = 2
            
            do {
                try self.context.save()
            } catch {
                XCTFail("Should allow unique IDs")
            }
        }
        
        self.context.performAndWait {
            let a = Beacon(context: self.context)
            a.id = "3"
            a.uuid = UUID()
            a.major = 3
            a.minor = 3
            
            let b = Beacon(context: self.context)
            b.id = "3"
            b.uuid = UUID()
            b.major = 4
            b.minor = 4
            
            do {
                try self.context.save()
                XCTFail("Should not allow duplicate IDs")
            } catch {
                self.context.rollback()
            }
        }
        
        let request: NSFetchRequest<Beacon> = Beacon.fetchRequest()
        let result = try! self.context.fetch(request)
        XCTAssertEqual(result.count, 2)
    }
    
    func testBeaconCompoundIndex() {
        self.context.performAndWait {
            let uuid = UUID()
            
            let a = Beacon(context: self.context)
            a.id = UUID().uuidString
            a.uuid = uuid
            a.major = 1
            a.minor = 2
            
            let b = Beacon(context: self.context)
            b.id = UUID().uuidString
            b.uuid = uuid
            b.major = 1
            b.minor = 2
            
            do {
                try self.context.save()
                XCTFail("Should not allow duplicate uuid/major/minor combinations")
            } catch {
                self.context.rollback()
            }
        }
        
        let request1: NSFetchRequest<Beacon> = Beacon.fetchRequest()
        let result1 = try! self.context.fetch(request1)
        XCTAssertEqual(result1.count, 0)
        
        self.context.performAndWait {
            let uuid = UUID()
            
            let c = Beacon(context: self.context)
            c.id = UUID().uuidString
            c.uuid = uuid
            c.major = 3
            c.minor = 4
            
            let d = Beacon(context: self.context)
            d.id = UUID().uuidString
            d.uuid = UUID()
            d.major = 3
            d.minor = 4
            
            let e = Beacon(context: self.context)
            e.id = UUID().uuidString
            e.uuid = uuid
            e.major = 5
            e.minor = 4
            
            let f = Beacon(context: self.context)
            f.id = UUID().uuidString
            f.uuid = uuid
            f.major = 3
            f.minor = 5
            
            do {
                try self.context.save()
            } catch {
                XCTFail("Should allow unique uuid/major/minor combinations")
            }
        }
        
        let request2: NSFetchRequest<Beacon> = Beacon.fetchRequest()
        let result2 = try! self.context.fetch(request2)
        XCTAssertEqual(result2.count, 4)
    }
    
    // MARK: Geofence tests
    
    func testGeofenceIDConstraint() {
        self.context.performAndWait {
            let a = Geofence(context: self.context)
            a.id = "1"
            a.latitude = 1
            a.longitude = 1
            a.radius = 1
            
            let b = Geofence(context: self.context)
            b.id = "2"
            b.latitude = 2
            b.longitude = 2
            b.radius = 2
            
            do {
                try self.context.save()
            } catch {
                XCTFail("Should allow unique IDs")
            }
        }
        
        self.context.performAndWait {
            let a = Geofence(context: self.context)
            a.id = "3"
            a.latitude = 3
            a.longitude = 3
            a.radius = 3
            
            let b = Geofence(context: self.context)
            b.id = "3"
            b.latitude = 4
            b.longitude = 4
            b.radius = 4
            
            do {
                try self.context.save()
                XCTFail("Should not allow duplicate IDs")
            } catch {
                self.context.rollback()
            }
        }
        
        let request: NSFetchRequest<Geofence> = Geofence.fetchRequest()
        let result = try! self.context.fetch(request)
        XCTAssertEqual(result.count, 2)
    }
    
    func testGeofenceCompoundIndex() {
        self.context.performAndWait {
            let a = Geofence(context: self.context)
            a.id = UUID().uuidString
            a.latitude = 1
            a.longitude = 2
            a.radius = 3
            
            let b = Geofence(context: self.context)
            b.id = UUID().uuidString
            b.latitude = 1
            b.longitude = 2
            b.radius = 3
            
            do {
                try self.context.save()
                XCTFail("Should not allow duplicate latitude/longitude/radius combinations")
            } catch {
                self.context.rollback()
            }
        }
        
        let request1: NSFetchRequest<Geofence> = Geofence.fetchRequest()
        let result1 = try! self.context.fetch(request1)
        XCTAssertEqual(result1.count, 0)
        
        self.context.performAndWait {
            let c = Geofence(context: self.context)
            c.id = UUID().uuidString
            c.latitude = 4
            c.longitude = 5
            c.radius = 6
            
            let d = Geofence(context: self.context)
            d.id = UUID().uuidString
            d.latitude = 4
            d.longitude = 5
            d.radius = 7
            
            let e = Geofence(context: self.context)
            e.id = UUID().uuidString
            e.latitude = 4
            e.longitude = 7
            e.radius = 6
            
            let f = Geofence(context: self.context)
            f.id = UUID().uuidString
            f.latitude = 7
            f.longitude = 5
            f.radius = 6
            
            do {
                try self.context.save()
            } catch {
                XCTFail("Should allow unique latitude/longitude/radius combinations")
            }
        }
        
        let request2: NSFetchRequest<Geofence> = Geofence.fetchRequest()
        let result2 = try! self.context.fetch(request2)
        XCTAssertEqual(result2.count, 4)
    }
}
