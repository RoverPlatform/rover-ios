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

/// An API to set and clear Adobe Experience Platform credentials after a user signs in.
public protocol AdobeExperienceAuthorizer {
    /**
     Set the user's Adobe Experience Platform ECID after a successful sign-in.
     
     - Parameters:
     - ecid: The value of the `ecid` property.
        
      See https://developer.adobe.com/client-sdks/home/base/mobile-core/identity/ for details of the Experience Cloud ID (ECID)
     
     */
    func setECID(_ ecid: String)
    
    /**
     Clear the user's Adobe Experience Platform credentials after a successful sign-out.
     */
    func clearCredentials()
}
