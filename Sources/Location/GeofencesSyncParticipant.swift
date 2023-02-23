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

import CoreData
import os.log
import RoverFoundation
import RoverData

class GeofencesSyncParticipant: PagingSyncParticipant {
    typealias Response = GeofencesSyncResponse
    
    let context: NSManagedObjectContext
    let userDefaults: UserDefaults
    
    var cursorKey: String {
        return "io.rover.RoverLocation.geofencesCursor"
    }
    
    var participants = [SyncParticipant]()
    
    init(context: NSManagedObjectContext, userDefaults: UserDefaults) {
        self.context = context
        self.userDefaults = userDefaults
    }
    
    func nextRequest(cursor: String?) -> SyncRequest {
        let orderBy: Attributes = [
            "field": "UPDATED_AT",
            "direction": "ASC"
        ]
        
        var values: [String: Any] = [
            "first": 500,
            "orderBy": orderBy
        ]
        
        if let cursor = cursor {
            values["after"] = cursor
        }
        
        return SyncRequest(query: SyncQuery.geofences, values: values)
    }

    func insertObject(from node: GeofencesSyncResponse.Data.Geofences.Node) {
        let geofence = Geofence(context: context)
        geofence.id = node.id
        geofence.name = node.name
        geofence.latitude = node.center.latitude
        geofence.longitude = node.center.longitude
        geofence.radius = node.radius
        geofence.tags = node.tags
    }
}

// MARK: GeofencesSyncResponse

struct GeofencesSyncResponse: Decodable {
    struct Data: Decodable {
        struct Geofences: Decodable {
            struct Node: Decodable {
                struct Center: Decodable {
                    var latitude: Double
                    var longitude: Double
                }
                
                var id: String
                var name: String
                var center: Center
                var radius: Double
                var tags: [String]
            }
            
            var nodes: [Node]?
            var pageInfo: PageInfo
        }
        
        var geofences: Geofences
    }
    
    var data: Data
}

extension GeofencesSyncResponse: PagingResponse {
    var nodes: [Data.Geofences.Node]? {
        return data.geofences.nodes
    }
    
    var pageInfo: PageInfo {
        return data.geofences.pageInfo
    }
}
