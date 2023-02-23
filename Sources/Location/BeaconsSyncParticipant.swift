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

class BeaconsSyncParticipant: PagingSyncParticipant {
    typealias Response = BeaconsSyncResponse
    
    let context: NSManagedObjectContext
    let userDefaults: UserDefaults
    
    var cursorKey: String {
        return "io.rover.RoverLocation.beaconsCursor"
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
        
        return SyncRequest(query: SyncQuery.beacons, values: values)
    }
    
    func insertObject(from node: BeaconsSyncResponse.Data.Beacons.Node) {
        let beacon = Beacon(context: context)
        beacon.id = node.id
        beacon.name = node.name
        beacon.uuid = node.uuid
        beacon.major = node.major
        beacon.minor = node.minor
        beacon.tags = node.tags
    }
}

struct BeaconsSyncResponse: Decodable {
    struct Data: Decodable {
        struct Beacons: Decodable {
            struct Node: Decodable {
                var id: String
                var name: String
                var uuid: UUID
                var major: Int32
                var minor: Int32
                var tags: [String]
            }
            
            var nodes: [Node]?
            var pageInfo: PageInfo
        }
        
        var beacons: Beacons
    }
    
    var data: Data
}

extension BeaconsSyncResponse: PagingResponse {
    var nodes: [Data.Beacons.Node]? {
        return data.beacons.nodes
    }
    
    var pageInfo: PageInfo {
        return data.beacons.pageInfo
    }
}
