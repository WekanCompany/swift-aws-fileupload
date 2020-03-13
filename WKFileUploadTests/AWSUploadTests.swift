//
//  AWSUploadTests.swift
//  WKFileUploadTests
//
//  Created by Brian on 08/10/19.
//  Copyright © 2019 WeKan. All rights reserved.
//

import AWSS3
import CommonCrypto
@testable import WKFileUpload
import XCTest

var testData = Data()
var generalTestBucket = ""

class AWSUploadTests: XCTestCase {
    
    override class func setUp() {
        super.setUp()

        //Setup Log level
        AWSDDLog.sharedInstance.logLevel = .debug
        AWSDDLog.add(AWSDDTTYLogger.sharedInstance)
                
        let credentialProvider = AWSCognitoCredentialsProvider(regionType: s3RegionType, identityPoolId: s3CognitoIdentityPoolId)
        let serviceConfiguration = AWSServiceConfiguration(
            region: s3RegionType,
            credentialsProvider: credentialProvider
        )

        let transferUtilityConfiguration = AWSS3TransferUtilityConfiguration()
        transferUtilityConfiguration.isAccelerateModeEnabled = true

        AWSS3TransferUtility.register(
            with: serviceConfiguration!,
            transferUtilityConfiguration: transferUtilityConfiguration,
            forKey: "transfer-acceleration"
        )
        
        let serviceConfiguration2 = AWSServiceManager.default().defaultServiceConfiguration
        let transferUtilityConfigurationWithRetry = AWSS3TransferUtilityConfiguration()
        transferUtilityConfigurationWithRetry.isAccelerateModeEnabled = false
        transferUtilityConfigurationWithRetry.retryLimit = 10
        transferUtilityConfigurationWithRetry.multiPartConcurrencyLimit = 6
        transferUtilityConfigurationWithRetry.timeoutIntervalForResource = 15*60 //15 minutes
        
        AWSS3TransferUtility.register(
            with: serviceConfiguration2!,
            transferUtilityConfiguration: transferUtilityConfigurationWithRetry,
            forKey: "with-retry"
        )
      
        let serviceConfiguration3 = AWSServiceManager.default().defaultServiceConfiguration
        let transferUtilityConfigurationShortExpiry = AWSS3TransferUtilityConfiguration()
        transferUtilityConfigurationShortExpiry.isAccelerateModeEnabled = false
        transferUtilityConfigurationShortExpiry.retryLimit = 5
        transferUtilityConfigurationShortExpiry.multiPartConcurrencyLimit = 6
        transferUtilityConfigurationShortExpiry.timeoutIntervalForResource = 2 //2 seconds
        
        AWSS3TransferUtility.register(
            with: serviceConfiguration3!,
            transferUtilityConfiguration: transferUtilityConfigurationShortExpiry,
            forKey: "short-expiry"
        )
        
        let serviceConfiguration4 = AWSServiceManager.default().defaultServiceConfiguration
        AWSS3TransferUtility.register(
            with: serviceConfiguration4!,
            transferUtilityConfiguration: nil,
            forKey: "nil-configuration"
        )
        
        let invalidStaticCredentialProvider = AWSStaticCredentialsProvider(accessKey: "Invalid", secretKey: "AlsoInvalid")
        let invalidServiceConfig = AWSServiceConfiguration(region: s3RegionType, credentialsProvider: invalidStaticCredentialProvider)
        AWSS3TransferUtility.register(with: invalidServiceConfig!, forKey: "invalid")
        
        
        var dataString = "1234567890"
        for _ in 1...5 {
            dataString += dataString
        }
        testData = dataString.data(using: String.Encoding.utf8)!
        
        let timeInterval = (Int)((Date.timeIntervalSinceReferenceDate * 1000).rounded())
        generalTestBucket = "s3-integ-transferutil-test-\(timeInterval)"
        AWSS3TestHelper.createBucket(withName: generalTestBucket, andRegion: s3RegionType)
    }

