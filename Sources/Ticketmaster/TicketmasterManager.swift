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

import Foundation
import os.log
import RoverFoundation
import RoverData

class TicketmasterManager {
    private let userInfoManager: UserInfoManager
    private let eventQueue: EventQueue
    
    struct Member: Codable {
        var id: String
        var email: String?
        var firstName: String?
        
        /// Return the basic UserInfo dictionary for ticketmaster given just the locally known data.
        var userInfo: [String: String] {
            return ["ticketmasterID": id]
        }
    }
    
    var member = PersistedValue<Member>(storageKey: "io.rover.RoverTicketmaster")
    
    struct LegacyMember: Codable {
        var hostID: String
        var teamID: String
    }
    var legacyMember = PersistedValue<LegacyMember>(storageKey: "io.rover.RoverTicketmaster")
    
    init(userInfoManager: UserInfoManager, eventQueue: EventQueue) {
        self.userInfoManager = userInfoManager
        self.eventQueue = eventQueue
        
        // do migration from 3.2 and older, if needed.
        if let legacyData = legacyMember.value, member.value == nil {
            if !legacyData.hostID.isEmpty {
                member.value = Member(id: legacyData.hostID, email: nil, firstName: nil)
                os_log("Migrated Ticketmaster data for TM member: %s", log: .general, legacyData.hostID)
            } else if !legacyData.teamID.isEmpty {
                member.value = Member(id: legacyData.teamID, email: nil, firstName: nil)
                os_log("Migrated Ticketmaster data for Archtics member: %s", log: .general, legacyData.teamID)
            } else {
                os_log("Unable to migrate TM data for either type, since neither was present. Ignoring.", log: .general)
                member.value = nil
            }
        }
        
        // Begin observing for TM PSDK's events.
        TicketmasterManager.tmEvents.keys.forEach { notificationName in
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.receiveTicketmasterNotification),
                name: NSNotification.Name(rawValue: notificationName),
                object: nil
            )
        }
    }
    
    @objc
    func receiveTicketmasterNotification(_ notification: Foundation.Notification) {
        guard let roverScreenName = TicketmasterManager.tmEvents[notification.name.rawValue] else {
            os_log("TicketmasterManager received an unexpected NSNotification, ignoring.", log: .general, type: .error)
            return
        }
        
        let attributes: Attributes = ["screenName": roverScreenName]
        
        // the same fields are common amongst all the events we monitor for.
        let eventAttributes: Attributes = [:]
        let venueAttributes: Attributes = [:]
        let artistAttributes: Attributes = [:]
        
        if let eventID = notification.userInfo?["event_id"] {
            eventAttributes["id"] = eventID
        }
        
        if let eventName = notification.userInfo?["event_name"] {
            eventAttributes["name"] = eventName
        }

        if let eventDate = notification.userInfo?["event_date"] as? Date {
            // In order to be (somewhat) consistent with the Android version of the Presence SDK (which yields a pre-rendered date string in a non-standard format), render it into the following format:
            // Mon, Apr 13, 7:00 PM
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.setLocalizedDateFormatFromTemplate("E, MMM d, h:mm a")
            eventAttributes["date"] = formatter.string(from: eventDate)
        }
        
        if let eventImageURL = notification.userInfo?["event_image_url"] {
            eventAttributes["imageURL"] = eventImageURL
        }
        
        if let venueName = notification.userInfo?["venue_name"] {
            venueAttributes["name"] = venueName
        }
        
        if let venueID = notification.userInfo?["venue_id"] {
            venueAttributes["id"] = venueID
        }
        
        if let currentTicketCount = notification.userInfo?["current_ticket_count"] {
            attributes["currentTicketCount"] = currentTicketCount
        }
        
        if let artistName = notification.userInfo?["artist_name"] ?? notification.userInfo?["atrist_name"] /* [sic] */ {
            artistAttributes["name"] = artistName
        }
        
        if let artistID = notification.userInfo?["artist_id"] {
            artistAttributes["id"] = artistID
        }
        
        if !eventAttributes.rawValue.isEmpty {
            attributes["event"] = eventAttributes
        }
        if !venueAttributes.rawValue.isEmpty {
            attributes["venue"] = venueAttributes
        }
        if !artistAttributes.rawValue.isEmpty {
            attributes["artist"] = artistAttributes
        }
        
        let eventInfo = EventInfo(name: "Screen Viewed", namespace: "ticketmaster", attributes: attributes)
        
        eventQueue.addEvent(eventInfo)
    }
    
    private static let tmEvents = [
        "TMX_MYTICKETSCREENSHOWED": "My Tickets",
        "TMX_MANAGETICKETSCREENSHOWED": "Manage Ticket",
        "TMX_ADDPAYMENTINFOSCREENSHOWED": "Add Payment Info",
        "TMX_MYTICKETBARCODESCREENSHOWED": "Ticket Barcode",
        "TMX_TICKETDETAILSSCREENSHOWED": "Ticket Details"
    ]
}

