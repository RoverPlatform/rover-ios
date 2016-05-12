//
//  Mappables.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-28.
//
//

import Foundation
import CoreLocation

extension CLRegion : Mappable {
    static func instance(JSON: [String: AnyObject], included: [String: Any]?) -> CLRegion? {
        guard let type = JSON["type"] as? String,
            identifier = JSON["id"] as? String,
            attributes = JSON["attributes"] as? [String: AnyObject] else { return nil }
        
        switch type {
        case "ibeacon-regions":
            guard let uuidString = attributes["uuid"] as? String, uuid = NSUUID(UUIDString: uuidString) else { return nil }
            
            let major = attributes["major-number"] as? Int
            let minor = attributes["minor-number"] as? Int
            
            if major != nil && minor != nil {
                return CLBeaconRegion(proximityUUID: uuid, major: CLBeaconMajorValue(major!), minor: CLBeaconMinorValue(minor!), identifier: identifier)
            } else if major != nil {
                return CLBeaconRegion(proximityUUID: uuid, major: CLBeaconMajorValue(major!), identifier: identifier)
            } else {
                return CLBeaconRegion(proximityUUID: uuid, identifier: identifier)
            }
        case "geofence-regions":
            guard let latitude = attributes["latitude"] as? CLLocationDegrees, longitude = attributes["longitude"] as? CLLocationDegrees, radius = attributes["radius"] as? CLLocationDistance else { return nil }
            return CLCircularRegion(center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), radius: radius, identifier: identifier)
        default:
            // invalid type
            return nil
        }
        
    }
}

extension Event : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String: Any]?) -> Event? {
        guard let type = JSON["type"] as? String,
            attributes = JSON["attributes"] as? [String: AnyObject],
            object = attributes["object"] as? String,
            action = attributes["action"] as? String,
            date = included?["date"] as? NSDate
            where type == "events" else { return nil }
        
        switch (object, action) {
        case ("app", "open"):
            return nil
        case ("location", "update"):
            guard let
                location = included?["location"] as? CLLocation else { return nil }
            
            return Event.DidUpdateLocation(location, date: date)
        case ("beacon-region", let action):
            guard let
                config = attributes["configuration"] as? [String: AnyObject],
                beaconConfig = BeaconConfiguration.instance(config, included: nil),
                beaconRegion = included?["region"] as? CLBeaconRegion else { return nil }
            
            var location: Location?
            if let locationAttributes = attributes["location"] as? [String: AnyObject] {
                location = Location.instance(locationAttributes, included: nil)
            }
            
            switch action {
            case "enter":
                return Event.DidEnterBeaconRegion(beaconRegion, config: beaconConfig, location: location, date: date)
            case "exit":
                return Event.DidExitBeaconRegion(beaconRegion, config: beaconConfig, location: location, date: date)
            default:
                return nil
            }
        case ("geofence-region", let action):
            guard let
                locationJSON = attributes["location"] as? [String: AnyObject],
                location = Location.instance(locationJSON, included: nil),
                circularRegion = included?["region"] as? CLCircularRegion else { return nil }
            
            switch action {
            case "enter":
                return Event.DidEnterCircularRegion(circularRegion, location: location, date: date)
            case "exit":
                return Event.DidExitCircularRegion(circularRegion, location: location, date: date)
            default:
                return nil
            }
        default:
            return nil
        }
    }
}

extension BeaconConfiguration : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String: Any]?) -> BeaconConfiguration? {
        guard let
            uuidString = JSON["uuid"] as? String,
            uuid = NSUUID(UUIDString: uuidString),
            name = JSON["name"] as? String,
            tags = JSON["tags"] as? [String] else { return nil }
        
        var majorNumber: CLBeaconMajorValue?
        if let major = JSON["major-number"] as? Int { majorNumber = CLBeaconMajorValue(major) }
        
        var minorNumber: CLBeaconMinorValue?
        if let minor = JSON["minor-number"] as? Int { minorNumber = CLBeaconMinorValue(minor) }
        
        return BeaconConfiguration(name: name, UUID: uuid, majorNumber: majorNumber, minorNumber: minorNumber, tags: tags)
    }
}

extension Location : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Location? {
        guard let
            latitude = JSON["latitude"] as? CLLocationDegrees,
            longitude = JSON["longitude"] as? CLLocationDegrees,
            radius = JSON["radius"] as? CLLocationDistance,
            name = JSON["name"] as? String,
            tags = JSON["tags"] as? [String] else { return nil }
        
        return Location(coordinates: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), radius: radius, name: name, tags: tags)
    }
}

extension Message : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Message? {
        guard let type = JSON["type"] as? String,
            identifier = JSON["id"] as? String,
            attributes = JSON["attributes"] as? [String: AnyObject],
            title = attributes["ios-title"] as? String?,
            timestampString = attributes["timestamp"] as? String,
            timestamp = rvDateFormatter.dateFromString(timestampString),
            text = attributes["notification-text"] as? String
            where type == "messages" else { return nil }
        
        
        
        let message = Message(title: title, text: text, timestamp: timestamp, identifier: identifier)

