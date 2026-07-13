// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import CoreData
import XCTest

@testable import RoverLocation

class RoverLocationConcurrencyTests: XCTestCase {
    static var container: NSPersistentContainer!
    static var context: NSManagedObjectContext!
    static var writerContext: NSManagedObjectContext!

    var context: NSManagedObjectContext {
        return RoverLocationConcurrencyTests.context
    }

    var writerContext: NSManagedObjectContext {
        return RoverLocationConcurrencyTests.writerContext
    }

    override class func setUp() {
        let testBundle = Bundle(for: RoverLocationConcurrencyTests.self)
        guard
            let locationBundleURL = testBundle.url(
                forResource: "Rover_RoverLocation",
                withExtension: "bundle"
            )
        else {
            fatalError("Location resource bundle not found")
        }
        guard let locationBundle = Bundle(url: locationBundleURL) else {
            fatalError("Unable to load Location resource bundle")
        }
        guard let modelURL = locationBundle.url(forResource: "RoverLocation", withExtension: "momd")
        else {
            fatalError("Location model URL not found")
        }
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Location model could not be loaded")
        }

        // SwiftPM resource models can pick up an unexpected module prefix.
        model.entities.forEach { entity in
            switch entity.name {
            case "Beacon":
                entity.managedObjectClassName = "RoverLocation.Beacon"
            case "Geofence":
                entity.managedObjectClassName = "RoverLocation.Geofence"
            default:
                break
            }
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

        RoverLocationConcurrencyTests.container = container
        RoverLocationConcurrencyTests.context = container.viewContext
        RoverLocationConcurrencyTests.writerContext = container.newBackgroundContext()
        RoverLocationConcurrencyTests.writerContext.mergePolicy = NSOverwriteMergePolicy
    }

    override func tearDown() {
        context.performAndWait {
            let fetchGeofences: NSFetchRequest<Geofence> = Geofence.fetchRequest()
            let geofences = try! context.fetch(fetchGeofences)
            for geofence in geofences {
                context.delete(geofence)
            }

            let fetchBeacons: NSFetchRequest<Beacon> = Beacon.fetchRequest()
            let beacons = try! context.fetch(fetchBeacons)
            for beacon in beacons {
                context.delete(beacon)
            }

            try! context.save()
        }
    }

    /*
     Verified crash-repro case for the pre-fix access pattern:
     - Beacon.fetchAll(in: viewContext).wildCardRegions(maxLength:)
     - Geofence.fetchAll(in: viewContext).regions(closestTo:maxLength:)
    
     Running this test currently crashes with:
     "Crash: xctest at closure #1 in Collection<>.wildCardRegions(maxLength:)"
    
     func testLegacyManagedObjectAccessPatternCrashRepro() throws {
         let readerCount = 32
         let writesPerPass = 250
         let timeout: TimeInterval = 30
    
         let viewContext = self.context
         let writerContext = self.writerContext
    
         writerContext.performAndWait {
             for seed in 0..<500 {
                 let beacon = Beacon(context: writerContext)
                 beacon.id = "legacy-seed-\(seed)-\(UUID().uuidString)"
                 beacon.uuid = UUID()
                 beacon.major = Int32((seed % 255) + 1)
                 beacon.minor = Int32((seed % 255) + 1)
                 beacon.tags = []
             }
    
             for seed in 0..<500 {
                 let geofence = Geofence(context: writerContext)
                 geofence.id = "legacy-seed-geofence-\(seed)-\(UUID().uuidString)"
                 geofence.latitude = Double(seed % 90)
                 geofence.longitude = Double(seed % 180)
                 geofence.radius = Double((seed % 100) + 10)
                 geofence.tags = []
             }
    
             try! writerContext.save()
             writerContext.reset()
         }
    
         let writerQueue = DispatchQueue(label: "io.rover.location.legacy.writer")
         let readerQueue = DispatchQueue(
             label: "io.rover.location.legacy.readers", attributes: .concurrent)
         let group = DispatchGroup()
    
         group.enter()
         writerQueue.async {
             writerContext.performAndWait {
                 for serial in 0..<writesPerPass {
                     if serial.isMultiple(of: 5) {
                         let beaconRequest: NSFetchRequest<Beacon> = Beacon.fetchRequest()
                         beaconRequest.fetchLimit = 1
                         if let existingBeacon = try? writerContext.fetch(beaconRequest).first {
                             writerContext.delete(existingBeacon)
                         }
    
                         let geofenceRequest: NSFetchRequest<Geofence> = Geofence.fetchRequest()
                         geofenceRequest.fetchLimit = 1
                         if let existingGeofence = try? writerContext.fetch(geofenceRequest).first {
                             writerContext.delete(existingGeofence)
                         }
                     } else {
                         let beacon = Beacon(context: writerContext)
                         beacon.id = "legacy-writer-\(serial)-\(UUID().uuidString)"
                         beacon.uuid = UUID()
                         beacon.major = Int32((serial % 500) + 1)
                         beacon.minor = Int32(((serial + 7) % 500) + 1)
                         beacon.tags = []
    
                         let geofence = Geofence(context: writerContext)
                         geofence.id = "legacy-writer-geofence-\(serial)-\(UUID().uuidString)"
                         geofence.latitude = Double(serial % 90)
                         geofence.longitude = Double(serial % 180)
                         geofence.radius = Double((serial % 100) + 10)
                         geofence.tags = []
                     }
                 }
    
                 do {
                     try writerContext.save()
                     writerContext.reset()
                 } catch {
                     writerContext.rollback()
                 }
             }
    
             group.leave()
         }
    
         for _ in 0..<readerCount {
             group.enter()
             readerQueue.async {
                 autoreleasepool {
                     let beaconRegions = Beacon.fetchAll(in: viewContext).wildCardRegions(maxLength: 20)
                     _ = beaconRegions.count
    
                     let geofenceRegions = Geofence.fetchAll(in: viewContext).regions(
                         closestTo: nil,
                         maxLength: 20
                     )
                     _ = geofenceRegions.count
                 }
    
                 group.leave()
             }
         }
    
         XCTAssertEqual(group.wait(timeout: .now() + timeout), .success)
     }
     */

