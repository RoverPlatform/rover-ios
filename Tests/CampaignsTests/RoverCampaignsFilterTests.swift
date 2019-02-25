//
//  RoverCampaignsFilterTests.swift
//  RoverCampaignsTests
//
//  Created by Andrew Clunis on 2018-12-17.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData
@testable import RoverCampaigns
@testable import RoverData
import XCTest

class RoverCampaignsFilterTests: XCTestCase {
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
        let matchingCampaign = AutomatedCampaign.blank(
            context: self.context!
        )
        matchingCampaign.eventTriggerEventName = "Test Run"
        
        let event = Event(context: context!)
        event.name = "Test Run"
        try assertThat(event: event, matchesCampaigns: [matchingCampaign])
        
        let nonMatchingEvent = Event(context: context!)
        nonMatchingEvent.name = "Some Other Event"
        
        try assertThat(event: nonMatchingEvent, matchesCampaigns: [])
    }
    
    func testMatchCampaignDayOfWeekFilter() throws {
        let matchingCampaign = AutomatedCampaign.blank(
            context: self.context!
        )
        matchingCampaign.eventTriggerEventName = "Test Run"
        matchingCampaign.hasDayOfWeekFilter = true
        matchingCampaign.dayOfWeekFilterTuesday = true
        
        let event = Event(context: context!)
        event.name = "Test Run"
        
        // 1550613954 Tuesday Feb 19 2019 17:06 america/montreal
        let aTuesday = Date(timeIntervalSince1970: 1_550_613_954)
        
        try assertThat(event: event, matchesCampaigns: [matchingCampaign], whenTodayIs: aTuesday)
        
        // 1550677593 Wednesday Feb 20 2019 10:46 america/montreal
        let aWednesday = Date(timeIntervalSince1970: 1_550_677_593)
        try assertThat(event: event, matchesCampaigns: [], whenTodayIs: aWednesday)
    }
    
    func testMatchEventAttributesFilter() throws {
        let matchingCampaign = AutomatedCampaign.blank(
            context: self.context!
        )
        matchingCampaign.eventTriggerEventName = "Test Run"
        matchingCampaign.hasEventAttributeFilter = true
        matchingCampaign.eventAttributeFilterPredicate = ComparisonPredicate(
            keyPath: "attribute field",
            modifier: .direct,
            operator: .equalTo,
            numberValue: 42
        )
        
        let event = Event(context: context!)
        event.name = "Test Run"
        event.attributes.rawValue["attribute field"] = 42
        try assertThat(event: event, matchesCampaigns: [matchingCampaign])
        
        let nonMatchingEvent = Event(context: context!)
        nonMatchingEvent.name = "Test Run"
        nonMatchingEvent.attributes.rawValue["attribute field"] = 43
        try assertThat(event: nonMatchingEvent, matchesCampaigns: [])
    }
    
    func testInvalidPredicateEventAttributesFilterShouldNotMatch() throws {
        let matchingCampaign = AutomatedCampaign.blank(
            context: self.context!
        )
        matchingCampaign.eventTriggerEventName = "Test Run"
        matchingCampaign.hasEventAttributeFilter = true
        matchingCampaign.eventAttributeFilterPredicate = ComparisonPredicate(
            keyPath: "attribute field",
            // .any modifier is inappropriate for scalar values, so NSPredicate will fail.
            modifier: .any,
            operator: .equalTo,
            numberValue: 42
        )
        
        let event = Event(context: context!)
        event.name = "Test Run"
        event.attributes.rawValue["attribute field"] = 42
        
        // also asserting that we do not crash the process!
        try assertThat(event: event, matchesCampaigns: [])
    }
    
    func testMatchTimeOfDayFilter() throws {
        let matchingCampaign = AutomatedCampaign.blank(
            context: self.context!
        )
        matchingCampaign.eventTriggerEventName = "Test Run"
        matchingCampaign.hasTimeOfDayFilter = true
        matchingCampaign.timeOfDayFilterStartTime = 3_600 * 17
        matchingCampaign.timeOfDayFilterEndTime = 3_600 * 18
        
        let event = Event(context: context!)
        event.name = "Test Run"
        
        // 1550613954 Tuesday Feb 19 2019 17:06 america/montreal
        let aTimeJustAfterFive = Date(timeIntervalSince1970: 1_550_613_954)
        try assertThat(event: event, matchesCampaigns: [matchingCampaign], whenTodayIs: aTimeJustAfterFive)
    }
    
    func testMatchDeviceFilter() throws {
        let deviceSnapshot = DeviceSnapshot(
            isTestDevice: true
        )
        
        let matchingCampaign = AutomatedCampaign.blank(context: self.context!)
        matchingCampaign.eventTriggerEventName = "Test Run"
        matchingCampaign.deviceFilterPredicate = ComparisonPredicate(
            keyPath: "isTestDevice",
            modifier: .direct,
            operator: .equalTo,
            booleanValue: true
        )
        
        let event = Event(context: context!)
        event.name = "Test Run"

        try assertThat(event: event, matchesCampaigns: [matchingCampaign], forDevice: deviceSnapshot)
        try assertThat(event: event, matchesCampaigns: [])
    }
    
    func testMatchDeviceFilterOnAttributes() throws {
        let deviceSnapshot = DeviceSnapshot(
            userInfo: [
                "scoreChannel": true
            ]
        )
        let matchingCampaign = AutomatedCampaign.blank(context: self.context!)
        matchingCampaign.eventTriggerEventName = "Test Run"
        matchingCampaign.deviceFilterPredicate = ComparisonPredicate(
            keyPath: "userInfo.scoreChannel",
            modifier: .direct,
            operator: .equalTo,
            booleanValue: true
        )
        
        let event = Event(context: context!)
        event.name = "Test Run"
        
        try assertThat(event: event, matchesCampaigns: [matchingCampaign], forDevice: deviceSnapshot)
        try assertThat(event: event, matchesCampaigns: [])
    }
    
    func testMultipleFiltersInQueryPredicate() throws {
        // the day-of-week/time-of-day filters are implemented by a single giant query predicate that is evaluated by Core Data (in fact in sqlite outside of the test suite).  This test validates they are not incorrectly interfering with one another.
        let matchingCampaign = AutomatedCampaign.blank(
            context: self.context!
        )
        matchingCampaign.eventTriggerEventName = "Test Run"
        
        // first we'll start with a day of week filter:
        matchingCampaign.hasDayOfWeekFilter = true
        matchingCampaign.dayOfWeekFilterTuesday = true
        
        // then we'll add a time of day filter:
        matchingCampaign.hasTimeOfDayFilter = true
        matchingCampaign.timeOfDayFilterStartTime = 3_600 * 10
        matchingCampaign.timeOfDayFilterEndTime = 3_600 * 18
        
        let event = Event(context: context!)
        event.name = "Test Run"
        
        // 1550613954 Tuesday Feb 19 2019 17:06 america/montreal.  Should match on both time of day and day of week.:
        let aTuesdayAfterFive = Date(timeIntervalSince1970: 1_550_613_954)
        try assertThat(event: event, matchesCampaigns: [matchingCampaign], whenTodayIs: aTuesdayAfterFive)
        
        // 1550677593 Wednesday Feb 20 2019 10:46 america/montreal. Should match on time of day but not day of week.
        let aWednesdayAfterFive = Date(timeIntervalSince1970: 1_550_677_593)
        try assertThat(event: event, matchesCampaigns: [], whenTodayIs: aWednesdayAfterFive)
        
        // 1550617554 Tuesday Feb 19 2019 18:06 america/montreal.  Should day of week but not on time.
        let aTuesdayAfterSix = Date(timeIntervalSince1970: 1_550_617_554)
        try assertThat(event: event, matchesCampaigns: [], whenTodayIs: aTuesdayAfterSix)
        
        // 1550681193 Tuesday Feb 19 2019 18:06 america/montreal.  Should match on neither.
        let aWednesdayAfterSix = Date(timeIntervalSince1970: 1_550_681_193)
        try assertThat(event: event, matchesCampaigns: [], whenTodayIs: aWednesdayAfterSix)
    }
    
    func testGeowithinPredicate() throws {
        let deviceSnapshotInToronto = DeviceSnapshot(
            userInfo: [
                "location": [
                    // lat, long
                    43.650_678_3, -79.378_002_5
                ]
            ]
        )
        
        let deviceSnapshotNotInToronto = DeviceSnapshot(
            userInfo: [
                "location": [
                    32.076_401_4, 34.774_564_6
                ]
            ]
        )
        
        let matchingCampaign = AutomatedCampaign.blank(context: self.context!)
        matchingCampaign.eventTriggerEventName = "Test Run"
        matchingCampaign.deviceFilterPredicate = ComparisonPredicate(
            keyPath: "userInfo.location",
            modifier: .direct,
            operator: .geoWithin,
            numberValues: [
                // lat, long, radius(m)
                43.650_678_3, -79.378_002_5, 100
            ]
        )
        
        let event = Event(context: context!)
        event.name = "Test Run"
        
        try assertThat(event: event, matchesCampaigns: [matchingCampaign], forDevice: deviceSnapshotInToronto)
        try assertThat(event: event, matchesCampaigns: [], forDevice: deviceSnapshotNotInToronto)
    }
    
    private func assertThat(
        event: Event,
        matchesCampaigns: [AutomatedCampaign],
        whenTodayIs today: Date = Date(),
        forDevice device: DeviceSnapshot = DeviceSnapshot(),
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        // let all of our tests use America/Montreal.
        let timeZone = TimeZone(identifier: "America/Montreal")!
        
        try XCTAssertEqual(
            AutomatedCampaignsFilter.automatedCampaignsMatching(event: event, forDevice: device, in: self.context!, todayBeing: today, inTimeZone: timeZone),
            matchesCampaigns,
            file: file,
            line: line
        )
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
