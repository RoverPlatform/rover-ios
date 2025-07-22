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
import TicketmasterTickets
import TicketmasterPurchase
import TicketmasterDiscoveryAPI

class TicketmasterManager: PrivacyListener {
    private let userInfoManager: UserInfoManager
    private let privacyService: PrivacyService
    
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
    
    init(userInfoManager: UserInfoManager, eventQueue: EventQueue, privacyService: PrivacyService) {
        self.userInfoManager = userInfoManager
        self.eventQueue = eventQueue
        self.privacyService = privacyService
    }
    
    private static let tmActions = [
        "addTicketToWalletButton": "Add Ticket To Wallet Button Tapped",
        "barcodeScreenshot": "Barcode Screenshot Taken",
        "transferSendButton": "Ticket Transfer Send Button Tapped",
        "transferCancelButton": "Ticket Transfer Cancel Button Tapped"
    ]
    
    private static let tmPages = [
        "eventTickets": "My Tickets",
        "events": "Events",
        "eventModules": "Event Modules",
        "ticketBarcode": "Ticket Barcode",
        "ticketDelivery": "Ticket Delivery",
        "ticketDetails": "Ticket Details",
    ]

}

// MARK: TicketmasterAuthorizer

extension TicketmasterManager: TicketmasterAuthorizer {
    func setTicketmasterID(_ id: String) {
        guard self.privacyService.trackingMode == .default else {
            os_log("Ticketmaster ID set while privacy is in anonymous/anonymized mode, ignored", log: .ticketmaster, type: .info)
            return
        }
        
        let newMember = Member(id: id, email: nil, firstName: nil)
        self.member.value = newMember
        
        self.userInfoManager.updateUserInfo {
            if let existingTicketmasterUserInfo = $0.rawValue["ticketmaster"] as? Attributes {
                // ticketmaster already exists, just clobber the two fields:
                $0.rawValue["ticketmaster"] = Attributes(rawValue: existingTicketmasterUserInfo.rawValue.merging(newMember.userInfo) { $1 })
            } else {
                // ticketmaster data does not already exist, so set it:
                $0.rawValue["ticketmaster"] = Attributes(rawValue: newMember.userInfo)
            }
        }
        
        os_log("Ticketmaster member identity has been set", log: .general)
    }
    
    func clearCredentials() {
        self.member.value = nil
        self.userInfoManager.updateUserInfo { attributes in
            attributes.rawValue["ticketmaster"] = nil
        }
    }
    
    // MARK: Privacy
    
    func trackingModeDidChange(_ trackingMode: PrivacyService.TrackingMode) {
        if(trackingMode != .default) {
            os_log("Tracking disabled, Ticketmaster data cleared.", log: .ticketmaster)
            clearCredentials()
        }
    }
}

extension TicketmasterManager: TicketmasterAnalytics {
    func postTicketmasterScreenViewed(page: TMTickets.Analytics.Page, metadata: TMTickets.Analytics.MetadataType) {
        guard self.privacyService.trackingMode == .default else {
            return
        }
        
        guard let roverPageName = TicketmasterManager.tmPages[page.rawValue] else {
            os_log("TicketmasterManager received an unexpected page name, ignoring.", log: .general, type: .debug)
            return
        }
        
        switch metadata {
        case .events(let events):
            for event in events {
                eventQueue.addEvent(event.roverEvent(screenName: roverPageName))
            }
            
        case .event(let event):
            eventQueue.addEvent(event.roverEvent(screenName: roverPageName))
            
        default:
            return
        }
    }
    
    func postTicketmasterAction(action: TMTickets.Analytics.Action, metadata: TMTickets.Analytics.MetadataType) {
        guard self.privacyService.trackingMode == .default else {
            return
        }
        
        guard let roverActionName = TicketmasterManager.tmActions[action.rawValue] else {
            os_log("TicketmasterManager received an unexpected action name, ignoring.", log: .general, type: .debug)
            return
        }
        
        switch metadata {
        case .events(let events):
            for event in events {
                eventQueue.addEvent(event.roverEvent(actionName: roverActionName))
            }
            
        case .event(let event):
            eventQueue.addEvent(event.roverEvent(actionName: roverActionName))
            
        case .eventTicket(let event, _):
            eventQueue.addEvent(event.roverEvent(actionName: roverActionName))
            
        case .eventTickets(let event, _):
            eventQueue.addEvent(event.roverEvent(actionName: roverActionName))
            
        default:
            return
        }
    }
    
