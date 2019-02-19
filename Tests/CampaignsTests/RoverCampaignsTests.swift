//
//  RoverCampaignsTests.swift
//  RoverCampaignsTests
//
//  Created by Andrew Clunis on 2018-12-17.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

@testable import RoverCampaigns
@testable import RoverData
import CoreData
import XCTest

class RoverCampaignsTests: XCTestCase {
    var context: NSManagedObjectContext?
    
    override func setUp() {
        let bundles = [Bundle(for: DataAssembler.self)]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles) else {
            fatalError("Model not found")
        }
        
        let container = NSPersistentContainer(name: "Rover", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        let exp = expectation(description: "Core Data in-memory stack setup")
        
        container.loadPersistentStores { _, possibleError in
            if let error = possibleError {
                fatalError(String(describing: error))
            }
            self.context = container.newBackgroundContext()

            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }

    override func tearDown() {
        self.context = nil
    }
    
    // in each of the following tests we will test match and non-matching events:

    func testSimpleMatchCampaignByEventName() throws {
        let deviceSnapshot = DeviceSnapshot()
        let matchingCampaign = AutomatedCampaign.blank(
            context: self.context!
        )
        matchingCampaign.eventTriggerEventName = "Test Run"
        
        let event = Event(context: context!)
        event.name = "Test Run"
        XCTAssertEqual(
            try campaignsMatching(event: event, forDevice: deviceSnapshot, in: context!),
            [matchingCampaign]
        )
        
        let nonMatchingEvent = Event(context: context!)
        nonMatchingEvent.name = "Some Other Event"
        XCTAssertEqual(
            try campaignsMatching(event: nonMatchingEvent, forDevice: deviceSnapshot, in: context!),
            []
        )
    }
    
    func testMatchCampaignDayOfWeekFilter() {
        
    }
    
    func testMatchEventAttributesFilter() {
        
    }
    
    func testMatchTimeOfDayFilter() {
        
    }
    
    func testMatchDeviceFilter() {
        
    }
    
    func testMultipleFilters() {
        
    }
}

extension AutomatedCampaign {
    class func blank(context: NSManagedObjectContext) -> AutomatedCampaign {
        let campaign = AutomatedCampaign(context: context)
        campaign.hasDayOfWeekFilter = false
        campaign.hasScheduledFilter = false
        campaign.hasEventAttributeFilter = false
        campaign.hasTimeOfDayFilter = false
        
        campaign.dayOfWeekFilterMonday = false
        campaign.dayOfWeekFilterTuesday = false
        campaign.dayOfWeekFilterWednesday = false
        campaign.dayOfWeekFilterThursday = false
        campaign.dayOfWeekFilterFriday = false
        campaign.dayOfWeekFilterSaturday = false
        campaign.dayOfWeekFilterSunday = false
        return campaign
    }
}
