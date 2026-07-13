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

import os
import os.log

extension OSLog {
    public static let experiences = OSLog(subsystem: "io.rover", category: "Experiences")

    /// Experiences V3 App Screens. Internal so it adds no new public symbol.
    static let appScreens = OSLog(subsystem: "io.rover", category: "AppScreens")
}

/// Instruments signposter for App Screens. Emits interval signposts for the
/// headline spans (navigate→reveal, document fetch, json fetch, recover) so the
/// pipeline can be profiled in Instruments' os_signpost track alongside the
/// `OSLog.appScreens` headline numbers. Internal — adds no public symbol; cheap
/// and side-effect-free when the tool is not recording.
let appScreensSignposter = OSSignposter(subsystem: "io.rover", category: "AppScreens")
