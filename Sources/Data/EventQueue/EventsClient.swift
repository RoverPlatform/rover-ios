//
//  EventsClient.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-09-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import os.log

public protocol EventsClient {
    func task(with events: [Event], completionHandler: @escaping (HTTPResult) -> Void) -> URLSessionTask
}

extension HTTPClient: EventsClient {
    public func task(with events: [Event], completionHandler: @escaping (HTTPResult) -> Void) -> URLSessionTask {
        let request = self.uploadRequest()
        let payload = EventsPayload(events: events)
        let bodyData = self.bodyData(payload: payload)
        return self.uploadTask(with: request, from: bodyData, completionHandler: completionHandler)
    }
}

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
