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
    
    @IBAction func didPressClose(_ sender: AnyObject) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func didLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state != .ended, let mapView = sender.view as? MKMapView else { return }
        
        mapView.removeAnnotations(mapView.annotations)
        
        let point = sender.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        let annotation = LocationAnnotation(coordinate: coordinate)
        
        selectedLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        mapView.addAnnotation(annotation)
        
        spoofBarButtonItem.isEnabled = true
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
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is LocationAnnotation else { return nil }
        
        var pin = mapView.dequeueReusableAnnotationView(withIdentifier: "annotationView") as? MKPinAnnotationView
        if (pin == nil) {
            pin = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "annotationView")
        } else {
            pin?.annotation = annotation
        }
        
        pin?.pinColor = .purple
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
