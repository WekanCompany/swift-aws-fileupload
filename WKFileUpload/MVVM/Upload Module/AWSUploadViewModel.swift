//
//  AWSUploadViewModel.swift
//  WKFileUpload
//
//  Created by Brian on 01/10/19.
//  Copyright © 2019 WeKan. All rights reserved.
//

import AWSS3
import Foundation
import Photos

class AWSUploadViewModel {
    var selectedImageAssets: [PHAsset] = []
    var imageModelArray: [AWSUploadFile] = []

    @objc var completionHandler: AWSS3TransferUtilityMultiPartUploadCompletionHandlerBlock?
    @objc var progressBlock: AWSS3TransferUtilityMultiPartProgressBlock?

    /// method to check and request permissions from the user for photo capturing and photo selection from album.
    func checkAndRequestPermissions() {
        let photoAuthorizationStatus = PHPhotoLibrary.authorizationStatus()
        switch photoAuthorizationStatus {
        case .authorized:
            print("Access is granted by user")
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({ (newStatus) in print("status is \(newStatus)")
                if newStatus == PHAuthorizationStatus.authorized {
                    // do stuff here */
                    print("success")
                }
            })
            
        case .restricted:
            print("User do not have access to photo album.")
            
        case .denied:
            print("User has denied the permission.")
            
        @unknown default:
                print("default")
            }
    }
    
    /// method that initiates the upload of files to s3
    func uploadFiles(forController viewController: AWSUploadViewController) {
        AWSUploadManager.shared.uploadFiles(files: self.imageModelArray, fromController: viewController, success: { (uploadFile) in
            print(uploadFile)
        }, failure: { (errorMessage) in
            print(errorMessage)
        })
    }
    
    /// method to retry any uploads that fails
    func retryUpload(forFileAt index: Int, forController viewController: AWSUploadViewController) {
        DispatchQueue.main.async {
            AWSUploadManager.shared.uploadFile(atIndex: index, fromController: viewController, success: { (uploadFile) in
                print("Retry: \(uploadFile)")
            }, failure: { (errorMessage) in
                print(errorMessage)
            })
        }
    }
    
    /**
        Converts PHAsset to UIImage
        - Used while creating a post with multiple images
        - Parameter asset: the asset to be converted to image
        - Parameter size: the size required for the image
        - returns: returns the asset as UIImage
        */
        func getUIImageFromAsset(asset: PHAsset, forSize size: CGSize) -> UIImage {
           let manager = PHImageManager.default()
           let option = PHImageRequestOptions()
           var thumbnail = UIImage()
           option.isSynchronous = true
           manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill,
                                options: option,
                                resultHandler: {(result, info) -> Void in
               thumbnail = result!
           })
           return thumbnail
       }
}
