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

public protocol EventsClient {
    func sendEvents(with events: [Event]) async -> HTTPResult
}

extension HTTPClient: EventsClient {
    public func sendEvents(with events: [Event]) async -> HTTPResult {
        let request = await self.authContext.authenticateRequest(request: self.uploadRequest())
        
        let payload = EventsPayload(events: events)
        guard let bodyData = self.bodyData(payload: payload) else {
            return HTTPResult.error(error: NoDataError(), isRetryable: false)
        }
        return await self.upload(with: request, from: bodyData)
    }
}

private struct NoDataError: Error { }

private struct EventsPayload {
    var query: String {
        return """
            mutation TrackEvents($events: [Event]!) {
                trackEvents(events:$events)
            }
            """
    }
    
    struct Variables: Encodable {
        var events: [Event]
    }
    
    var variables: Variables
    
    init(events: [Event]) {
        variables = Variables(events: events)
    }
}

extension EventsPayload: Encodable {
    enum CodingKeys: String, CodingKey {
        case query
        case variables
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.query, forKey: .query)
        try container.encode(self.variables, forKey: .variables)
    }
}
