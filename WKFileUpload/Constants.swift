//
//  Constants.swift
//  WKFileUpload
//
//  Created by Brian on 01/10/19.
//  Copyright © 2019 WeKan. All rights reserved.
//

import Foundation
import UIKit
import AWSS3

/// The Cognito pool Identifier for the IAM user
let s3CognitoIdentityPoolId: String = "us-east-1:42470987-3f6d-4268-889a-ea2bb05693e4"
/// Name of the folder to which files should be uploaded
let s3BucketName: String = "mvvm"
///  The region in which our identity pool exists
let s3RegionType: AWSRegionType = .USEast1
/// Name of file to be uploaded
let s3UploadKeyName: String = "public/testimage.png"
/// A name identifier for the transer service
let s3TransferUtilityServiceKey: String = "transfer-utility-with-advanced-options"
/// App background task name
let appBackgroundDownloadTask: String = "AppBackgroundDownloadTask"

let appDelegate: AppDelegate = UIApplication.shared.delegate as? AppDelegate ?? AppDelegate()

/// Enum with all types of Files the app supports for upload .
/// - raw value : Int
enum UploadFileType: String {
    case document = "text/html"
    case imageFile = "image/png"
    case videoFile = "video/mov"
}

/// Enum with all status for FIle Upload.
/// - raw value : Int
enum UploadStatus: Int {
    case notStarted = 0
    case complete = 1
    case inProgress = 2
    case failed = 3
}

///List of constants that define the maximum limits
struct Maximum {
   static let uploadFileCount = 5
}

struct NotificationName {
    static let uploadInProgress = "uploadInProgress"
    static let uploadFailed = "uploadFailed"
}
