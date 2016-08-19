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
    public static func instance(JSON: [String: AnyObject], included: [String: Any]?) -> CLRegion? {
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
            guard let latitude = attributes["latitude"] as? CLLocationDegrees,
                longitude = attributes["longitude"] as? CLLocationDegrees,
                radius = attributes["radius"] as? CLLocationDistance else { return nil }
            
            return CLCircularRegion(center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), radius: radius, identifier: identifier)
        default:
            // invalid type
            return nil
        }
        
    }
}

extension Event : Mappable {
    public static func instance(JSON: [String : AnyObject], included: [String: Any]?) -> Event? {
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
            
            var place: Place?
            if let placeAttributes = attributes["place"] as? [String: AnyObject] {
                place = Place.instance(placeAttributes, included: nil)
            }
            
            switch action {
            case "enter":
                return Event.DidEnterBeaconRegion(beaconRegion, config: beaconConfig, place: place, date: date)
            case "exit":
                return Event.DidExitBeaconRegion(beaconRegion, config: beaconConfig, place: place, date: date)
            default:
                return nil
            }
        case ("geofence-region", let action):
            guard let
                placeJSON = attributes["place"] as? [String: AnyObject],
                place = Place.instance(placeJSON, included: nil),
                circularRegion = included?["region"] as? CLCircularRegion else { return nil }
            
            switch action {
            case "enter":
                return Event.DidEnterCircularRegion(circularRegion, place: place, date: date)
            case "exit":
                return Event.DidExitCircularRegion(circularRegion, place: place, date: date)
            default:
                return nil
            }
        default:
            return nil
        }
    }
}