    override class func tearDown() {
        AWSS3TestHelper.deleteAllObjects(fromBucket: generalTestBucket)
        AWSS3TestHelper.deleteBucket(withName: generalTestBucket)
        super.tearDown()
    }
    
    func testMultiPartUploadSmallFile() {
        let expectation = self.expectation(description: "The completion handler called.")
        let transferUtility = AWSS3TransferUtility.default()
        let filePath = NSTemporaryDirectory() + "testMultiPartUploadSmallFile.tmp"
        let fileURL = URL(fileURLWithPath: filePath)
        FileManager.default.createFile(atPath: filePath, contents: "This is a test".data(using: .utf8), attributes: nil)
        
        var calculatedHash:(String) = ""
        if let digestData = sha256(url: fileURL) {
            calculatedHash = digestData.map { String(format: "%02hhx", $0) }.joined()
        }
        
        let expression = AWSS3TransferUtilityMultiPartUploadExpression()
        let uuid:(String) = UUID().uuidString
        let author:(String) = "integration test"
        expression.setValue(author, forRequestHeader: "x-amz-meta-author")
        expression.setValue(uuid, forRequestHeader: "x-amz-meta-id")
        expression.progressBlock = {(task, progress) in
            print("Upload progress: ", progress.fractionCompleted)
        }
        
        //Create Completion Handler
        let uploadCompletionHandler = { (task: AWSS3TransferUtilityMultiPartUploadTask, error: Error?) -> Void in
            XCTAssertNil(error)
            XCTAssertEqual(task.status, AWSS3TransferUtilityTransferStatusType.completed)
            
            //Get Meta Data and verify that it has been updated. This will indicate that the upload has succeeded.
            let s3 = AWSS3.default()
            let headObjectRequest = AWSS3HeadObjectRequest()
            headObjectRequest?.bucket = generalTestBucket
            headObjectRequest?.key = "testMultiPartUploadSmallFile.txt"
            
            
            s3.headObject(headObjectRequest!).continueWith(block: { (task:AWSTask<AWSS3HeadObjectOutput> ) -> Any? in
                XCTAssertNil(task.error)
                XCTAssertNotNil(task.result)
                if (task.result != nil) {
                    let output:(AWSS3HeadObjectOutput) = task.result!
                    XCTAssertNotNil(output)
                    XCTAssertNotNil(output.metadata)
                    XCTAssertEqual(author, output.metadata?["author"])
                    XCTAssertEqual(uuid, output.metadata?["id"])
                }
                //Download the file and make sure that contents are the same.
                self.verifyContent(tu: transferUtility, bucket: generalTestBucket, key: "testMultiPartUploadSmallFile.txt", hash: calculatedHash)
                
                expectation.fulfill()
                return nil
            })
        }
    
        transferUtility.uploadUsingMultiPart(fileURL:fileURL,
                                                 bucket: generalTestBucket,
                                                 key: "testMultiPartUploadSmallFile.txt",
                                                 contentType: "text/plain",
                                                 expression: expression,
                                                 completionHandler: uploadCompletionHandler)
            .continueWith { (task: AWSTask<AWSS3TransferUtilityMultiPartUploadTask>) -> Any? in
                                                    XCTAssertNil(task.error)
                                                    XCTAssertNotNil(task.result)
                                                    return nil
            }.waitUntilFinished()
        
        waitForExpectations(timeout: 90) { (error) in
            XCTAssertNil(error)
        }
    }

