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
     Set the user's Ticketmaster credentials after a successful sign-in with the Presence SDK. Note that this method is deprecated: use setCredentials(id:,email:,firstName:) instead.
     */
    @available(*, deprecated, message: "Use setCredentials(id:,email:,firstName:) instead.")
    func setCredentials(accountManagerMemberID: String, hostMemberID: String)
    
    /**
     Set the user's Ticketmaster credentials after a successful sign-in with the [Presence SDK](https://developer.ticketmaster.com/products-and-docs/sdks/presence-sdk/). Implement the `onMemberUpdated(backendName:member:)` method in your `PresenceLoginDelegate` and call this method passing in values from the `PresenceMember`.
     
     - Parameters:
     - id: The value of the `PresenceMember`'s `id` property.
     - email: The value of the `PresenceMember`'s `email` property (optional).
     - firstName: The value of the `PresenceMember`'s `firstName` property (optional).
     
     ````
     extension MyViewController: PresenceLoginDelegate {
         func onMemberUpdated(backendName: PresenceLogin.BackendName, member: PresenceMember?) {
             if let pMember = member {
                 Rover.shared?.resolve(TicketmasterAuthorizer.self)?.setCredentials(
                     id: pMember.id,
                     email: pMember.email,
                     firstName: pMember.firstName
                 )
             }
         }
     }
     ````
     */
    func setCredentials(id: String, email: String?, firstName: String?)
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
