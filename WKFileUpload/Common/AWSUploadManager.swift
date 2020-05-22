//
//  AWSUploadManager.swift
//  WKFileUpload
//
//  Created by Brian on 01/10/19.
//  Copyright © 2019 WeKan. All rights reserved.
//

import AWSS3
import Foundation

class AWSUploadManager {
    static let shared = AWSUploadManager()
    /// Array of files to be uploaded
    var filesToUpload: [AWSUploadFile] = []
    /// Flag that says whether files should be encrypted while uploading
    var shouldEncrypt = false
    /// the completion handler block for file upload
    @objc var completionHandler: AWSS3TransferUtilityMultiPartUploadCompletionHandlerBlock?
    /// the block for upload progress
    @objc var progressBlock: AWSS3TransferUtilityMultiPartProgressBlock?

    typealias OnUploadSuccess = (_ file: AWSUploadFile) -> Void
    typealias OnUploadFailure = (_ errorMessage: String) -> Void
    
    @objc lazy var transferUtility = {
         AWSS3TransferUtility.default()
    }()
    
    /// configure and register for AWS transfer
    func registerAWSTransfer() {
        //Setup credentials, see your awsconfiguration.json for the "YOUR-IDENTITY-POOL-ID"
          let credentialProvider = AWSCognitoCredentialsProvider(regionType: s3RegionType, identityPoolId: s3CognitoIdentityPoolId)

          //Setup the aws service configuration
          let configuration = AWSServiceConfiguration(region: s3RegionType, credentialsProvider: credentialProvider)

        AWSServiceManager.default().defaultServiceConfiguration = configuration

          //Setup the transfer utility configuration
          let tuConf = AWSS3TransferUtilityConfiguration()
          tuConf.isAccelerateModeEnabled = true
          tuConf.bucket = s3BucketName

          //Register a transfer utility object asynchronously
          AWSS3TransferUtility.register(
              with: configuration!,
              transferUtilityConfiguration: tuConf,
              forKey: s3TransferUtilityServiceKey
          ) { (err) in
              if let error = err {
                  //Handle registration error.
                  print(error.localizedDescription)
              }
          }
    }
    
    /// method that create background tasks to upload files in a viewcontroller
    /// - Parameter files: list of files to be uploaded
    /// - Parameter viewController: the viewcontroller that initiated the upload. Progress updates will be send back to this viewcontroller
    func uploadFiles(files: [AWSUploadFile],
                     fromController viewController: AWSUploadViewController,
                     shouldEncrypt encryptFile: Bool? = nil,
                     success onSuccess: @escaping OnUploadSuccess ,
                     failure onFailure: @escaping OnUploadFailure) {
        UIApplication.shared.runInBackground({
              self.shouldEncrypt = encryptFile ?? false
              self.filesToUpload = files
              for index in 0..<self.filesToUpload.count {
                self.uploadFile(atIndex: index, fromController: viewController, success: { (uploadFile) in
                    onSuccess(uploadFile)
                }, failure: { (errorMessage) in
                    print(errorMessage)
                })
              }
        }, expirationHandler: {
            print("expired")
        })
    }
    
