//
//  RecordViewController.swift
//  GPS Recording
//
//  Created by Aaron Blondeau on 6/4/18.
//  Copyright © 2018 Aaron Blondeau. All rights reserved.
//

import UIKit

class RecordViewController: UIViewController {

    @IBOutlet weak var textTrackName: UITextField!
    @IBOutlet weak var buttonSave: UIButton!
    @IBOutlet weak var buttonStart: UIButton!
    @IBOutlet weak var buttonPause: UIButton!
    @IBOutlet weak var buttonResume: UIButton!
    @IBOutlet weak var buttonFinish: UIButton!
    
    var store: GPSRecordingStore?
    var service: GPSRecordingService?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    
        NotificationCenter.default.addObserver(self, selector: #selector(storeLoaded(notification:)), name: .gpsRecordingStoreReady, object: nil)
        if store != nil {
            buttonSave.isEnabled = true
        }
    }
    
    @objc func storeLoaded(notification: NSNotification) {
        self.store = notification.object as? GPSRecordingStore
        buttonSave.isEnabled = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        self.title = "Record"
    }
    
    @IBAction func buttonSaveTap(_ sender: Any) {
        if (self.store != nil) {
            do {
                let _ = try store!.createTrack(name: textTrackName.text, note: "I am a fake track", activity: nil)
            } catch {
                print("Failed to create track : \(error.localizedDescription)")
            }
            navigationController?.popViewController(animated: true)
        } else {
            print("~~ Store is nil!")
        }
    }
    
    @IBAction func buttonStartTap(_ sender: Any) {
        service?.start()
        updateButtons()
    }
    
    @IBAction func buttonPauseTap(_ sender: Any) {
        service?.pause()
        updateButtons()
    }
    
    @IBAction func buttonResumeTap(_ sender: Any) {
        service?.resume()
        updateButtons()
    }
    
    @IBAction func buttonFinishTap(_ sender: Any) {
        service?.finish()
        updateButtons()
    }
    
    func updateButtons() {
        if let service = service {
            buttonStart.isEnabled = !service.recording
            buttonStart.isHidden = service.hasCurrentTrack || service.recording
            
            buttonPause.isEnabled = service.recording
            buttonPause.isHidden = !service.recording
            
            buttonResume.isEnabled = !service.recording && service.hasCurrentTrack
            buttonResume.isHidden = service.recording || !service.hasCurrentTrack
            
            buttonFinish.isEnabled = service.hasCurrentTrack
            buttonFinish.isHidden = !service.hasCurrentTrack
        } else {
            buttonStart.isEnabled = false
            buttonPause.isEnabled = false
            buttonResume.isEnabled = false
            buttonFinish.isEnabled = false
            
            buttonStart.isHidden = false
            buttonPause.isHidden = true
            buttonResume.isHidden = true
            buttonFinish.isHidden = true
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}