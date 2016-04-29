//
//  ViewController.swift
//  Rover
//
//  Created by ata_n on 01/05/2016.
//  Copyright (c) 2016 ata_n. All rights reserved.
//

import UIKit
import Rover
import CoreLocation

class BeaconRegion {
    var UUID: NSUUID
    var major: UInt16
    var minor: UInt16
    var majorEnabled: Bool
    var minorEnabled: Bool
    var identifier: String
    
    init(UUID: NSUUID, major: UInt16, minor: UInt16, majorEnabled: Bool, minorEnabled: Bool, identifier: String) {
        self.UUID = UUID
        self.major = major
        self.minor = minor
        self.majorEnabled = majorEnabled
        self.minorEnabled = minorEnabled
        self.identifier = identifier
    }
}

class MainViewController: UITableViewController {
    
    let locationManager = CLLocationManager()
    
    var beaconRegions = [BeaconRegion]()
    var geofenceRegions = [CLCircularRegion]()
    
    var beaconEditing = false {
        didSet {
            if beaconEditing {
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done", style: .Done, target: self, action: #selector(MainViewController.endBeaconEditing))
            } else {
                self.navigationItem.leftBarButtonItem = updateBarButtonItem
            }
        }
    }

    @IBOutlet weak var monitoringSwitch: UISwitch!
    @IBOutlet var updateBarButtonItem: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.delegate = self
        
        reloadDataSource()
        tableView.reloadData()
        
        monitoringSwitch.setOn(Rover.isMonitoring, animated: false)
        updateBarButtonItem.enabled = Rover.isMonitoring
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func reloadDataSource() {
        let clBeaconRegions = locationManager.monitoredRegions.filter { $0 is CLBeaconRegion } as! [CLBeaconRegion]
        beaconRegions = clBeaconRegions.map { (region) -> BeaconRegion in
            return BeaconRegion(UUID: region.proximityUUID,
                major: UInt16(region.major?.integerValue ?? 1),
                minor: UInt16(region.minor?.integerValue ?? 1), majorEnabled: region.major == nil, minorEnabled: region.minor == nil, identifier: region.identifier)
        }
        geofenceRegions = locationManager.monitoredRegions.filter { $0 is CLCircularRegion } as! [CLCircularRegion]
    }
    
    // MARK: Navigation
    
    @IBAction func unwindToMonitoringViewController(segue: UIStoryboardSegue) {
        if segue.identifier == "SpoofSegue" {
            guard let sourceViewController = segue.sourceViewController as? LocationViewController,
                let location = sourceViewController.selectedLocation else { return }
            Rover.updateLocation(location)
        }
    }
    
    // MARK: Actions
    
    @IBAction func monitoringSwitchValueDidChange(sender: UISwitch) {
        if sender.on {
            Rover.startMonitoring()
        } else {
            Rover.stopMonitoring()
            beaconRegions = []
            geofenceRegions = []
            tableView.reloadData()
        }
        updateBarButtonItem.enabled = sender.on
    }
    
    @IBAction func didBeginEditingBeaconInfo(sender: UITextField) {
        if !beaconEditing {
            beaconEditing = true
        }
    }
    
    @IBAction func didEndEditingBeaconInfo(sender: UITextField) {
        let cell = sender.superview?.superview as! BeaconTableViewCell
        let indexPath = tableView.indexPathForCell(cell)
        let beaconRegion = beaconRegions[indexPath!.row]
        beaconRegion.major = UInt16(cell.majorTextField.text ?? "1")!
        beaconRegion.minor = UInt16(cell.minorTextField.text ?? "1")!
    }
    