    /// method to upload a file
    /// - Parameter index: index of file to be uploaded (index in the filesToUpload array)
    /// - Parameter viewController: the viewcontroller that initiated the upload. Progress updates will be send back to this viewcontroller
    func uploadFile(atIndex index: Int,
                    fromController viewController: AWSUploadViewController,
                    success onSuccess: @escaping OnUploadSuccess ,
                    failure onFailure: @escaping OnUploadFailure) {
        let file: AWSUploadFile = self.filesToUpload[index]
        let timestamp = NSDate().timeIntervalSince1970
        let uploadFileName: String = "public/testImage\(timestamp).png"
        
        // Set the Progress block to handle upload progress
        setUploadProgressHandler(for: file, at: index)
        
        // Set the completion block to handle the upload completion
        self.completionHandler = { (task, error) -> Void in
            DispatchQueue.main.async(execute: {
                if let error = error {
                    // Handle image upload error. Pass it to UI if required
                    print("Error for Image \(String(describing: file.fileIndex)): \(String(describing: error.localizedDescription))")
                    file.uploadStatus = UploadStatus.failed.rawValue
                    onFailure(error.localizedDescription)
                    self.filesToUpload[index] = file
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotificationName.uploadFailed), object: file)
                } else {
                    print("Task completed")
                    print(task.bucket)
                    print(task.key)
                    // Handle Upload completion, send it to UI
                    let indexpath = IndexPath(item: index, section: 0)
                    let cell = viewController.imagesCollectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell",
                                                                                       for: indexpath) as? ImageCollectionViewCell
                    if cell?.progressView.progress == 1.0 {
                        file.uploadProgress = 1.0
                        file.uploadStatus = UploadStatus.complete.rawValue
                        file.s3UrlPath = task.key
                        self.filesToUpload[index] = file
                        onSuccess(file)
                        let encodedData = try? JSONEncoder().encode(file)
                        let dict = try? JSONSerialization.jsonObject(with: encodedData ?? Data(), options: .allowFragments)
                        NotificationCenter.default.post(name: NSNotification.Name(NotificationName.uploadInProgress),
                                                        object: file,
                                                        userInfo: dict as? [AnyHashable: Any])
                    }
                    
                    self.scheduleNotification(message: String("testImage\(timestamp).png"))
                }
            })
        }
        
        // Upload using multipart and assign the progress and completion blocks
        let expression = AWSS3TransferUtilityMultiPartUploadExpression()
        expression.setValue("public-read-write", forRequestHeader: "x-amz-acl")
        if shouldEncrypt {
            expression.setValue("aws:kms", forRequestHeader: "s3:x-amz-server-side-encryption")
        }
        expression.progressBlock = self.progressBlock
        self.transferUtility.uploadUsingMultiPart(data: file.fileData!,
                                                  bucket: s3BucketName,
                                                  key: uploadFileName,
                                                  contentType: file.fileType ?? "image/png",
                                                  expression: expression,
                                                  completionHandler: self.completionHandler).continueWith { (task) -> AnyObject? in
                                                    if let error = task.error {
                                                        print(error)
                                                        print("Error: \(error.localizedDescription)")
                                                        DispatchQueue.main.async {
                                                            onFailure(error.localizedDescription)
                                                            NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotificationName.uploadFailed), object: "Failed")
                                                        }
                                                    }
                                                    if let _ = task.result {
                                                        DispatchQueue.main.async {
                                                            print("Upload Starting!")
                                                        }
                                                    }
                                                    return nil
        }
    }
    
    
    /// Handle the upload progress of each file. Update the progress onn UI if rerequired
    /// - Parameters:
    ///   - file: the file that is being uploaded. progress will be availale in file.uploadProgress
    ///   - index: index of the file being uploaded among the list of all files being uploaded
    func setUploadProgressHandler(for file: AWSUploadFile, at index: Int) {
        self.progressBlock = {(task, progress) in
            print("Image \(String(describing: file.fileIndex)): \(progress.fractionCompleted)")
            
            // If progress needs to be shown in the UI, do it here
            DispatchQueue.main.async(execute: {
                // Update the progress in model
                file.uploadProgress = Float(progress.fractionCompleted)
                file.uploadStatus = (progress.fractionCompleted == 1.0) ? UploadStatus.complete.rawValue : UploadStatus.inProgress.rawValue
                self.filesToUpload[index] = file
                
                // Send the progress update to UI
                let encodedData = try? JSONEncoder().encode(file)
                let dict = try? JSONSerialization.jsonObject(with: encodedData ?? Data(), options: .allowFragments)
                NotificationCenter.default.post(name: NSNotification.Name(NotificationName.uploadInProgress),
                                                object: file,
                                                userInfo: dict as? [AnyHashable: Any])
            })
        }
    }

    
    /// To add a local notification on upload success
    func scheduleNotification(message: String) {
        let content = UNMutableNotificationContent()
        content.title = message
        content.body = "Upload complete"
        content.sound = UNNotificationSound.default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: content.title, content: content, trigger: trigger)
        appDelegate.notificationCenter.add(request) { (error) in
            if let error = error {
                print("Error \(error.localizedDescription)")
            }
        }
    }
}
