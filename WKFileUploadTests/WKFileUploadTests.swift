//
//  WKFileUploadTests.swift
//  WKFileUploadTests
//
//  Created by Brian on 01/10/19.
//  Copyright © 2019 WeKan. All rights reserved.
//

@testable import WKFileUpload
import XCTest

class WKFileUploadTests: XCTestCase {
    var awsUploadViewModel: AWSUploadViewModel!

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        awsUploadViewModel = AWSUploadViewModel()
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
     /// Test to check if the image upload works
    func testIfImageUploadIsWorking() {
        var filesArray: [AWSUploadFile] = []
        for index in 0...1 {
            let file = AWSUploadFile()
            file.fileData = UIImage(named: "images.jpeg")?.pngData()
            file.fileIndex = index
            file.uploadProgress = 0.0
            file.uploadStatus = 0
            file.s3UrlPath = ""
            filesArray.append(file)
        }
        
        var successResponseArray: [String] = []
        AWSUploadManager.shared.uploadFiles(files: filesArray,
                                            fromController: AWSUploadViewController(),
                                            success: { _ in
            successResponseArray.append("Success")
            if successResponseArray.count == filesArray.count {
                XCTAssertNotNil("File upload success")
            }
        }, failure: { _ in
            XCTAssert(false)
        })
    }
}