        message.read = attributes["read"] as? Bool ?? false
        
        if let action = attributes["content-type"] as? String {
            switch action {
            case "website":
                message.action = .Link
                // TODO: this can throw, needs to be safer
                if let url = attributes["website-url"] as? String {
                    message.url = NSURL(string: url)
                }
            case "landing-page":
                message.action = .LandingPage
                
                if let landingPageAttributes = attributes["landing-page"] as? [String: AnyObject] {
                    message.landingPage = Screen.instance(landingPageAttributes, included: nil)
                }
            default:
                message.action = .None
            }
        }

        
        return message
    }
}

extension Screen : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Screen? {
        guard let rowsAttributes = JSON["rows"] as? [[String : AnyObject]],
            rows = rowsAttributes.map({ Row.instance($0, included: nil) }) as? [Row] else { return nil }
        
        let screen = Screen(rows: rows)
        screen.title = JSON["title"] as? String
        
        return screen
    }
}

extension Row : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Row? {
        guard let blocksAttributes = JSON["blocks"] as? [[String : AnyObject]],
            blocks = blocksAttributes.map({ Block.instance($0, included: nil) }) as? [Block] else { return nil }
        
        let row = Row(blocks: blocks)
        row.height = Unit.instance(JSON["height"] as? [String: AnyObject] ?? [:], included: nil)
        
        return row
    }
}

extension Block : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Block? {
        guard let type = JSON["type"] as? String else { return nil }
        
        var block: Block
        
        switch type {
        case "image-block":
            block = ImageBock()
        case "text-block":
            block = TextBlock()
            
            let textBlock = block as! TextBlock
            textBlock.text = JSON["text"] as? String
        case "button-block":
            block = ButtonBlock()
            
            let buttonBlock = block as! ButtonBlock
            buttonBlock.title = JSON["title-text"] as? String
            buttonBlock.titleColor = UIColor.instance(JSON["title-color"] as? [String: AnyObject] ?? [:], included: nil)
            buttonBlock.titleOffset = Offset.instance(JSON["title-offset"] as? [String: AnyObject] ?? [:], included: nil)
            buttonBlock.titleAlignment = Alignment.instance(JSON["title-alignment"] as? [String: AnyObject] ?? [:], included: nil)
        default:
            return nil
        }
        
        block.width = Unit.instance(JSON["width"] as? [String: AnyObject] ?? [:], included: nil)
        block.height = Unit.instance(JSON["height"] as? [String: AnyObject] ?? [:], included: nil)
        block.position = Block.Position(rawValue: JSON["layout"] as? String ?? "stacked")
        block.alignment = Alignment.instance(JSON["alignment"] as? [String: AnyObject] ?? [:], included: nil)
        block.offset = Offset.instance(JSON["offset"] as? [String: AnyObject] ?? [:], included: nil)
        block.backgroundColor = UIColor.instance(JSON["background-color"] as? [String: AnyObject] ?? [:], included: nil)
        block.borderColor = UIColor.instance(JSON["border-color"] as? [String: AnyObject] ?? [:], included: nil)
        block.borderRadius = JSON["border-radius"] as? CGFloat
        block.borderWidth = JSON["border-width"] as? CGFloat
        
        return block
    }
}

extension Offset : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Offset? {
        let top = Unit.instance(JSON["top"] as? [String: AnyObject] ?? [:], included: nil)
        let right = Unit.instance(JSON["right"] as? [String: AnyObject] ?? [:], included: nil)
        let bottom = Unit.instance(JSON["bottom"] as? [String: AnyObject] ?? [:], included: nil)
        let left = Unit.instance(JSON["left"] as? [String: AnyObject] ?? [:], included: nil)
        let center = Unit.instance(JSON["center"] as? [String: AnyObject] ?? [:], included: nil)
        let middle = Unit.instance(JSON["middle"] as? [String: AnyObject] ?? [:], included: nil)

        return Offset(left: left, right: right, top: top, bottom: bottom, center: center, middle: middle)
    }
}

extension Alignment : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Alignment? {
        let horizontal = Alignment.HorizontalAlignment(rawValue: JSON["horizonal"] as? String ?? "left")
        let vertical = Alignment.VerticalAlignment(rawValue: JSON["vertical"] as? String ?? "top")
        
        return Alignment(horizontal: horizontal, vertical: vertical)
    }
}

extension Unit : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Unit? {
        guard let value = JSON["value"] as? CGFloat,
            type = JSON["type"] as? String else { return nil }
        
        switch type {
        case "points":
            return Unit.Points(value)
        case "percentage":
            return Unit.Percentage(value)
        default:
            return nil
        }
    }
}

extension UIColor : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> UIColor? {
        guard let red = JSON["red"] as? CGFloat,
            blue = JSON["blue"] as? CGFloat,
            green = JSON["green"] as? CGFloat,
            alpha = JSON["alpha"] as? CGFloat else { return nil }
        
        return UIColor(red: red/255.0, green: green/255.0, blue: blue/255.0, alpha: alpha)
    }
}

