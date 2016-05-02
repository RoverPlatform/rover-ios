//
//  MonitoringViewController.swift
//  Rover
//
//  Created by Ata Namvari on 2016-04-29.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import MapKit
import Rover

class MyAnnotation: MKPointAnnotation {
    var region: CLCircularRegion?
    var inside = false
}

class MonitoringViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var monitoringSwitch: UISwitch!
    
    let locationManager = CLLocationManager()
    
    var geofenceRegions = [CLCircularRegion]()
    var beaconRegions = [CLBeaconRegion]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        locationManager.delegate = self
        
        reloadData()
        
        monitoringSwitch.setOn(Rover.isMonitoring, animated: false)
    }
    
    func reloadData() {
        geofenceRegions = locationManager.monitoredRegions.filter({ $0 is CLCircularRegion }) as! [CLCircularRegion]
        beaconRegions = locationManager.monitoredRegions.filter({ $0 is CLBeaconRegion }) as! [CLBeaconRegion]
        
        segmentedControl.setTitle("Geofences (\(geofenceRegions.count))", forSegmentAtIndex: 0)
        segmentedControl.setTitle("Beacons (\(beaconRegions.count))", forSegmentAtIndex: 1)
        
        reloadMapOverlays()
    }
    
    func reloadMapOverlays() {
        mapView.removeOverlays(mapView.overlays)
        mapView.annotations.forEach { annotation in
            mapView.removeAnnotation(annotation)
        }
        geofenceRegions.forEach { region in
            locationManager.requestStateForRegion(region)

        }
    }
    
    func enterGeofence(sender: UIButton) {
        let region = geofenceRegions[sender.tag]
        Rover.simulateEvent(Event.DidEnterCircularRegion(region, location: nil, date: NSDate()))
    }
    
    func exitGeofence(sender: UIButton) {
        let region = geofenceRegions[sender.tag]
        Rover.simulateEvent(Event.DidExitCircularRegion(region, location: nil, date: NSDate()))
    }
    
    // MARK: Actions
    
    @IBAction func segmentChanged(sender: UISegmentedControl) {
        mapView.hidden = sender.selectedSegmentIndex == 1
        tableView.hidden = sender.selectedSegmentIndex == 0
    }
    
    @IBAction func monitoringSwitched(sender: UISwitch) {
        if sender.on {
            Rover.startMonitoring()
        } else {
            Rover.stopMonitoring()
            geofenceRegions = []
            beaconRegions = []
            reloadData()
        }
    }
}

extension MonitoringViewController : MKMapViewDelegate {
    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        let circleView = MKCircleRenderer(overlay: overlay)
        if overlay is RedCircle {
            circleView.strokeColor = UIColor(red: 1, green: 8.0/255.0, blue: 0, alpha: 1)
            circleView.fillColor = UIColor(red: 1, green: 7.0/255.0, blue: 0, alpha: 0.3)
        } else {
        	circleView.strokeColor = UIColor(red: 0, green: 122.0/255.0, blue: 255, alpha: 1)
            circleView.fillColor = UIColor(red: 0, green: 122.0/255.0, blue: 255, alpha: 0.3)
        }
        circleView.lineWidth = 1
        return circleView
    }
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotation = annotation as? MyAnnotation else { return nil }
        
        var pin = mapView.dequeueReusableAnnotationViewWithIdentifier("annotationView") as? MKPinAnnotationView
        if (pin == nil) {
            pin = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "annotationView")
        } else {
            pin?.annotation = annotation
        }
        
        if !annotation.inside {
            pin?.pinTintColor = UIColor(red: 0, green: 122.0/255.0, blue: 255, alpha: 1)
        }
        
        pin?.canShowCallout = true
        
        let calloutView = UIView()
        
        let enterButton = UIButton(frame: CGRect(x: 0, y: 0, width: 100, height: 44))
        enterButton.setTitle("Enter", forState: .Normal)
        enterButton.setTitleColor(UIColor(red: 0, green: 122.0/255.0, blue: 255, alpha: 1), forState: .Normal)
        enterButton.addTarget(self, action: #selector(MonitoringViewController.enterGeofence(_:)), forControlEvents: .TouchUpInside)
        enterButton.tag = geofenceRegions.indexOf(annotation.region!)!
        
        let exitButton = UIButton(frame: CGRect(x: 100, y: 0, width: 100, height: 44))
        exitButton.setTitle("Exit", forState: .Normal)
        exitButton.setTitleColor(UIColor(red: 0, green: 122.0/255.0, blue: 255, alpha: 1), forState: .Normal)
        exitButton.addTarget(self, action: #selector(MonitoringViewController.exitGeofence(_:)), forControlEvents: .TouchUpInside)
        exitButton.tag = geofenceRegions.indexOf(annotation.region!)!
        
        calloutView.addSubview(enterButton)
        calloutView.addSubview(exitButton)
        
        calloutView.addConstraint(NSLayoutConstraint(item: calloutView, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 200))
        calloutView.addConstraint(NSLayoutConstraint(item: calloutView, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 44))
        
        pin?.detailCalloutAccessoryView = calloutView
        
        return pin
    }
}

