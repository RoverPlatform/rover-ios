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

public protocol StaticContextProvider: AnyObject {
    var appBadgeNumber: Int { get }
    var appBuild: String { get }
    var appIdentifier: String { get }
    var appVersion: String { get }
    var buildEnvironment: Context.BuildEnvironment { get }
    var deviceIdentifier: String { get }
    var deviceManufacturer: String { get }
    var deviceModel: String { get }
    var deviceName: String { get }
    var operatingSystemName: String { get }
    var operatingSystemVersion: String { get }
    var screenHeight: Double { get }
    var screenWidth: Double { get }
    var sdkVersion: String { get }
}
