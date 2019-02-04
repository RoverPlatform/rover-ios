//
//  TicketmasterAuthorizer.swift
//  RoverTicketmaster
//
//  Created by Sean Rucker on 2018-09-29.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

/// An API to set and clear Ticketmaster credentials after a user signs in with the [Presence SDK](https://developer.ticketmaster.com/products-and-docs/sdks/presence-sdk/).
public protocol TicketmasterAuthorizer {
    /**
     Set the user's Ticketmaster credentials after a successful sign-in with the [Presence SDK](https://developer.ticketmaster.com/products-and-docs/sdks/presence-sdk/). Implement the `onMemberUpdated(backendName:member:)` method in your `PresenceLoginDelegate` and call this method passing in values from the `PresenceMember`.
     
     - Parameters:
        - accountManagerMemberID: The value of the `PresenceMember`'s `AccountManagerMemberID` property.
        - hostMemberID: The value of the `PresenceMember`'s `HostMemberID` property.
     
     ````
     extension MyViewController: PresenceLoginDelegate {
        func onMemberUpdated(backendName: PresenceLogin.BackendName, member: PresenceMember?) {
            if let pMember = member {
                Rover.shared?.resolve(TicketmasterAuthorizer.self)?.setCredentials(
                    accountManagerMemberID: pMember.AccountManagerMemberID,
                    hostMemberID: pMember.HostMemberID
                )
            }
        }
     }
     ````
     */
    func setCredentials(accountManagerMemberID: String, hostMemberID: String)
    
    /**
     Clear the user's Ticketmaster credentials after a successful sign-out with the [Presence SDK](https://developer.ticketmaster.com/products-and-docs/sdks/presence-sdk/). Implement the `onLogoutAllSuccessful()` method in your `PresenceLoginDelegate` and call this method.
     
     ````
     extension MyViewController: PresenceLoginDelegate {
         //...
         func onLogoutAllSuccessful() {
             Rover.shared?.resolve(TicketmasterAuthorizer.self)?.clearCredentials()
         }
     }
     ````
     */
    func clearCredentials()
}
