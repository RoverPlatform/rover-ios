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
import RoverFoundation

/// The user info keys the SDK itself understands.
///
/// Integrators sometimes write these keys directly instead of going through the ticketing modules, so core
/// treats them as its own rather than trusting a module to police them.
enum UserInfoKey {
    static let userID = "userID"
    static let ticketmaster = "ticketmaster"
    static let ticketmasterID = "ticketmasterID"
    static let seatGeek = "seatGeek"
    static let seatGeekClientID = "seatGeekClientID"
    static let seatGeekID = "seatGeekID"
    static let axs = "axs"
    static let ecid = "ecid"
}

/// Decides which parts of the stored user info the SDK is allowed to report outward.
///
/// Tracking mode never mutates what is stored: a ticketing ID set while anonymized is kept, simply withheld,
/// and it becomes visible again the moment the host returns to the default mode. Erasing it would need the fan
/// to sign in again, which is not something a transient consent-manager mistake should cost them.
enum UserInfoPrivacy {
    /// Top-level keys withheld from everything that leaves the SDK while tracking mode is not `.default`.
    static let sensitiveKeys: Set<String> = [
        UserInfoKey.ticketmaster,
        UserInfoKey.seatGeek,
        UserInfoKey.axs,
        UserInfoKey.ecid
    ]

    /// The user info to report, given what is stored and the tracking mode. A pure function of its inputs.
    static func reportedUserInfo(
        _ storedUserInfo: [String: Any],
        trackingMode: PrivacyService.TrackingMode
    ) -> [String: Any] {
        guard trackingMode != .default else {
            return storedUserInfo
        }

        return storedUserInfo.filter { !sensitiveKeys.contains($0.key) }
    }

    /// The user info to report, given what is stored and the tracking mode. A pure function of its inputs.
    ///
    /// `Attributes` is a reference type, so a filtered result is always a new object and the stored one is
    /// left alone.
    static func reportedUserInfo(
        _ storedUserInfo: Attributes?,
        trackingMode: PrivacyService.TrackingMode
    ) -> Attributes? {
        guard let storedUserInfo else {
            return nil
        }

        guard trackingMode != .default else {
            return storedUserInfo
        }

        return Attributes(rawValue: storedUserInfo.rawValue.filter { !sensitiveKeys.contains($0.key) })
    }
}
