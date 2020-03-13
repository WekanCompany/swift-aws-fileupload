# S3 File Upload Sample for iOS using Swift #

* Swift 5
* MVVM architecture

### What is this repository for? ###

* This is a sample app that covers multipart file upload to AWS S3 bucket using AWSS3TransferUtility.

### Frameworks Used ###

Cocoapods will install these frameworks 

* AWSS3
* AWSMobileClient
* AssetsPickerViewController

### Using this sample ###

1. To install the frameworks, change directory to project root directory in terminal and run the following command:
```
pod install
```

2. In Constants.swift, set your AWS credentials
	* Cognito Identity Pool Id
	* Bucket Name
	* Region

3. Build and run the app
