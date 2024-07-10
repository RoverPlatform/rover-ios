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

import TicketmasterDiscoveryAPI
import TicketmasterPurchase
import TicketmasterTickets

public protocol TicketmasterAnalytics {
    /**
     Post an event from the Ticketmaster [Ignite SDK ](https://ignite.ticketmaster.com/v1/docs/analytics-ios-1) for use with Rover.  This method should be called from the `TMTicketsAnalyticsDelegate` method `userDidView(page:metadata:)`.
     
     ````
     extension MyViewController: TMTicketsAnalyticsDelegate {
         //...
     func userDidView(
        page: TMTickets.Analytics.Page,
        metadata: TMTickets.Analytics.MetadataType
     ) {
        Rover.shared.ticketmasterAnalytics.postTicketmasterEvent(
            page: page,
            metadata: metadata
        )
     }
     ````
     */
    func postTicketmasterScreenViewed(page: TMTickets.Analytics.Page, metadata: TMTickets.Analytics.MetadataType)
    
    /**
     Post an event from the Ticketmaster [Ignite SDK ](https://ignite.ticketmaster.com/v1/docs/analytics-ios-1) for use with Rover.  This method should be called from the `TMTicketsAnalyticsDelegate` method `userDidPerform(action:metadata:)`.
     
     ````
     extension MyViewController: TMTicketsAnalyticsDelegate {
         //...
     func userDidPerform(
        action: TMTickets.Analytics.Action,
        metadata: TMTickets.Analytics.MetadataType
     ) {
        Rover.shared.ticketmasterAnalytics.postTicketmasterAction(
            action: action,
            metadata: metadata
        )
     }
     ````
     */
    func postTicketmasterAction(action: TMTickets.Analytics.Action, metadata: TMTickets.Analytics.MetadataType)
    
    /**
     Post an event from the Ticketmaster [Ignite SDK ](https://ignite.ticketmaster.com/docs/set-up-analytics) for use with Rover.  This method should be called from the `TMPurchaseUserAnalyticsDelegate` method `purchaseNavigationController(_ purchaseNavigationController: TMPurchaseNavigationController, didBeginCheckoutFor event: DiscoveryEvent)`.
     
     ````
     extension MyViewController: TMPurchaseUserAnalyticsDelegate {
         //...
     func purchaseNavigationController(
        _ purchaseNavigationController: TMPurchaseNavigationController,
        didBeginCheckoutFor event: DiscoveryEvent
     ) {
        Rover.shared.ticketmasterAnalytics.didBeginCheckout(for: event)
     }
     ````
     */
    func didBeginCheckout(for event: DiscoveryEvent)
    
    /**
     Post an event from the Ticketmaster [Ignite SDK ](https://ignite.ticketmaster.com/docs/set-up-analytics) for use with Rover.  This method should be called from the `TMPurchaseUserAnalyticsDelegate` method `purchaseNavigationController(_ purchaseNavigationController: TMPurchaseNavigationController, didEndCheckoutFor event: DiscoveryEvent, because reason: TMEndCheckoutReason)`.
     
     ````
     extension MyViewController: TMPurchaseUserAnalyticsDelegate {
         //...
     func purchaseNavigationController(
        _ purchaseNavigationController: TMPurchaseNavigationController,
        didEndCheckoutFor event: DiscoveryEvent,
        because reason: TMEndCheckoutReason
     ) {
        Rover.shared.ticketmasterAnalytics.didEndCheckout(for: event, because: reason)
     }
     ````
     */
    func didEndCheckout(for event: DiscoveryEvent, because reason: TMEndCheckoutReason)
    
    /**
     Post an event from the Ticketmaster [Ignite SDK ](https://ignite.ticketmaster.com/docs/set-up-analytics) for use with Rover.  This method should be called from the `TMPurchaseUserAnalyticsDelegate` method `purchaseNavigationController(_ purchaseNavigationController: TMPurchaseNavigationController, didBeginTicketSelectionFor event: DiscoveryEvent)`.
     
     ````
     extension MyViewController: TMPurchaseUserAnalyticsDelegate {
         //...
     func purchaseNavigationController(
        _ purchaseNavigationController: TMPurchaseNavigationController,
        didBeginTicketSelectionFor event: DiscoveryEvent
     ) {
        Rover.shared.ticketmasterAnalytics.didBeginTicketSelection(for: event)
     }
     ````
     */
    func didBeginTicketSelection(for event: DiscoveryEvent)
    
    /**
     Post an event from the Ticketmaster [Ignite SDK ](https://ignite.ticketmaster.com/docs/set-up-analytics) for use with Rover.  This method should be called from the `TMPurchaseUserAnalyticsDelegate` method `purchaseNavigationController(_ purchaseNavigationController:TMPurchaseNavigationController, didEndTicketSelection event: DiscoveryEvent, because reason: TMEndTicketSelectionReason)`.
     
     ````
     extension MyViewController: TMPurchaseUserAnalyticsDelegate {
         //...
     func purchaseNavigationController(
        _ purchaseNavigationController: TMPurchaseNavigationController,
        didEndTicketSelectionFor event: DiscoveryEvent,
        because reason: TMEndTicketSelectionReason
     ) {
        Rover.shared.ticketmasterAnalytics.didEndTicketSelection(for: event, because: reason)
     }
     ````
     */
    func didEndTicketSelection(for event: DiscoveryEvent, because reason: TMEndTicketSelectionReason)
}
