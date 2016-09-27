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
        
        NotificationCenter.default.addObserver(self, selector: #selector(userDidSignOut), name: NSNotification.Name(rawValue: UserDidSignOutNotification), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func reloadData() {
        geofenceRegions = locationManager.monitoredRegions.filter({ $0 is CLCircularRegion }) as! [CLCircularRegion]
        beaconRegions = locationManager.monitoredRegions.filter({ $0 is CLBeaconRegion }) as! [CLBeaconRegion]
        
        segmentedControl.setTitle("Geofences (\(geofenceRegions.count))", forSegmentAt: 0)
        segmentedControl.setTitle("Beacons (\(beaconRegions.count))", forSegmentAt: 1)
        
        reloadMapOverlays()
    }
    
    func reloadMapOverlays() {
        mapView.removeOverlays(mapView.overlays)
        mapView.annotations.forEach { annotation in
            mapView.removeAnnotation(annotation)
        }
        geofenceRegions.forEach { region in
            locationManager.requestState(for: region)

        }
    }
    
    func enterGeofence(_ sender: UIButton) {
        let region = geofenceRegions[sender.tag]
        Rover.simulateEvent(Event.didEnterCircularRegion(region, place: nil, date: Date()))
    }
    
    func exitGeofence(_ sender: UIButton) {
        let region = geofenceRegions[sender.tag]
        Rover.simulateEvent(Event.didExitCircularRegion(region, place: nil, date: Date()))
    }
    
    func userDidSignOut(_ note: Notification) {
        monitoringSwitch.isOn = false
        stopMonitoring()
    }
    
    func stopMonitoring() {
        Rover.stopMonitoring()
        geofenceRegions = []
        beaconRegions = []
        reloadData()
    }
    
    // MARK: Actions
    
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        mapView.isHidden = sender.selectedSegmentIndex == 1
        tableView.isHidden = sender.selectedSegmentIndex == 0
    }
    
    @IBAction func monitoringSwitched(_ sender: UISwitch) {
        if sender.isOn {
            Rover.startMonitoring()
            if let location = CLLocationManager().location {
                Rover.updateLocation(location)
            }
        } else {
            stopMonitoring()
        }
    }
}

extension MonitoringViewController : MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
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
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotation = annotation as? MyAnnotation,
            let region = annotation.region,
            let geofenceRegion = geofenceRegions.index(of: region) else { return nil }
        
        var pin = mapView.dequeueReusableAnnotationView(withIdentifier: "annotationView") as? MKPinAnnotationView
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
        enterButton.setTitle("Enter", for: UIControlState())
        enterButton.setTitleColor(UIColor(red: 0, green: 122.0/255.0, blue: 255, alpha: 1), for: UIControlState())
        enterButton.addTarget(self, action: #selector(MonitoringViewController.enterGeofence(_:)), for: .touchUpInside)
        enterButton.tag = geofenceRegion
        
        let exitButton = UIButton(frame: CGRect(x: 100, y: 0, width: 100, height: 44))
        exitButton.setTitle("Exit", for: UIControlState())
        exitButton.setTitleColor(UIColor(red: 0, green: 122.0/255.0, blue: 255, alpha: 1), for: UIControlState())
        exitButton.addTarget(self, action: #selector(MonitoringViewController.exitGeofence(_:)), for: .touchUpInside)
        exitButton.tag = geofenceRegion
        
        calloutView.addSubview(enterButton)
        calloutView.addSubview(exitButton)
        
        calloutView.addConstraint(NSLayoutConstraint(item: calloutView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 200))
        calloutView.addConstraint(NSLayoutConstraint(item: calloutView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 44))
        
        pin?.detailCalloutAccessoryView = calloutView
        
        return pin
    }
}

extension MonitoringViewController : UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return beaconRegions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "beaconCellIdentifier", for: indexPath)
        
        let region = beaconRegions[(indexPath as NSIndexPath).row]
            
        cell.detailTextLabel?.text = region.proximityUUID.uuidString
        cell.textLabel?.text = "Major: \(region.major == nil ? "*" : String(describing: region.major!))  Minor: \(region.minor == nil ? "*" : String(describing: region.minor!))"
        
        return cell
    }
}

extension MonitoringViewController : UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let region = beaconRegions[(indexPath as NSIndexPath).row]
        let alertController = UIAlertController(title: "Simulate", message: "Enter Major/Minor number:", preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.keyboardType = .numberPad
            textField.text = "1"
        }
        alertController.addTextField { (textField) in
            textField.keyboardType = .numberPad
            textField.text = "1"
        }
        let enterAction = UIAlertAction(title: "Enter", style: .default) { (action) in
            let r = CLBeaconRegion(proximityUUID: region.proximityUUID, major: UInt16(alertController.textFields![0].text ?? "1")!, minor: UInt16(alertController.textFields![1].text ?? "1")!, identifier: "")
            Rover.simulateEvent(.didEnterBeaconRegion(r, config: nil, place: nil, date: Date()))
        }
        let exitAction = UIAlertAction(title: "Exit", style: .default) { (action) in
            let r = CLBeaconRegion(proximityUUID: region.proximityUUID, major: UInt16(alertController.textFields![0].text ?? "1")!, minor: UInt16(alertController.textFields![1].text ?? "1")!, identifier: "")
            Rover.simulateEvent(.didExitBeaconRegion(r, config: nil, place: nil, date: Date()))
        }
        alertController.addAction(enterAction)
        alertController.addAction(exitAction)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alertController, animated: true) { 
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
}

extension MonitoringViewController : CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        reloadData()
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard let region = region as? CLCircularRegion else { return }
        
        let annotation = MyAnnotation()
        
        var circle: MKCircle
        if state == .inside {
            circle = RedCircle(center: region.center, radius: region.radius)
            annotation.inside = true
        } else {
            circle = BlueCircle(center: region.center, radius: region.radius)
        }
        mapView.add(circle)
        
        annotation.coordinate = region.center
        annotation.title = "Simulate"
        annotation.region = region
        mapView.addAnnotation(annotation)
        
        mapView.showAnnotations(mapView.annotations, animated: true)
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region is CLCircularRegion {
            reloadMapOverlays()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region is CLCircularRegion {
            reloadMapOverlays()
        }
    }
}

class RedCircle : MKCircle { }
class BlueCircle: MKCircle { }