extension BeaconConfiguration : Mappable {
    public static func instance(JSON: [String : AnyObject], included: [String: Any]?) -> BeaconConfiguration? {
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

extension Place : Mappable {
    public static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Place? {
        guard let
            latitude = JSON["latitude"] as? CLLocationDegrees,
            longitude = JSON["longitude"] as? CLLocationDegrees,
            radius = JSON["radius"] as? CLLocationDistance,
            name = JSON["name"] as? String,
            tags = JSON["tags"] as? [String] else { return nil }
        
        return Place(coordinates: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), radius: radius, name: name, tags: tags)
    }
}

extension Message : Mappable {
    public static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Message? {
        guard let type = JSON["type"] as? String,
            identifier = JSON["id"] as? String,
            attributes = JSON["attributes"] as? [String: AnyObject],
            title = attributes["ios-title"] as? String?,
            timestampString = attributes["timestamp"] as? String,
            timestamp = rvDateFormatter.dateFromString(timestampString),
            text = attributes["notification-text"] as? String,
            properties = attributes["properties"] as? [String: String]
            where type == "messages" else { return nil }
        
        
        
        let message = Message(title: title, text: text, timestamp: timestamp, identifier: identifier, properties: properties)

        message.read = attributes["read"] as? Bool ?? false
        message.savedToInbox = attributes["saved-to-inbox"] as? Bool ?? false
        
        if let action = attributes["content-type"] as? String {
            switch action {
            case "deep-link":
                message.action = .DeepLink
                if let url = attributes["deep-link-url"] as? String {
                    message.url = NSURL(string: url)
                }
            case "website":
                message.action = .Website
                // TODO: this can throw, needs to be safer
                if let url = attributes["website-url"] as? String {
                    message.url = NSURL(string: url)
                }
            case "landing-page":
                message.action = .LandingPage
                
                if let landingPageAttributes = attributes["landing-page"] as? [String: AnyObject] {
                    message.landingPage = Screen.instance(landingPageAttributes, included: nil)
                }
            case "experience":
                message.action = .Experience
                
                if let experienceId = attributes["experience-id"] as? String {
                    message.experienceId = experienceId
                }
            default:
                message.action = .None
            }
        }

        
        return message
    }
}

extension Experience : Mappable {
    public static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Experience? {
        guard let attributes = JSON["attributes"] as? [String: AnyObject],
            identifier = JSON["id"] as? String,
            screensAttributes = attributes["screens"] as? [[String: AnyObject]],
            screens = screensAttributes.map({ Screen.instance($0, included: nil) }) as? [Screen],
            homeScreenId = attributes["home-screen-id"] as? String else {
                return nil
        }
        
        return Experience(screens: screens, homeScreenIdentifier: homeScreenId, identifier: identifier)
    }
}

extension Screen : Mappable {
    public static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Screen? {
        guard let rowsAttributes = JSON["rows"] as? [[String : AnyObject]],
            rows = rowsAttributes.map({ Row.instance($0, included: nil) }) as? [Row] else {
                return nil
        }
        
        // TODO: header rows and footer rows
        
        let screen = Screen(rows: rows)
        screen.title = JSON["title"] as? String
        screen.backgroundColor = UIColor.instance(JSON["background-color"] as? [String: AnyObject] ?? [:], included: nil) ?? screen.backgroundColor
        screen.titleColor = UIColor.instance(JSON["title-bar-text-color"] as? [String: AnyObject] ?? [:], included: nil)
        screen.navBarColor = UIColor.instance(JSON["title-bar-background-color"] as? [String: AnyObject] ?? [:], included: nil)
        screen.navItemColor = UIColor.instance(JSON["title-bar-button-color"] as? [String: AnyObject] ?? [:], included: nil)
        screen.statusBarStyle = UIStatusBarStyle.instance(JSON["status-bar-style"] as? String)
        screen.useDefaultNavBarStyle = JSON["use-default-title-bar-style"] as? Bool ?? true
        screen.identifier = JSON["id"] as? String
        screen.navBarButtons = Screen.NavBarButtons(rawValue: JSON["title-bar-buttons"] as? String ?? "") ?? screen.navBarButtons
        screen.backgroundImage = Image.instance(JSON["background-image"] as? [String: AnyObject] ?? [:], included: nil)
        screen.backgorundContentMode = ImageContentMode(rawValue: JSON["background-content-mode"] as? String ?? "") ?? screen.backgorundContentMode
        screen.backgroundScale = JSON["background-scale"] as? CGFloat ?? screen.backgroundScale
        
        return screen
    }
}

extension Row : Mappable {
    public static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Row? {
        guard let blocksAttributes = JSON["blocks"] as? [[String : AnyObject]],
            blocks = blocksAttributes.map({ Block.instance($0, included: nil) }) as? [Block] else {
                return nil
        }
        
        let row = Row(blocks: blocks)
        row.height = Unit.instance(JSON["height"] as? [String: AnyObject] ?? [:], included: nil)
        row.backgroundBlock.backgroundColor = UIColor.instance(JSON["background-color"] as? [String: AnyObject] ?? [:], included: nil) ?? row.backgroundBlock.backgroundColor
        row.backgroundBlock.backgroundImage = Image.instance(JSON["background-image"] as? [String: AnyObject] ?? [:] , included: nil)
        row.backgroundBlock.backgroundScale = JSON["background-scale"] as? CGFloat ?? row.backgroundBlock.backgroundScale
        row.backgroundBlock.backgroundContentMode = ImageContentMode(rawValue: JSON["background-content-mode"] as? String ?? "") ?? row.backgroundBlock.backgroundContentMode
        
        return row
    }
}

extension Block : Mappable {
    public static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Block? {
        guard let type = JSON["type"] as? String else {
            return nil
        }
        
        var block: Block
        
        switch type {
        case "barcode-block":
            fallthrough
        case "image-block":
            let image = Image.instance(JSON["image"] as? [String: AnyObject] ?? [:], included: nil)
            
            block = ImageBock(image: image)
        case "text-block":
            block = TextBlock()
            
            let textBlock = block as! TextBlock
            textBlock.text = JSON["text"] as? String
            
            if let alignment = Alignment.instance(JSON["text-alignment"] as? [String: AnyObject] ?? [:], included: nil) {
                textBlock.textAlignment = alignment
            } else {
                textBlock.textAlignment = Alignment(horizontal: Alignment.HorizontalAlignment(rawValue:JSON["text-alignment"] as? String ?? "left") ?? .Left, vertical: .Top) ?? textBlock.textAlignment
            }
            
            textBlock.textOffset = Offset.instance(JSON["text-offset"] as? [String: AnyObject] ?? [:], included: nil) ?? textBlock.textOffset
            textBlock.textColor = UIColor.instance(JSON["text-color"] as? [String: AnyObject] ?? [:], included: nil) ?? textBlock.textColor
            
            let fontSize = JSON["text-font-size"] as? CGFloat
            let fontWeight = JSON["text-font-weight"] as? CGFloat
            
            textBlock.font = UIFont.instance(JSON["text-font"] as? [String: AnyObject] ?? [:], included: nil) ?? textBlock.font
            
        case "button-block":
            block = ButtonBlock()
            
            let buttonBlock = block as! ButtonBlock
        
            if let states = JSON["states"] as? [String: AnyObject] {
                buttonBlock.appearences[.Normal] = ButtonBlock.Appearance.instance(states["normal"] as? [String: AnyObject] ?? [:], included: nil)
                buttonBlock.appearences[.Highlighted] = ButtonBlock.Appearance.instance(states["highlighted"] as? [String: AnyObject] ?? [:], included: nil)
                buttonBlock.appearences[.Selected] = ButtonBlock.Appearance.instance(states["selected"] as? [String: AnyObject] ?? [:], included: nil)
                buttonBlock.appearences[.Disabled] = ButtonBlock.Appearance.instance(states["disabled"] as? [String: AnyObject] ?? [:], included: nil)
            }
        case "web-view-block":
            let url = NSURL(string: JSON["url"] as? String ?? "")
            
            block = WebBlock(url: url)
            
            let webBlock = block as! WebBlock
            webBlock.scrollable = true//JSON["scrollable"] as? Bool ?? webBlock.scrollable
        default:
            block = Block()
        }
        
        block.identifier = JSON["id"] as? String
        block.action = Block.Action.instance(JSON["action"] as? [String: AnyObject] ?? [:], included: nil)
        
        // Layout
        
        block.width = Unit.instance(JSON["width"] as? [String: AnyObject] ?? [:], included: nil)
        block.height = Unit.instance(JSON["height"] as? [String: AnyObject] ?? [:], included: nil)
        block.position = Block.Position(rawValue: JSON["position"] as? String ?? "") ?? block.position
        block.alignment = Alignment.instance(JSON["alignment"] as? [String: AnyObject] ?? [:], included: nil) ?? block.alignment
        block.offset = Offset.instance(JSON["offset"] as? [String: AnyObject] ?? [:], included: nil) ?? block.offset
        
        // Appearance

        block.backgroundColor = UIColor.instance(JSON["background-color"] as? [String: AnyObject] ?? [:], included: nil) ?? block.backgroundColor
        block.borderColor = UIColor.instance(JSON["border-color"] as? [String: AnyObject] ?? [:], included: nil) ?? block.borderColor
        block.borderRadius = JSON["border-radius"] as? CGFloat ?? block.borderRadius
        block.borderWidth = JSON["border-width"] as? CGFloat ?? block.borderWidth
        block.inset = UIEdgeInsets.instance(JSON["inset"] as? [String: AnyObject] ?? [:], included: nil) ?? block.inset
        block.opacity = JSON["opacity"] as? Float ?? block.opacity
        
        if let isAutoHeight = JSON["auto-height"] as? Bool where isAutoHeight {
            block.height = nil
        }
        
        // BackgroundImage
        
        block.backgroundImage = Image.instance(JSON["background-image"] as? [String : AnyObject] ?? [:], included: nil)
        block.backgroundContentMode = ImageContentMode(rawValue: JSON["background-content-mode"] as? String ?? "") ?? block.backgroundContentMode
        block.backgroundScale = JSON["background-scale"] as? CGFloat ?? block.backgroundScale
        
        return block
    }
}

extension Block.Action : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> ButtonBlock.Action? {
        guard let type = JSON["type"] as? String else { return nil }
        
