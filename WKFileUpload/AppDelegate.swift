//
//  AppDelegate.swift
//  WKFileUpload
//
//  Created by Brian on 01/10/19.
//  Copyright © 2019 WeKan. All rights reserved.
//

import AWSMobileClient
import AWSS3
import CoreData
import UIKit
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var backgroundTask = UIBackgroundTaskIdentifier.invalid
    
    /// To notify on upload complete
    let notificationCenter = UNUserNotificationCenter.current()

    // MARK: UIApplication Lifecycle

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
//        UIApplication.shared.setMinimumBackgroundFetchInterval(60)
        backgroundTask = application.beginBackgroundTask(withName: appBackgroundDownloadTask, expirationHandler: {
            // This expirationHandler is called when your task expired
            // Cleanup the task here, remove objects from memory, etc

            application.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = UIBackgroundTaskIdentifier.invalid
        })
        
        // Setup local notification, to notify when download tasks gets completed
        notificationCenter.delegate = self
        notificationCenter.getNotificationSettings { (settings) in
          if settings.authorizationStatus != .authorized {
            // Notifications not allowed
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            self.notificationCenter.requestAuthorization(options: options) { (didAllow, error) in
                if !didAllow {
                    print("User has declined notifications")
                }
                if error != nil {
                    print(error?.localizedDescription)
                }
            }
          }
        }        
        return true
    }
    
    func endBackgroundTask() {
        UIApplication.shared.endBackgroundTask(self.backgroundTask)
        self.backgroundTask = UIBackgroundTaskIdentifier.invalid
    }

    func application(_ application: UIApplication,
                         handleEventsForBackgroundURLSession identifier: String,
                         completionHandler: @escaping () -> Void) {
        AWSMobileClient.default().initialize { (userState, error) in
            guard error == nil else {
                print("Error initializing AWSMobileClient. Error: \(error!.localizedDescription)")
                return
            }
            print("AWSMobileClient initialized.")
        }
         //provide the completionHandler to the TransferUtility to support background transfers.
         AWSS3TransferUtility.interceptApplication(application,
                                                   handleEventsForBackgroundURLSession: identifier,
                                                   completionHandler: completionHandler)
     }

     func applicationDidBecomeActive(_ application: UIApplication) {
         // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        //clear the icon badge number when app is opened
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        // to relaunch tasks that were running when the app went inactive last time by the system, and not force closed by the user.
        let transferUtility = AWSS3TransferUtility.s3TransferUtility(forKey: s3TransferUtilityServiceKey)
        if transferUtility != nil {
            guard let multiPartUploadTasks = transferUtility!.getMultiPartUploadTasks().result as? [AWSS3TransferUtilityMultiPartUploadTask] else { return }
            print(multiPartUploadTasks)
            if !(multiPartUploadTasks.isEmpty) {
                for task in multiPartUploadTasks {
                    task.setCompletionHandler(AWSUploadManager.shared.completionHandler!)
                    task.setProgressBlock(AWSUploadManager.shared.progressBlock!)
                }
            }
        }
     }

     func applicationWillTerminate(_ application: UIApplication) {
         // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
         // Saves changes in the application's managed object context before the application terminates.
         self.saveContext()
     }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "WKFileUpload")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                print("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                print("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}

extension UIApplication {
    /// Run a block in background after app resigns activity
    public func runInBackground(_ closure: @escaping () -> Void, expirationHandler: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let taskID: UIBackgroundTaskIdentifier
            if let expirationHandler = expirationHandler {
                taskID = self.beginBackgroundTask(expirationHandler: expirationHandler)
            } else {
                taskID = self.beginBackgroundTask(expirationHandler: { })
            }
            closure()
            self.endBackgroundTask(taskID)
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }
}
