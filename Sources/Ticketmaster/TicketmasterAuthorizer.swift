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

/// An API to set and clear Ticketmaster credentials after a user signs in with the [Presence SDK](https://developer.ticketmaster.com/products-and-docs/sdks/presence-sdk/).
public protocol TicketmasterAuthorizer {        
    /**
     Set the user's Ticketmaster credentials after a successful sign-in with the [Presence SDK](https://developer.ticketmaster.com/products-and-docs/sdks/presence-sdk/). Implement the `onMemberUpdated(backendName:member:)` method in your `PresenceLoginDelegate` and call this method passing in values from the `PresenceMember`.
     
     - Parameters:
     - id: The value of the `PresenceMember`'s `id` property.
     
     ````
     extension MyViewController: PresenceLoginDelegate {
         func onMemberUpdated(backendName: PresenceLogin.BackendName, member: PresenceMember?) {
             if let pMember = member {
                 Rover.shared.ticketmasterAuthorizer.setTicketmasterID(pMember.id)
             }
         }
     }
     ````
     */
    func setTicketmasterID(_ id: String)
    /**
     Clear the user's Ticketmaster credentials after a successful sign-out with the [Presence SDK](https://developer.ticketmaster.com/products-and-docs/sdks/presence-sdk/). Implement the `onLogoutAllSuccessful()` method in your `PresenceLoginDelegate` and call this method.
     
     ````
     extension MyViewController: PresenceLoginDelegate {
         //...
         func onLogoutAllSuccessful() {
             Rover.shared.ticketmasterAuthorizer.clearCredentials()
         }
     }
     ````
     */
    func clearCredentials()
}