extension MonitoringViewController : UITableViewDataSource {

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return beaconRegions.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("beaconCellIdentifier", forIndexPath: indexPath)
        
        let region = beaconRegions[indexPath.row]
            
        cell.detailTextLabel?.text = region.proximityUUID.UUIDString
        cell.textLabel?.text = "Major: \(region.major == nil ? "*" : region.major!)  Minor: \(region.minor == nil ? "*" : region.minor!)"
        
        return cell
    }
}

extension MonitoringViewController : UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let region = beaconRegions[indexPath.row]
        let alertController = UIAlertController(title: "Simulate", message: "Enter Major/Minor number:", preferredStyle: .Alert)
        alertController.addTextFieldWithConfigurationHandler { (textField) in
            textField.keyboardType = .NumberPad
            textField.text = "1"
        }
        alertController.addTextFieldWithConfigurationHandler { (textField) in
            textField.keyboardType = .NumberPad
            textField.text = "1"
        }
        let enterAction = UIAlertAction(title: "Enter", style: .Default) { (action) in
            let r = CLBeaconRegion(proximityUUID: region.proximityUUID, major: UInt16(alertController.textFields![0].text ?? "1")!, minor: UInt16(alertController.textFields![1].text ?? "1")!, identifier: "")
            Rover.simulateEvent(.DidEnterBeaconRegion(r, config: nil, location: nil, date: NSDate()))
        }
        let exitAction = UIAlertAction(title: "Exit", style: .Default) { (action) in
            let r = CLBeaconRegion(proximityUUID: region.proximityUUID, major: UInt16(alertController.textFields![0].text ?? "1")!, minor: UInt16(alertController.textFields![1].text ?? "1")!, identifier: "")
            Rover.simulateEvent(.DidExitBeaconRegion(r, config: nil, location: nil, date: NSDate()))
        }
        alertController.addAction(enterAction)
        alertController.addAction(exitAction)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        presentViewController(alertController, animated: true) { 
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
    }
}

extension MonitoringViewController : CLLocationManagerDelegate {
    func locationManager(manager: CLLocationManager, didStartMonitoringForRegion region: CLRegion) {
        reloadData()
    }
    
    func locationManager(manager: CLLocationManager, didDetermineState state: CLRegionState, forRegion region: CLRegion) {
        guard let region = region as? CLCircularRegion else { return }
        
        let annotation = MyAnnotation()
        
        var circle: MKCircle
        if state == .Inside {
            circle = RedCircle(centerCoordinate: region.center, radius: region.radius)
            annotation.inside = true
        } else {
            circle = BlueCircle(centerCoordinate: region.center, radius: region.radius)
        }
        mapView.addOverlay(circle)
        
        annotation.coordinate = region.center
        annotation.title = "Simulate"
        annotation.region = region
        mapView.addAnnotation(annotation)
        
        mapView.showAnnotations(mapView.annotations, animated: true)
    }
    
    func locationManager(manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region is CLCircularRegion {
            reloadMapOverlays()
        }
    }
    
    func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region is CLCircularRegion {
            reloadMapOverlays()
        }
    }
}

class RedCircle : MKCircle { }
class BlueCircle: MKCircle { }