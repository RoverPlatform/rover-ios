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

import TicketmasterTickets

/// An API to set and clear Ticketmaster credentials after a user signs in with the [Ignite SDK](https://ignite.ticketmaster.com/docs/ignite-overview).
public protocol TicketmasterAuthorizer {
    /**
     Set the user's Ticketmaster credentials after a successful sign-in with the [Ignite SDK](https://ignite.ticketmaster.com/docs/ignite-overview).  Implement the `onStateChanged(backend:state: .loginCompleted, error:)` method in your `TMAuthenticationDelegate`, then call `TMAuthetication.shared.memberInfo` and call this method passing in the `localID` value from the `MemberInfo`.
     
     - Parameters:
     - id: The value of the `MemberInfo`'s `localID` property.
     
     ````
     extension MyViewController: TMAuthenticationDelegate {
         //...
     func onStateChanged(
         backend: TMAuthentication.BackendService?,
         state: TMAuthentication.ServiceState,
         error: Error?
     ) {
        // ...
        switch state {
            // ...
            case .loginCompleted:
                TMAuthentication.shared.memberInfo { memberInfo in
                    Rover.sharedticketmasterAuthorizer.setTicketmasterID(memberInfo.localID)
                } failure: { oldMemberInfo, error, backend in
                    print("MemberInfo Error: \(error.localizedDescription)")
                }
        }
     }
     ````
     */
    func setTicketmasterID(_ id: String)
    
    /**
     Clear the user's Ticketmaster credentials after a successful sign-out with the [Ignite SDK](https://ignite.ticketmaster.com/v1/docs/analytics-ios-1). Implement the `onStateChanged(backend:state: .loggedOut, error:)` method in your `TMAuthenticationDelegate` and call this method.
     
     ````
     extension MyViewController: TMAuthenticationDelegate {
         //...
     func onStateChanged(
         backend: TMAuthentication.BackendService?,
         state: TMAuthentication.ServiceState,
         error: Error?
     ) {
        // ...
        switch state {
            // ...
            case .loggedOut:
                Rover.shared.ticketmasterAuthorizer.clearCredentials()
        }
     }
     ````
     */
    func clearCredentials()
}