    func testMultiPartUploadLargeFile() {
        //Create a large temp file;
      
        let customerKey = "MTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTI="
        let customerKeyMD5 = "dnF5x6K/8ZZRzpfSlMMM+w=="
        let filePath = NSTemporaryDirectory() + "testMultiPartUploadLargeFile.tmp"
        var testData = "Test123456789"
        for _ in 1...21 {
            testData = testData + testData;
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        FileManager.default.createFile(atPath: filePath, contents: testData.data(using: .utf8), attributes: nil)
        
        var calculatedHash:(String) = ""
        if let digestData = sha256(url: fileURL) {
            calculatedHash = digestData.map { String(format: "%02hhx", $0) }.joined()
        }
        
        let transferUtility = AWSS3TransferUtility.s3TransferUtility(forKey: "with-retry")
        XCTAssertNotNil(transferUtility)
        
        
        let expectation = self.expectation(description: "The completion handler called.")
        
        let expression = AWSS3TransferUtilityMultiPartUploadExpression()
        let uuid:(String) = UUID().uuidString
        let author:(String) = "integration test"
        expression.setValue(author, forRequestHeader: "x-amz-meta-author")
        expression.setValue(uuid, forRequestHeader: "x-amz-meta-id")
        expression.setValue("AES256", forRequestHeader: "x-amz-server-side-encryption-customer-algorithm")
        expression.setValue(customerKey, forRequestHeader: "x-amz-server-side-encryption-customer-key")
        expression.setValue(customerKeyMD5, forRequestHeader: "x-amz-server-side-encryption-customer-key-MD5")
        expression.progressBlock = {(task, progress) in
            print("Upload progress: ", progress.fractionCompleted)
        }
        
        //Create Completion Handler
        let uploadCompletionHandler = { (task: AWSS3TransferUtilityMultiPartUploadTask, error: Error?) -> Void in
            XCTAssertNil(error)
            
            //Get Meta Data and verify that it has been updated. This will indicate that the upload has succeeded.
            let s3 = AWSS3.default()
            let headObjectRequest = AWSS3HeadObjectRequest()
            headObjectRequest?.bucket = generalTestBucket
            headObjectRequest?.key = "testMultiPartUploadLargeFile.txt"
            headObjectRequest?.sseCustomerAlgorithm = "AES256"
            headObjectRequest?.sseCustomerKey = customerKey
            headObjectRequest?.sseCustomerKeyMD5 = customerKeyMD5
            
            s3.headObject(headObjectRequest!).continueWith(block: { (task:AWSTask<AWSS3HeadObjectOutput> ) -> Any? in
                XCTAssertNil(task.error)
                XCTAssertNotNil(task.result)
                if (task.result != nil) {
                    let output:(AWSS3HeadObjectOutput) = task.result!
                    XCTAssertNotNil(output)
                    XCTAssertNotNil(output.metadata)
                    XCTAssertEqual(author, output.metadata?["author"])
                    XCTAssertEqual(uuid, output.metadata?["id"])
                }
                
                let headers =  [
                    "x-amz-server-side-encryption-customer-algorithm": "AES256",
                    "x-amz-server-side-encryption-customer-key": customerKey,
                    "x-amz-server-side-encryption-customer-key-MD5" : customerKeyMD5]
                
                self.verifyContent(tu: transferUtility!,
                                   bucket: generalTestBucket,
                                   key: "testMultiPartUploadLargeFile.txt",
                                   hash: calculatedHash,
                                   headerKeyValues: headers)
                
                expectation.fulfill()
                return nil
            })
            
        }
        
        transferUtility?.uploadUsingMultiPart(fileURL: fileURL, bucket: generalTestBucket,
                                   key: "testMultiPartUploadLargeFile.txt",
                                   contentType: "text/plain",
                                   expression: expression,
                                   completionHandler: uploadCompletionHandler)
            .continueWith { (task: AWSTask<AWSS3TransferUtilityMultiPartUploadTask>) -> Any? in
                XCTAssertNil(task.error)
                XCTAssertNotNil(task.result)
                return nil
            }.waitUntilFinished()
        
        waitForExpectations(timeout: 240) { (error) in
            XCTAssertNil(error)
        }
    }
    
    func testInvalidCredentialsMultiPartUpload() {
        let expectation = self.expectation(description: "The completion handler called.")
        let transferUtility = AWSS3TransferUtility.s3TransferUtility(forKey: "invalid")
        XCTAssertNotNil(transferUtility)
        let uploadCompletionHandler = { (task: AWSS3TransferUtilityMultiPartUploadTask, error: Error?) -> Void in
            XCTAssertNotNil(error)
            XCTAssertEqual(task.status, AWSS3TransferUtilityTransferStatusType.error)
            
            self.processServiceError(error)
            expectation.fulfill()
        }
        
        transferUtility?.uploadUsingMultiPart(
            data: "1234567890".data(using: String.Encoding.utf8)!,
            bucket: generalTestBucket,
            key: "any-file-which-gets-rejected.txt",
            contentType: "text/plain",
            expression: nil,
            completionHandler: uploadCompletionHandler
            ).continueWith (block: { (task) -> AnyObject? in
                XCTAssertNotNil(task.error)
                expectation.fulfill()
                return nil
            })
        
        waitForExpectations(timeout: 90) { (error) in
            XCTAssertNil(error)
        }
    }

    func processServiceError(_ error: Error?) {
        guard let err = error as NSError? else {
            return
        }
        
        let errorInfo = err.userInfo["Error"] as? [String: Any]
        if errorInfo != nil {
            print("Found error in response. Details are:")
            for element in errorInfo! {
                print(">> \(element.key): \(element.value)")
            }
            XCTAssertNotNil(errorInfo!["Code"])
            XCTAssertNotNil(errorInfo!["Message"])
          }
    }
    
    
    func testTransferUtilityCompletionHandler() {
        let credentialProvider = AWSCognitoCredentialsProvider(regionType: s3RegionType, identityPoolId: s3CognitoIdentityPoolId)
        let serviceConfiguration = AWSServiceConfiguration(
            region: s3RegionType,
            credentialsProvider: credentialProvider
        )
        
        let transferUtilityConfiguration = AWSS3TransferUtilityConfiguration()
        
        let expectation1 = self.expectation(description: "test1 register completion handler called")
        AWSS3TransferUtility.register(
            with: serviceConfiguration!,
            transferUtilityConfiguration: transferUtilityConfiguration,
            forKey: "test1") { (error) in
                XCTAssertNil(error)
                expectation1.fulfill()
        }
        wait(for:[expectation1], timeout: 2)
        
        let expectation2 = self.expectation(description: "test2 register completion handler called")
        AWSS3TransferUtility.register(
        with: serviceConfiguration!,
        forKey: "test2") { (error) in
            XCTAssertNil(error)
            expectation2.fulfill()
        }
        wait(for:[expectation2], timeout: 2)
        
        let expectation4 = self.expectation(description: "test4 register completion handler called")
        AWSS3TransferUtility.register(
            with: serviceConfiguration!,
            transferUtilityConfiguration: nil,
            forKey: "test4") { (error) in
                XCTAssertNil(error)
                expectation4.fulfill()
        }
        wait(for:[expectation4], timeout: 2)
    }
    
    func testReRegisterTransferUtility() {
        var uploadCount = 0;
        var mpUploadCount = 0;
        var downloadCount = 0;
        let key = UUID().uuidString
        let uploadsCompleted = self.expectation(description: "Uploads completed")
        let multiPartUploadsCompleted = self.expectation(description: "Multipart uploads completed")
        let downloadsCompleted = self.expectation(description: "Downloads completed")
        
        //Register the TU
        let credentialProvider = AWSCognitoCredentialsProvider(regionType: s3RegionType, identityPoolId: s3CognitoIdentityPoolId)
        let serviceConfiguration = AWSServiceConfiguration(
            region: s3RegionType,
            credentialsProvider: credentialProvider
        )

        let transferUtilityConfiguration = AWSS3TransferUtilityConfiguration()
        
        AWSS3TransferUtility.register(
            with: serviceConfiguration!,
            transferUtilityConfiguration: transferUtilityConfiguration,
            forKey: key
        )
        
        //Do some work with the TU
        let transferUtility = AWSS3TransferUtility.s3TransferUtility(forKey: key)
        XCTAssertNotNil(transferUtility)
        let uploadExpression = AWSS3TransferUtilityUploadExpression()
        
        uploadExpression.progressBlock = {(task, progress) in
            print("Upload progress: ", progress.fractionCompleted)
        }
        
        let uploadCompletionHandler = { (task: AWSS3TransferUtilityUploadTask, error: Error?) -> Void in
            XCTAssertNil(error)
            uploadCount = uploadCount + 1
            if ( uploadCount >= 3 ) {
                uploadsCompleted.fulfill()
            }
            return
        }
        
        let multiPartUploadExpression = AWSS3TransferUtilityMultiPartUploadExpression()
        multiPartUploadExpression.progressBlock = {(task, progress) in
            print("Upload progress: ", progress.fractionCompleted)
        }
        
        let multiPartUploadCompletionHandler = { (task: AWSS3TransferUtilityMultiPartUploadTask, error: Error?) -> Void in
            XCTAssertNil(error)
            mpUploadCount = mpUploadCount + 1
            if ( mpUploadCount >= 3 ) {
                multiPartUploadsCompleted.fulfill()
            }
            return
        }
        
        let downloadExpression = AWSS3TransferUtilityDownloadExpression()
        downloadExpression.progressBlock = {(task, progress) in
            print("Upload progress: ", progress.fractionCompleted)
        }
        
        let downloadCompletionHandler = { (task: AWSS3TransferUtilityDownloadTask, URL: Foundation.URL?, data: Data?, error: Error?) in
            XCTAssertNil(error)
            downloadCount = downloadCount + 1
            if ( downloadCount >= 6 ) {
                downloadsCompleted.fulfill()
            }
            return
        }
        
        var testData = "Test123456789"
        for _ in 1...15 {
            testData = testData + testData;
        }
        
        //Upload 3 files
        for i in 1...3 {
            transferUtility?.uploadData(
                testData.data(using: String.Encoding.utf8)!,
                bucket: generalTestBucket,
                key: "testFileForGetTasks\(i).txt",
                contentType: "text/plain",
                expression: uploadExpression,
                completionHandler: uploadCompletionHandler
                ).continueWith (block: { (task) -> AnyObject? in
                    XCTAssertNil(task.error)
                    return nil
                })
            sleep(1)
        }
        XCTAssertEqual(transferUtility?.getUploadTasks().result!.count, 3)
        XCTAssertEqual(transferUtility?.getDownloadTasks().result!.count, 0)
        XCTAssertEqual(transferUtility?.getMultiPartUploadTasks().result!.count, 0)
        
        wait(for:[uploadsCompleted],  timeout: 60)
        
        //upload 3 more files using multipart
        for i in 4...6 {
            transferUtility?.uploadUsingMultiPart(
                data: testData.data(using: String.Encoding.utf8)!,
                bucket: generalTestBucket,
                key: "testFileForGetTasks\(i).txt",
                contentType: "text/plain",
                expression: multiPartUploadExpression,
                completionHandler: multiPartUploadCompletionHandler
                ).continueWith (block: { (task) -> AnyObject? in
                    XCTAssertNil(task.error)
                    return nil
                })
            sleep(1)
        }
        XCTAssertEqual(transferUtility?.getUploadTasks().result!.count, 3)
        XCTAssertEqual(transferUtility?.getDownloadTasks().result!.count, 0)
        XCTAssertEqual(transferUtility?.getMultiPartUploadTasks().result!.count, 3)
        wait(for:[multiPartUploadsCompleted],  timeout: 60)
        
        //Download 6 files
        for i in 1...6 {
            let url = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("file\(i)")
            transferUtility?.download(to: url!,
                                      bucket: generalTestBucket,
                                      key: "testFileForGetTasks\(i).txt",
                expression: downloadExpression,
                completionHandler: downloadCompletionHandler).continueWith(block: { (task) -> Any? in
                    XCTAssertNil(task.error)
                    return nil
                })
            sleep(1)
        }
        XCTAssertEqual(transferUtility?.getUploadTasks().result!.count, 3)
        XCTAssertEqual(transferUtility?.getDownloadTasks().result!.count, 6)
        XCTAssertEqual(transferUtility?.getMultiPartUploadTasks().result!.count, 3)
        wait(for:[downloadsCompleted],  timeout: 120)
    
        //Remove the TU
        AWSS3TransferUtility.remove(forKey: key)
        
        //Wait for the underlying NSURLSession invalidation to go through.
        sleep(5)
        
        //Register again.
        AWSS3TransferUtility.register(
            with: serviceConfiguration!,
            transferUtilityConfiguration: transferUtilityConfiguration,
            forKey: key
        ){ (error) in
            XCTAssertNil(error, "Registration of TransferUtility succeeded.")
        }
    }

    func sha256(url: URL) -> Data? {
        do {
            let bufferSize = 1024 * 1024
            // Open file for reading:
            let file = try FileHandle(forReadingFrom: url)
            defer {
                file.closeFile()
            }
            
            // Create and initialize SHA256 context:
            var context = CC_SHA256_CTX()
            CC_SHA256_Init(&context)
            
            // Read up to `bufferSize` bytes, until EOF is reached, and update SHA256 context:
            while autoreleasepool(invoking: {
                // Read up to `bufferSize` bytes
                let data = file.readData(ofLength: bufferSize)
                if data.count > 0 {
                    data.withUnsafeBytes {
                        _ = CC_SHA256_Update(&context, $0.baseAddress, numericCast(data.count))
                    }
                    // Continue
                    return true
                } else {
                    // End of file
                    return false
                }
            }) { }
            
            // Compute the SHA256 digest:
            var digest = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
            digest.withUnsafeMutableBytes {
                let d = $0.bindMemory(to: UInt8.self)
                _ = CC_SHA256_Final(d.baseAddress, &context)
            }
            
            return digest
        } catch {
            print(error)
            return nil
        }
    }

    func verifyContent(tu:AWSS3TransferUtility, bucket: String, key:String, hash:String, headerKeyValues:[String:String] = [:] ) {
        let filePath = NSTemporaryDirectory() + UUID().uuidString
        let fileURL = URL(fileURLWithPath: filePath)
        let downloadExpression = AWSS3TransferUtilityDownloadExpression()
      
        for(headerKey, headerValue) in headerKeyValues {
            downloadExpression.setValue(headerValue, forRequestHeader: headerKey)
        }
        
        downloadExpression.progressBlock = {(task, progress) in
            print("Download progress: ", progress.fractionCompleted)
        }
      
        let group = DispatchGroup()
        group.enter()
        
        let downloadCompletionHandler = { (task: AWSS3TransferUtilityDownloadTask, URL: Foundation.URL?, data: Data?, error: Error?) in
            if let HTTPResponse = task.response {
                XCTAssertEqual(HTTPResponse.statusCode, 200)
                if let digestData = self.sha256(url: fileURL) {
                    let calculatedHash = digestData.map { String(format: "%02hhx", $0) }.joined()
                    print ("Original Hash [", hash, "], Hash of Downloaded file [", calculatedHash, "]")
                    XCTAssertEqual(hash, calculatedHash)
                }
            } else {
                XCTFail()
            }
            group.leave()
        }
        
        tu.download(to: fileURL,
                bucket: bucket,
                   key: key,
                 expression: downloadExpression,
                 completionHandler: downloadCompletionHandler).continueWith(block: { (task) -> Any? in
                    XCTAssertNil(task.error)
                    return nil
                 })
        
        group.wait()
    }
}