        let urlString = JSON["url"] as? String ?? ""
        let url = NSURL(string: urlString)
        
        switch type {
        case "website-action":
            guard let url = url else { return nil }
            return .Website(url)
        case "deep-link-action":
            guard let url = url else { return nil }
            return .Deeplink(url)
        case "go-to-screen":
            guard let screenIdentifier = JSON["screen-id"] as? String else { return nil }
            return .Screen(screenIdentifier)
        case "open-url":
            guard let url = url else { return nil }
            return .Deeplink(url)
        default:
            return nil
        }
    }
}

extension ButtonBlock.Appearance : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> ButtonBlock.Appearance? {
        var appearance = ButtonBlock.Appearance()
        appearance.title = JSON["text"] as? String
        
        if let alignment = Alignment.instance(JSON["text-alignment"] as? [String: AnyObject] ?? [:], included: nil) {
            appearance.titleAlignment = alignment
        } else {
            appearance.titleAlignment = Alignment(horizontal: Alignment.HorizontalAlignment(rawValue: JSON["text-alignment"] as? String ?? "center") ?? .Center, vertical: .Middle)
        }

        appearance.titleOffset = Offset.instance(JSON["text-offset"] as? [String: AnyObject] ?? [:], included: nil)
        appearance.titleColor = UIColor.instance(JSON["text-color"] as? [String: AnyObject] ?? [:], included: nil)
        appearance.titleFont = UIFont.instance(JSON["text-font"] as? [String: AnyObject] ?? [:], included: nil)
        appearance.backgroundColor = UIColor.instance(JSON["background-color"] as? [String: AnyObject] ?? [:], included: nil)
        appearance.borderColor = UIColor.instance(JSON["border-color"] as? [String: AnyObject] ?? [:], included: nil)
        appearance.borderRadius = JSON["border-radius"] as? CGFloat
        appearance.borderWidth = JSON["border-width"] as? CGFloat
        return appearance
    }
}

