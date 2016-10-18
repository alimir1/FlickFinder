//
//  ViewController.swift
//  FlickFinder
//
//  Created by Jarrod Parkes on 11/5/15.
//  Edited and modified by Ali Mir on 10/18/16.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - ViewController: UIViewController

class ViewController: UIViewController {
    
    // MARK: Properties
    
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var photoTitleLabel: UILabel!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var phraseSearchButton: UIButton!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var latLonSearchButton: UIButton!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        phraseTextField.delegate = self
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
        subscribeToNotification(UIKeyboardWillShowNotification, selector: #selector(keyboardWillShow))
        subscribeToNotification(UIKeyboardWillHideNotification, selector: #selector(keyboardWillHide))
        subscribeToNotification(UIKeyboardDidShowNotification, selector: #selector(keyboardDidShow))
        subscribeToNotification(UIKeyboardDidHideNotification, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Search Actions
    
    @IBAction func searchByPhrase(sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if !phraseTextField.text!.isEmpty {
            photoTitleLabel.text = "Searching..."
            // TODO: Set necessary parameters!
            let methodParameters: [String: String!] = [
                Constants.FlickrParameterKeys.Method : Constants.FlickrParameterValues.SearchMethod,
                Constants.FlickrParameterKeys.APIKey : Constants.FlickrParameterValues.APIKey,
                Constants.FlickrParameterKeys.Text : phraseTextField.text,
                Constants.FlickrParameterKeys.SafeSearch : Constants.FlickrParameterValues.UseSafeSearch,
                Constants.FlickrParameterKeys.Extras : Constants.FlickrParameterValues.MediumURL,
                Constants.FlickrParameterKeys.Format : Constants.FlickrParameterValues.ResponseFormat,
                Constants.FlickrParameterKeys.NoJSONCallback : Constants.FlickrParameterValues.DisableJSONCallback
            ]
            displayImageFromFlickrBySearch(methodParameters)
        } else {
            setUIEnabled(true)
            photoTitleLabel.text = "Phrase Empty."
        }
    }
    
    @IBAction func searchByLatLon(sender: AnyObject) {
        userDidTapView(self)
        setUIEnabled(false)
        
        if isTextFieldValid(latitudeTextField, forRange: Constants.Flickr.SearchLatRange) && isTextFieldValid(longitudeTextField, forRange: Constants.Flickr.SearchLonRange) {
            photoTitleLabel.text = "Searching..."
            // TODO: Set necessary parameters!
            let methodParameters: [String: String!] = [
                Constants.FlickrParameterKeys.Method : Constants.FlickrParameterValues.SearchMethod,
                Constants.FlickrParameterKeys.APIKey : Constants.FlickrParameterValues.APIKey,
                Constants.FlickrParameterKeys.BoundingBox : bboxString(),
                Constants.FlickrParameterKeys.SafeSearch : Constants.FlickrParameterValues.UseSafeSearch,
                Constants.FlickrParameterKeys.Extras : Constants.FlickrParameterValues.MediumURL,
                Constants.FlickrParameterKeys.Format : Constants.FlickrParameterValues.ResponseFormat,
                Constants.FlickrParameterKeys.NoJSONCallback : Constants.FlickrParameterValues.DisableJSONCallback
            ]
            displayImageFromFlickrBySearch(methodParameters)
        }
        else {
            setUIEnabled(true)
            photoTitleLabel.text = "Lat should be [-90, 90].\nLon should be [-180, 180]."
        }
    }
    
    private func bboxString() -> String {
        guard let lon = Double(longitudeTextField.text!), let lat = Double(latitudeTextField.text!) else {
            return "0,0,0,0"
        }
        
        let lonMin = min(lon-Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.0)
        let lonMax = max(lon+Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.1)
        let latMin = min(lat-Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.0)
        let latMax = max(lat+Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.1)
        
        return "\(lonMin),\(latMin),\(lonMax),\(latMax)"
    }
    
    // MARK: Flickr API
    
    private func displayImageFromFlickrBySearch(methodParameters: [String:AnyObject]) {
        let session = NSURLSession.sharedSession()
        let request = NSURLRequest(URL: flickrURLFromParameters(methodParameters))
        
        let task = session.dataTaskWithRequest(request) {
            (data, response, error) in
            
            func displayError(error: String) {
                print(error)
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.photoTitleLabel.text = "No photo returned. Try again."
                    self.photoImageView.image = nil
                }
            }
            
            // GUARD: Check error
            guard (error == nil) else {
                displayError(error!.localizedDescription)
                return
            }
            
            // GUARD: Check if successful 2xx response
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                displayError("No data was returned by the request!")
                return
            }
            
            // GUARD: Check if data was returned
            guard let rawData = data else {
                displayError("Data was not successfully returned!")
                return
            }
            
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(rawData, options: .AllowFragments)
            } catch {
                displayError("Could not parse data as JSON: \(rawData)")
                return
            }
            
            // GUARD: Check if Flickr returned an error (stat != ok)
            guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String where stat == Constants.FlickrResponseValues.OKStatus else {
                displayError("Flickr status error. Check following: \(parsedResult)")
                return
            }
            
            // GUARD: Check to see if "Photos" exist in parsedResults
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String : AnyObject] else {
                displayError("Could not find \(Constants.FlickrResponseKeys.Photos) in \(parsedResult)")
                return
            }
            
            // GUARD: Check to see if there are any photos in the photosDictionary
            guard let photosArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as? [[String : AnyObject]] else {
                displayError("Could not find \(Constants.FlickrResponseKeys.Photo) in \(photosDictionary)")
                return
            }
            
            if photosArray.count < 1 {
                displayError("No images found. Search again!")
                return
            } else {
                let randomPhotoIndex = Int(arc4random_uniform(UInt32(photosArray.count)))
                let randomPhotoDictionary = photosArray[randomPhotoIndex] as [String : AnyObject]
                let photoTitle = randomPhotoDictionary[Constants.FlickrResponseKeys.Title] as? String
                
                // GUARD: Check if photo has "url_m" key
                guard let imageURLString = randomPhotoDictionary[Constants.FlickrResponseKeys.MediumURL] as? String else {
                    displayError("Cannot find image url. \(randomPhotoDictionary)")
                    return
                }
                
                // Set image and title if image exists in the url
                let imageURL = NSURL(string: imageURLString)
                if let imageData = NSData(contentsOfURL: imageURL!) {
                    performUIUpdatesOnMain {
                        self.photoImageView.image = UIImage(data: imageData)
                        self.photoTitleLabel.text = photoTitle ?? "(Untitled)"
                        self.setUIEnabled(true)
                    }
                } else {
                    displayError("Image does not exist at \(imageURL!)")
                    return
                }
            }
        }
        
        task.resume()
        
    }
    
