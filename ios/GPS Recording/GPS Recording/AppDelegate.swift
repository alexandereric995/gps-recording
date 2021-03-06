//
//  AppDelegate.swift
//  GPS Recording
//
//  Created by Aaron Blondeau on 5/15/18.
//  Copyright © 2018 Aaron Blondeau. All rights reserved.
//

import UIKit
import CoreData
import WatchConnectivity

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, WCSessionDelegate {

    var window: UIWindow?

    var store: GPSRecordingStore?
    var serviceManager: GPSRecordingServiceManager?
    
    var wcUserInfoQueue: [[String : Any]]?
    var wcSessionFileQueue: [WCSessionFile]?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        wcUserInfoQueue = [[String : Any]]()
        wcSessionFileQueue = [WCSessionFile]()
        
        self.setupWatchConnectivity()
        
        // Get access to the recording store
        let bundle = Bundle(for: type(of: self))
        GPSRecordingStore.buildContainer(bundle: bundle) {
            (container: NSPersistentContainer) in
            self.store = GPSRecordingStore(withContainer: container)
            self.serviceManager = GPSRecordingServiceManager(self.store!)
            if let navigationViewController = self.window?.rootViewController as? UINavigationController {
                if let firstViewController = navigationViewController.viewControllers.first as? ViewController {
                    firstViewController.store = self.store
                    firstViewController.serviceManager = self.serviceManager
                }
            }
            NotificationCenter.default.post(name: .gpsRecordingStoreReady, object: self.store)
            self.sendRecordStatus()
            self.processWCUserInfoQueue()
            self.processWCSessionFileQueue()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(onRecordingStarted(notification:)), name: .gpsRecordingStarted, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onRecordingStopped(notification:)), name: .gpsRecordingStopped, object: nil)
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        print("~~ App did enter background")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        if let context = store?.container.viewContext {
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    // Replace this implementation with code to handle the error appropriately.
                    // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    let nserror = error as NSError
                    fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
                }
            }
        }
    }
    
    // MARK: - Watch Connectivity
    
    func setupWatchConnectivity() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WC Session did become inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("WC Session did deactivate")
        WCSession.default.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith
        activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WC Session activation failed with error: \(error.localizedDescription)")
            return
        }
        print("WC Session activated with state: \(activationState.rawValue)")
    }
    
    @objc func onRecordingStarted(notification: NSNotification) {
        sendRecordStatus()
    }
    
    @objc func onRecordingStopped(notification: NSNotification) {
        sendRecordStatus()
    }
    
    func sendRecordStatus() {
        if WCSession.isSupported() {
            let session = WCSession.default
            if session.isWatchAppInstalled {
                do {
                    var dictionary = ["phone_recording": false]
                    if let service = serviceManager?.service {
                        dictionary = ["phone_recording": service.recording]
                    }
                    try session.updateApplicationContext(dictionary)
                } catch {
                    print("ERROR: \(error)")
                }
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext:[String:Any]) {
        if let watch_recording = applicationContext["watch_recording"] as? Bool {
            if (watch_recording) {
                print("~~ Phone: watch sent message to say it is recording")
            } else {
                print("~~ Phone: watch sent message to say it is not recording")
            }
        }
    }
    
    func enqueueWCSessionFile(_ file: WCSessionFile) {
        print("~~ queueing a wc session file")
        wcSessionFileQueue?.append(file)
    }
    
    func enqueueWCUserInfo(_ userInfo: [String : Any] = [:]) {
        print("~~ queueing a wc userinfo item")
        wcUserInfoQueue?.append(userInfo)
    }

    
    func processWCUserInfoQueue() {
        if let items = wcUserInfoQueue, let store = self.store {
            print("~~ processing \(items.count) wc userinfo items")
            for item in items {
                processWCUserInfo(store, WCSession.default, item)
            }
        }
    }
    
    func processWCSessionFileQueue() {
        if let files = wcSessionFileQueue, let store = self.store {
            print("~~ processing \(files.count) wc session files")
            for file in files {
                processWCSessionFile(store, WCSession.default, file)
            }
        }
    }
    
    func processWCUserInfo(_ store: GPSRecordingStore, _ session : WCSession, _ userInfo: [String : Any] = [:]) {
        
        if let action = userInfo["action"] as? String {
            if (action == "track_from_watch") {
                print("~~ Phone got a track from the watch")
                
                // Check if a there is already a track with upstreamId = userInfo["id"]
                if let upstreamId = userInfo["id"] as? String {
                    if let existingTrack = store.getTrackWithUpstreamId(upstreamId) {
                        print("~~ Watch tried to sync an existing track \(existingTrack.upstreamId ?? "?")")
                        return;
                    }
                }
                
                do {
                    let track = try store.trackFromDict(userInfo)
                    var info = [String: Any]()
                    info["action"] = "track_from_watch_result"
                    info["id"] = track.upstreamId
                    info["downstreamId"] = track.objectID.uriRepresentation().absoluteString
                    info["success"] = true
                    session.transferUserInfo(info)
                } catch {
                    var info = [String: Any]()
                    info["action"] = "track_from_watch_result"
                    info["id"] = userInfo["id"] as? String
                    info["error"] = error.localizedDescription
                    session.transferUserInfo(info)
                }
            
            }
            else if (action == "open_track_from_watch") {
                if let store = self.store, let id = userInfo["id"] as? String {
                    if let url = URL(string: id) {
                        DispatchQueue.main.async {
                            if let trackViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "trackViewController") as? TrackViewController,
                                let navigationViewController = self.window?.rootViewController as? UINavigationController,
                                let track = store.getTrack(atURL: url) {
                                trackViewController.store = store
                                trackViewController.track = track
                                navigationViewController.pushViewController(trackViewController, animated: true)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func processWCSessionFile(_ store: GPSRecordingStore, _ session : WCSession, _ file: WCSessionFile) {
        if let action = file.metadata?["action"] as? String {
            if (action == "track_from_watch") {
                
                print("~~ inflating track_from_watch : \(file.fileURL.path)")
                
                if var userInfo = NSKeyedUnarchiver.unarchiveObject(withFile: file.fileURL.path) as! [String: Any]? {
                    userInfo["action"] = action
                    processWCUserInfo(store, session, userInfo)
                    
                    // TODO - delete file?
                } else {
                    print("~~ processWCSessionFile was unable to unarchive file!")
                }
                
            } else {
                print("~~ processWCSessionFile got an unknown action : \(action)")
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        if let store = self.store {
            processWCUserInfo(store, session, userInfo)
        } else {
            // Store wasn't ready : add to queue
            enqueueWCUserInfo(userInfo)
        }
    }
    
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        if let store = self.store {
            processWCSessionFile(store, session, file)
        } else {
            // Store wasn't ready : add to queue
            enqueueWCSessionFile(file)
        }
    }

}