    @IBAction func didPressUpdate(sender: UIBarButtonItem) {
        let alert = UIAlertController(title: nil, message: "Location:", preferredStyle: .ActionSheet)
        let currentLocationAction = UIAlertAction(title: "Current Location", style: .Default) { action in
            self.locationManager.startUpdatingLocation()
        }
        let spoofAction = UIAlertAction(title: "Spoof", style: .Default) { action in
            self.performSegueWithIdentifier("LocationSegue", sender: nil)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        alert.addAction(spoofAction)
        alert.addAction(currentLocationAction)
        alert.addAction(cancelAction)
        presentViewController(alert, animated: true, completion: nil)
    }
    
    func endBeaconEditing() {
        self.view.endEditing(true)
        beaconEditing = false
    }
    
    // MARK: UITableViewDataSource
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Beacon Regions (\(beaconRegions.count))"
        } else {
            return "Geofences (\(geofenceRegions.count))"
        }
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return beaconRegions.count
        } else {
            return geofenceRegions.count
        }
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 81
        } else {
            return 44
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = self.tableView.dequeueReusableCellWithIdentifier("BeaconCellIdentifier", forIndexPath: indexPath) as! BeaconTableViewCell
            let beaconRegion = beaconRegions[indexPath.row]
            cell.label.text = beaconRegion.identifier
            cell.majorTextField.text = "\(beaconRegion.major)"
            cell.minorTextField.text = "\(beaconRegion.minor)"
            cell.majorTextField.enabled = beaconRegion.majorEnabled
            cell.minorTextField.enabled = beaconRegion.minorEnabled
            cell.delegate = self
            
            return cell
        } else {
            let cell = self.tableView.dequeueReusableCellWithIdentifier("GeofenceCellIdentifier", forIndexPath: indexPath) as! GeofenceTableViewCell
            let geofence = geofenceRegions[indexPath.row]
            cell.label.text = geofence.identifier
            cell.delegate = self
            
            return cell
        }
    }

}

extension MainViewController : BeaconTableViewCellDelegate {
    
    func beaconTableViewCellDidPressEnter(cell: BeaconTableViewCell) {
        guard let indexPath = tableView.indexPathForCell(cell) else { return }
        let region = beaconRegions[indexPath.row]
        let simulatedRegion = CLBeaconRegion(proximityUUID: region.UUID, major: region.major, minor: region.minor, identifier: region.identifier)
        Rover.simulateEvent(Event.DidEnterBeaconRegion(simulatedRegion, config: nil, location: nil, date: NSDate()))
    }
    
    func beaconTableViewCellDidPressExit(cell: BeaconTableViewCell) {
        guard let indexPath = tableView.indexPathForCell(cell) else { return }
        let region = beaconRegions[indexPath.row]
        let simulatedRegion = CLBeaconRegion(proximityUUID: region.UUID, major: region.major, minor: region.minor, identifier: region.identifier)
        Rover.simulateEvent(Event.DidExitBeaconRegion(simulatedRegion, config: nil, location: nil, date: NSDate()))
    }
}

extension MainViewController : GeofenceTableViewCellDelegate {
    
    func geofenceTableViewCellDidPressEnter(cell: GeofenceTableViewCell) {
        guard let indexPath = tableView.indexPathForCell(cell) else { return }
        let region = geofenceRegions[indexPath.row]
        Rover.simulateEvent(Event.DidEnterCircularRegion(region, location: nil, date: NSDate()))
        //Rover.simulateEnterEvent(region: region)
    }
    
    func geofenceTableViewCellDidPressExit(cell: GeofenceTableViewCell) {
        guard let indexPath = tableView.indexPathForCell(cell) else { return }
        let region = geofenceRegions[indexPath.row]
        Rover.simulateEvent(Event.DidExitCircularRegion(region, location: nil, date: NSDate()))
    }
}

extension MainViewController : CLLocationManagerDelegate {
    
    func locationManager(manager: CLLocationManager, didStartMonitoringForRegion region: CLRegion) {
        reloadDataSource()
        tableView.reloadData()
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations[0]
        Rover.updateLocation(location)
        manager.stopUpdatingLocation()
    }
}