    func testBeaconWildcardRegionsSnapshotHelperRespectsUniqueUUIDsAndMaxLength() {
        writerContext.performAndWait {
            let fixedUUID = UUID()
            for index in 0..<12 {
                let beacon = Beacon(context: writerContext)
                beacon.id = "fixed-\(index)-\(UUID().uuidString)"
                beacon.uuid = fixedUUID
                beacon.major = Int32(index + 1)
                beacon.minor = Int32(index + 1)
                beacon.tags = []
            }

            for index in 0..<9 {
                let beacon = Beacon(context: writerContext)
                beacon.id = "unique-\(index)-\(UUID().uuidString)"
                beacon.uuid = UUID()
                beacon.major = Int32(index + 100)
                beacon.minor = Int32(index + 200)
                beacon.tags = []
            }

            try! writerContext.save()
            writerContext.reset()
        }

        let beaconRegions = Beacon.wildcardRegions(in: context, maxLength: 5)
        XCTAssertEqual(beaconRegions.count, 5)
        XCTAssertEqual(Set(beaconRegions.map(\.uuid)).count, beaconRegions.count)
    }

    func testGeofenceRegionsSnapshotHelperRespectsMaxLength() {
        writerContext.performAndWait {
            for index in 0..<40 {
                let geofence = Geofence(context: writerContext)
                geofence.id = "geo-\(index)-\(UUID().uuidString)"
                geofence.latitude = Double(index)
                geofence.longitude = Double(index)
                geofence.radius = Double((index % 25) + 10)
                geofence.tags = []
            }

            try! writerContext.save()
            writerContext.reset()
        }

        let geofenceRegions = Geofence.regions(in: context, closestTo: nil, maxLength: 15)
        XCTAssertEqual(geofenceRegions.count, 15)
    }

    func testSnapshotHelpersHandleConcurrentReads() {
        writerContext.performAndWait {
            for index in 0..<120 {
                let beacon = Beacon(context: writerContext)
                beacon.id = "concurrent-beacon-\(index)-\(UUID().uuidString)"
                beacon.uuid = UUID()
                beacon.major = Int32((index % 255) + 1)
                beacon.minor = Int32((index % 255) + 1)
                beacon.tags = []

                let geofence = Geofence(context: writerContext)
                geofence.id = "concurrent-geofence-\(index)-\(UUID().uuidString)"
                geofence.latitude = Double(index % 90)
                geofence.longitude = Double(index % 180)
                geofence.radius = Double((index % 100) + 10)
                geofence.tags = []
            }

            try! writerContext.save()
            writerContext.reset()
        }

        let group = DispatchGroup()
        let queue = DispatchQueue(label: "io.rover.location.concurrent-helpers", attributes: .concurrent)
        let readerContext = RoverLocationConcurrencyTests.container.newBackgroundContext()
        readerContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

        for _ in 0..<12 {
            group.enter()
            queue.async {
                for _ in 0..<25 {
                    _ = Beacon.wildcardRegions(in: readerContext, maxLength: 20).count
                    _ = Geofence.regions(in: readerContext, closestTo: nil, maxLength: 20).count
                }

                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 30), .success)
    }
}
