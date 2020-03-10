//
//  AWSUploadTests.swift
//  WKFileUploadTests
//
//  Created by Brian on 08/10/19.
//  Copyright © 2019 WeKan. All rights reserved.
//

import XCTest

@testable import WKFileUpload

class AWSUploadTests: XCTestCase {
    var awsUploadViewModel: AWSUploadViewModel!
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        self.awsUploadViewModel = AWSUploadViewModel()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func allUploadsInitiated() {
        
    }
    
    func allUploadsFinished() {
        
    }
    
    func uploadFailedOnNetworkFailureAndUploadRestartsOnNetworkAvailable() {
        
    }
    
    func uploadsPausesWhenAppGoesBackgroundAndResumesWhenAppOpens() {
        
    }

}