// MARK: TicketmasterAuthorizer

extension TicketmasterManager: TicketmasterAuthorizer {
    func setTicketmasterID(_ id: String) {
        let newMember = Member(id: id, email: nil, firstName: nil)
        self.member.value = newMember
        
        // As a side-effect, set the fields into the `ticketmaster` hash in userInfo so they are immediately available even without a server sync succeeding.
        self.userInfoManager.updateUserInfo {
            if let existingTicketmasterUserInfo = $0.rawValue["ticketmaster"] as? Attributes {
                // ticketmaster already exists, just clobber the two fields:
                $0.rawValue["ticketmaster"] = Attributes(rawValue: existingTicketmasterUserInfo.rawValue.merging(newMember.userInfo) { $1 })
            } else {
                // ticketmaster data does not already exist, so set it:
                $0.rawValue["ticketmaster"] = Attributes(rawValue: newMember.userInfo)
            }
        }
        
        os_log("Ticketmaster member identity has been set: %s", log: .general, newMember.email ?? "none")
    }
    
    func clearCredentials() {
        self.member.value = nil
        self.userInfoManager.updateUserInfo { attributes in
            attributes.rawValue["ticketmaster"] = nil
        }
    }
}

// MARK: SyncParticipant

extension SyncQuery {
    static let ticketmaster = SyncQuery(
        name: "ticketmasterProfile",
        body: """
            attributes
            """,
        arguments: [
            SyncQuery.Argument(name: "id", type: "String")
        ],
        fragments: []
    )
}

extension TicketmasterManager: SyncParticipant {
    func initialRequest() -> SyncRequest? {
        guard let member = self.member.value else {
            return nil
        }
        
        return SyncRequest(
            query: .ticketmaster,
            values: [
                "id": member.id,
            ]
        )
    }
    
    struct Response: Decodable {
        struct Data: Decodable {
            struct Profile: Decodable {
                var attributes: Attributes?
            }
            
            var ticketmasterProfile: Profile
        }
        
        var data: Data
    }
    
    func saveResponse(_ data: Data) -> SyncResult {
        let response: Response
        do {
            response = try JSONDecoder.default.decode(Response.self, from: data)
        } catch {
            os_log("Failed to decode response: %@", log: .sync, type: .error, error.logDescription)
            return .failed
        }
        
        guard let attributes = response.data.ticketmasterProfile.attributes else {
            return .noData
        }
        
        let localAttributes: [String: Any] = member.value?.userInfo ?? [String: Any]()
        
        // Set the `ticketmaster` field on userInfo, but clobber the email and firstName fields that might have come back from the server with our local values.
        self.userInfoManager.updateUserInfo {
            $0.rawValue["ticketmaster"] = Attributes(rawValue: localAttributes.merging(attributes.rawValue) { (localValue, _) in localValue })
        }
        
        return .newData(nextRequest: nil)
    }
}
