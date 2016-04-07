//
//  LocationViewController.swift
//  Rover
//
//  Created by Ata Namvari on 2016-03-11.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import MapKit

class LocationViewController: UIViewController {
    
    @IBOutlet weak var spoofBarButtonItem: UIBarButtonItem!
    
    var selectedLocation: CLLocation?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Actions
    
    @IBAction func didPressClose(sender: AnyObject) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func didLongPress(sender: UILongPressGestureRecognizer) {
        guard sender.state != .Ended, let mapView = sender.view as? MKMapView else { return }
        
        mapView.removeAnnotations(mapView.annotations)
        
        let point = sender.locationInView(mapView)
        let coordinate = mapView.convertPoint(point, toCoordinateFromView: mapView)
        let annotation = LocationAnnotation(coordinate: coordinate)
        
        selectedLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        mapView.addAnnotation(annotation)
        
        spoofBarButtonItem.enabled = true
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

extension LocationViewController : MKMapViewDelegate {
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is LocationAnnotation else { return nil }
        
        var pin = mapView.dequeueReusableAnnotationViewWithIdentifier("annotationView") as? MKPinAnnotationView
        if (pin == nil) {
            pin = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "annotationView")
        } else {
            pin?.annotation = annotation
        }
        
        pin?.pinColor = .Purple
        pin?.animatesDrop = true
        
        return pin
    }
}

class LocationAnnotation : NSObject, MKAnnotation {

    let coordinate: CLLocationCoordinate2D
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
    }
    
    //optional public var title: String? { get }
    //optional public var subtitle: String? { get }
}