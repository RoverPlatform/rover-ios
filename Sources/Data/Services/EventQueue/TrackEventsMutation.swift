//
//  TrackEventsMutation.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-05-02.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

struct TrackEventsMutation: GraphQLOperation {
    struct Data: Decodable {
        
    }
    
    var operationType: GraphQLOperationType {
        return .mutation
    }
    
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
    
    var variables: Variables?
    
    init(events: [Event]) {
        variables = Variables(events: events)
    }
}
