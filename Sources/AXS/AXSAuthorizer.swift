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

/// An API to set and clear AXS credentials after a user signs in.
public protocol AXSAuthorizer {
    /**
     Set the user's AXS credentials after a successful sign-in.
     
     - Parameter userId: The value of the `userID` property.
     */
    @available(*, deprecated, renamed: "setUserID")
    func setUserId(_ userId: String)

    /**
     Set the user's AXS credentials after a successful sign-in. If `userID` is nil, then it is treated as a sign out.

     - Parameter userID: The value of the `userID` property.
     - Parameter flashMemberID: A Flash Seats Member ID.
     - Parameter flashMobileID: A Flash Seats Mobile ID.
     */
    func setUserID(_ userID: String?, flashMemberID: String?, flashMobileID: String?)

    /**
     Clear the user's AXS credentials after a successful sign-out.
     */
    func clearCredentials()
}

