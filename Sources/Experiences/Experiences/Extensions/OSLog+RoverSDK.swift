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

private var _roverLog = OSLog(subsystem: "io.rover.RoverSDK", category: "RoverSDK")

extension OSLog {
    static var roverLog: OSLog { _roverLog }
}

private func roverLoggingEnabled() -> Bool {
    ProcessInfo.processInfo.environment["ROVER_VERBOSE"] != nil
}

func rover_log(_ type: OSLogType, _ message: StaticString, _ args: CVarArg...) {
    guard roverLoggingEnabled() || type == .error else {
        return
    }
    
    // lack of splat means this mess:
    switch args.count {
    case 0:
        os_log(message, log: .roverLog, type: type)
    case 1:
        os_log(message, log: .roverLog, type: type, args[0])
    case 2:
        os_log(message, log: .roverLog, type: type, args[0], args[1])
    case 3:
        os_log(message, log: .roverLog, type: type, args[0], args[1], args[2])
    case 4:
        os_log(message, log: .roverLog, type: type, args[0], args[1], args[2], args[3])
    case 5:
        os_log(message, log: .roverLog, type: type, args[0], args[1], args[2], args[3], args[4])
    default:
        os_log(message, log: .roverLog, type: type, args[0], args[1], args[2], args[3], args[4], args[5])
    }
}