extension Image: Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Image? {
        guard let width = JSON["width"] as? CGFloat,
            height = JSON["height"] as? CGFloat,
            urlString = JSON["url"] as? String,
            url = NSURL(string: urlString) else { return nil }
        
        return Image(size: CGSize(width: width, height: height), url: url)
    }
}

extension Offset : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Offset? {
        let top = Unit.instance(JSON["top"] as? [String: AnyObject] ?? [:], included: nil) ?? .Points(0)
        let right = Unit.instance(JSON["right"] as? [String: AnyObject] ?? [:], included: nil) ?? .Points(0)
        let bottom = Unit.instance(JSON["bottom"] as? [String: AnyObject] ?? [:], included: nil) ?? .Points(0)
        let left = Unit.instance(JSON["left"] as? [String: AnyObject] ?? [:], included: nil) ?? .Points(0)
        let center = Unit.instance(JSON["center"] as? [String: AnyObject] ?? [:], included: nil) ?? .Points(0)
        let middle = Unit.instance(JSON["middle"] as? [String: AnyObject] ?? [:], included: nil) ?? .Points(0)

        return Offset(left: left, right: right, top: top, bottom: bottom, center: center, middle: middle)
    }
}

extension Alignment : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Alignment? {
        guard let horizontal = Alignment.HorizontalAlignment(rawValue: JSON["horizontal"] as? String ?? ""),
            vertical = Alignment.VerticalAlignment(rawValue: JSON["vertical"] as? String ?? "") else { return nil }
        
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
    public static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> UIColor? {
        guard let red = JSON["red"] as? CGFloat,
            blue = JSON["blue"] as? CGFloat,
            green = JSON["green"] as? CGFloat,
            alpha = JSON["alpha"] as? CGFloat else { return nil }
        
        return UIColor(red: red/255.0, green: green/255.0, blue: blue/255.0, alpha: alpha)
    }
}

extension UIFont : Mappable {
    public static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> UIFont? {
        guard let fontSize = JSON["size"] as? CGFloat,
            fontWeight = JSON["weight"] as? Int else { return UIFont.systemFontOfSize(12) }
        
        let weights = [
            100: UIFontWeightUltraLight,
            200: UIFontWeightThin,
            300: UIFontWeightLight,
            400: UIFontWeightRegular,
            500: UIFontWeightMedium,
            600: UIFontWeightSemibold,
            700: UIFontWeightBold,
            800: UIFontWeightHeavy,
            900: UIFontWeightBlack
        ]
        
        return UIFont.systemFontOfSize(fontSize, weight: weights[fontWeight] ?? UIFontWeightRegular)
    }
}

extension UIStatusBarStyle {
    public static func instance(string: String?) -> UIStatusBarStyle? {
        switch string {
        case "light"?:
            return .LightContent
        default:
            return .Default
        }
    }
}

extension UIEdgeInsets : Mappable {
    public static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> UIEdgeInsets? {
        guard let top = JSON["top"] as? CGFloat,
            bottom = JSON["bottom"] as? CGFloat,
            left = JSON["left"] as? CGFloat,
            right = JSON["right"] as? CGFloat else { return nil }
        
        return UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
    }
}