    func didBeginCheckout(for event: DiscoveryEvent) {
        guard self.privacyService.trackingMode == .default else {
            return
        }
        
        eventQueue.addEvent(event.roverEvent("Did Begin Checkout"))
    }
    
    func didEndCheckout(for event: DiscoveryEvent, because reason: TMEndCheckoutReason) {
        guard self.privacyService.trackingMode == .default else {
            return
        }
        
        eventQueue.addEvent(event.roverEvent("Did End Checkout", reason: reason.rawValue))
    }
    
    func didBeginTicketSelection(for event: DiscoveryEvent) {
        guard self.privacyService.trackingMode == .default else {
            return
        }
        
        eventQueue.addEvent(event.roverEvent("Did Begin Ticket Selection"))
    }
    
    func didEndTicketSelection(for event: DiscoveryEvent, because reason: TMEndTicketSelectionReason) {
        guard self.privacyService.trackingMode == .default else {
            return
        }
        
        eventQueue.addEvent(event.roverEvent("Did End Ticket Selection", reason: reason.rawValue))
    }
}

fileprivate extension TMPurchasedEvent {
    func roverEvent(actionName: String) -> EventInfo {
        let attributes = roverAttributes()
        
        return EventInfo(
            name: actionName,
            namespace: "ticketmaster",
            attributes: attributes
        )
    }
    
    
    func roverEvent(screenName: String) -> EventInfo {
        let attributes = roverAttributes()
        
        attributes["screenName"] = screenName
        
        return EventInfo(
            name: "Screen Viewed",
            namespace: "ticketmaster",
            attributes: attributes
        )
    }
    
    func roverAttributes() -> Attributes {
        let attributes: Attributes = Attributes()
        var currentTicketCount: Int = 0
        
        if let orders = self.orders {
            for order in orders {
                currentTicketCount += order.tickets.count
            }
        }
        
        var eventAttributes = ["id": self.info.identifier,
                               "name": self.info.name,
                               "imageUrl": self.info.imageInfo?.url?.absoluteString,
                               "currentTicketCount": currentTicketCount]
            .compactMapValues { $0 }
        
        if let eventDate = self.info.dateInfo?.dateTimeUTC as? Date {
            // In order to be (somewhat) consistent with the Android version of the Presence SDK (which yields a pre-rendered date string in a non-standard format), render it into the following format:
            // Mon, Apr 13, 7:00 PM
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.setLocalizedDateFormatFromTemplate("E, MMM d, h:mm a")
            eventAttributes["date"] = formatter.string(from: eventDate)
        }
        
        let venueAttributes = ["name": self.info.venue?.name,
                               "id": self.info.venue?.identifier]
            .compactMapValues { $0 }
        
        if !eventAttributes.isEmpty {
            attributes["event"] = Attributes(rawValue: eventAttributes)
        }
        
        if !venueAttributes.isEmpty {
            attributes["venue"] = Attributes(rawValue: venueAttributes)
        }
        
        return attributes
    }
}

fileprivate extension DiscoveryEvent {
    func roverEvent(_ eventName: String, reason: String? = nil) -> EventInfo {
        let attributes: Attributes = [:]
        
        if let reason = reason {
            attributes["reason"] = reason
        }
        
        let eventAttributes = ["id": self.eventIdentifier.rawValue,
                               "name": self.name,
                               "imageUrl": self.imageMetadataArray.first?.url.absoluteString,
                               "type": self.type]
            .compactMapValues { $0 }
        
        let venueAttributes = ["name": self.venueArray.first?.name,
                               "id": self.venueArray.first?.venueIdentifier.rawValue]
            .compactMapValues { $0 }
        
        if !eventAttributes.isEmpty {
            attributes["event"] = Attributes(rawValue: eventAttributes)
        }
        
        if !venueAttributes.isEmpty {
            attributes["venue"] = Attributes(rawValue: venueAttributes)
        }

        return EventInfo(
            name: eventName,
            namespace: "ticketmaster",
            attributes: attributes
        )
    }
}