    // MARK: Helper for Creating a URL from Parameters
    
    private func flickrURLFromParameters(parameters: [String:AnyObject]) -> NSURL {
        
        let components = NSURLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [NSURLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = NSURLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        return components.URL!
    }
}

// MARK: - ViewController: UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(notification: NSNotification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
        }
    }
    
    func keyboardDidShow(notification: NSNotification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(notification: NSNotification) {
        keyboardOnScreen = false
    }
    
    private func keyboardHeight(notification: NSNotification) -> CGFloat {
        let userInfo = notification.userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.CGRectValue().height
    }
    
    private func resignIfFirstResponder(textField: UITextField) {
        if textField.isFirstResponder() {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(sender: AnyObject) {
        resignIfFirstResponder(phraseTextField)
        resignIfFirstResponder(latitudeTextField)
        resignIfFirstResponder(longitudeTextField)
    }
    
    // MARK: TextField Validation
    
    private func isTextFieldValid(textField: UITextField, forRange: (Double, Double)) -> Bool {
        if let value = Double(textField.text!) where !textField.text!.isEmpty {
            return isValueInRange(value, min: forRange.0, max: forRange.1)
        } else {
            return false
        }
    }
    
    private func isValueInRange(value: Double, min: Double, max: Double) -> Bool {
        return !(value < min || value > max)
    }
}

// MARK: - ViewController (Configure UI)

extension ViewController {
    
    private func setUIEnabled(enabled: Bool) {
        photoTitleLabel.enabled = enabled
        phraseTextField.enabled = enabled
        latitudeTextField.enabled = enabled
        longitudeTextField.enabled = enabled
        phraseSearchButton.enabled = enabled
        latLonSearchButton.enabled = enabled
        
        // adjust search button alphas
        if enabled {
            phraseSearchButton.alpha = 1.0
            latLonSearchButton.alpha = 1.0
        } else {
            phraseSearchButton.alpha = 0.5
            latLonSearchButton.alpha = 0.5
        }
    }
}

// MARK: - ViewController (Notifications)

extension ViewController {
    
    private func subscribeToNotification(notification: String, selector: Selector) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    private func unsubscribeFromAllNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}
