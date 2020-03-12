//
//  AWSUploadViewController.swift
//  WKFileUpload
//
//  Created by Brian on 01/10/19.
//  Copyright © 2019 WeKan. All rights reserved.
//

import AssetsPickerViewController
import Photos
import UIKit

class AWSUploadViewController: UIViewController, UINavigationControllerDelegate {
    @IBOutlet var imagesCollectionView: UICollectionView!
    @IBOutlet var collViewFlowLayout: UICollectionViewFlowLayout!
    
    @objc let imagePicker = UIImagePickerController()
    let cameraImageNamePrefix = "camimage00"
    let libraryImageNameFallbackPrefix = "libimage"
    
    var viewModel: AWSUploadViewModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        self.viewModel = AWSUploadViewModel()
        
        self.imagePicker.delegate = self
        self.collViewFlowLayout.estimatedItemSize = CGSize(width: 1, height: 1)
        self.imagesCollectionView.contentInsetAdjustmentBehavior = .never
        
        // Register for AWS transfer with the credentials
        AWSUploadManager.shared.registerAWSTransfer()
        
        // Listen to upload progress and update the progress in UI
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NotificationName.uploadInProgress),
                                               object: nil, queue: .main) { (notification) in
                                                self.imagesCollectionView.performBatchUpdates({
                                                    DispatchQueue.main.async {
                                                        self.imagesCollectionView.reloadData()
                                                    }
                                                }, completion: { (completed) in
                                                    print("finished updating cell: \(completed)")
                                                })
        }
        
        // Listen to upload failure and update the UI
        NotificationCenter.default.addObserver(self, selector: #selector(uploadFailedNotification(notification:)),
                                               name: NSNotification.Name(rawValue: NotificationName.uploadFailed),
                                               object: nil)
    }
    
    /// Button action for select images button
    @IBAction func selectImagesAction(_ sender: UIButton) {
        self.viewModel.checkAndRequestPermissions()
        self.openImagePicker()
    }
    
    /// Upload button action
    @IBAction func uploadAction(_ sender: UIButton) {
        self.viewModel.uploadFiles(forController: self)
    }
    
    /// Delete Image button action
    @IBAction func deleteImageAction(_ sender: UIButton) {
        //Delete from total array
        let fileToDelete = self.viewModel.filesArray[sender.tag]
        self.viewModel.filesArray.remove(at: sender.tag)
        // Delete from gallery assets selection list
        deleteAsset(withName: fileToDelete.fileName)
        // remove the item from grid
        reloadImagesList()
    }
    
    /// Deletes asset from array by it's name. Checks if the image is selected from camera or library and deletes the asset from corresponding array
    /// - Parameter name: name of the asset to be deleted
    func deleteAsset(withName name: String) {
        if name.hasPrefix(cameraImageNamePrefix) {
            viewModel.capturedImages = viewModel.capturedImages.filter() { $0.fileName != name }
        } else {
            viewModel.selectedImageAssets = viewModel.selectedImageAssets.filter() { $0.value(forKey: "filename") as! String != name }
        }
    }
    
    /// Reload the list of images on the gridview. this is usually called when there is a image being removed from the list.
    func reloadImagesList() {
        // update the fileIndex of all images after deleting an image
        let allImages = viewModel.filesArray
        for index in 0..<allImages.count {
            let imageFile = viewModel.filesArray[index]
            imageFile.fileIndex = index
            viewModel.filesArray[index] = imageFile
        }
        self.imagesCollectionView.reloadData()
    }
    
    /// Notification selector, called when the upload fails
    @objc func uploadFailedNotification(notification: Notification) {
        print(notification)
        self.imagesCollectionView.performBatchUpdates({
            DispatchQueue.main.async {
                self.imagesCollectionView.reloadData()
            }
        }, completion: { (completed) in
            print("finished updating cell: \(completed)")
        })
    }
    
    /// Shows the options to select image from photo library or to capture from camera
    func openImagePicker() {
        let selectedCount = viewModel.capturedImages.count + viewModel.selectedImageAssets.count
        if selectedCount > Maximum.uploadFileCount {
            self.showMessage(message: "You can upload a maximum of \(Maximum.uploadFileCount) images.", title: "Limit exceeded")
            return
        }
        
        let alert = UIAlertController(title: "Select Images", message: "", preferredStyle: .alert)
        let cameraAction = UIAlertAction(title: "Open Camera", style: .default) { _ in
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                self.imagePicker.delegate = self
                self.imagePicker.sourceType = .camera
                self.imagePicker.allowsEditing = true
                //self.imagePicker.cameraViewTransform = CGAffineTransform(scaleX: -1, y: 1)
                DispatchQueue.main.async {
                    self.present(self.imagePicker, animated: true, completion: nil)
                }
            }
        }
        let galleryAction = UIAlertAction(title: "Open Photos Album", style: .default) { _ in
            if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
                self.openAssetPicker()
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
        }
        alert.addAction(cameraAction)
        alert.addAction(galleryAction)
        alert.addAction(cancelAction)
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    /// opens the photo album with support for mutiple file selection
    func openAssetPicker() {
        let picker = AssetsPickerViewController()
        picker.pickerDelegate = self
        picker.pickerConfig.selectedAssets = self.viewModel.selectedImageAssets
        present(picker, animated: true, completion: nil)
    }
    
    /// Alert message used to show any general messages
    func showMessage(message: String, title: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let okBtnAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(okBtnAction)
            self.present(alert, animated: true) {
            }
        }
    }
    
}

extension AWSUploadViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.viewModel.filesArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell",
                                                            for: indexPath) as? ImageCollectionViewCell else {
                                                                return UICollectionViewCell()
        }
        cell.configureCell(imageModel: self.viewModel.filesArray[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 100, height: 100)
    }
    
    func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.viewModel.retryUpload(forFileAt: indexPath.item, forController: self)
    }
}

extension AWSUploadViewController: UIImagePickerControllerDelegate {
    /// delegate called when the image picker finishes capturing an image from camera
    @objc func imagePickerController(_ picker: UIImagePickerController,
                                     didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        // Local variable inserted by Swift 4.2 migrator.
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)
        if "public.image" == info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.mediaType)] as? String {
            let image = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage
            let file = AWSUploadFile()
            file.fileType = UploadFileType.imageFile.rawValue
            guard let data = image?.pngData() else {
                return
            }
            file.fileData = data
            file.fileIndex = viewModel.filesArray.count
            let nameForCapturedImage = "\(cameraImageNamePrefix)\(viewModel.filesArray.count)"
            file.fileName = nameForCapturedImage
            self.viewModel.filesArray.append(file)
            self.viewModel.capturedImages.append(file)
            self.imagesCollectionView.reloadData()
        }
        dismiss(animated: true, completion: nil)
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
    return Dictionary(uniqueKeysWithValues: input.map { key, value in (key.rawValue, value) })
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
    return input.rawValue
}

// MARK: - Asset Picker delegates

extension AWSUploadViewController: AssetsPickerViewControllerDelegate {
    func assetsPickerCannotAccessPhotoLibrary(controller: AssetsPickerViewController) {}
    
    func assetsPicker(controller: AssetsPickerViewController, selected assets: [PHAsset]) {
        // From all images array, keep only camera images and remove all library images.
        // And then add the updated images from assetpicker to the array
        self.viewModel.filesArray = self.viewModel.filesArray.filter() { $0.fileName.hasPrefix(cameraImageNamePrefix) }
        self.viewModel.selectedImageAssets = assets
        for (_, asset) in assets.enumerated() {
            let origImage = self.viewModel.getUIImageFromAsset(asset: asset, forSize: UIScreen.main.bounds.size)
            let orientationFixedImg = Helper.fixImageOrientation(origImage)
            let file = AWSUploadFile()
            file.fileData = orientationFixedImg.pngData()
            file.fileIndex = viewModel.filesArray.count
            let fallbackNameForImage = "\(libraryImageNameFallbackPrefix)\(viewModel.filesArray.count)"
            file.fileName = asset.value(forKey: "filename") as? String ?? fallbackNameForImage
            self.viewModel.filesArray.append(file)
        }
        self.imagesCollectionView.reloadData()
    }
    
    func assetsPicker(controller: AssetsPickerViewController, shouldSelect asset: PHAsset, at indexPath: IndexPath) -> Bool {
        //restrict image count to the max limit set in Costants
        // Total Image count should consider the image captured from camera as well
        let selectedCount = viewModel.capturedImages.count + controller.selectedAssets.count
        return (selectedCount < Maximum.uploadFileCount)
    }
    
    func assetsPicker(controller: AssetsPickerViewController, shouldDeselect asset: PHAsset, at indexPath: IndexPath) -> Bool {
        return true
    }
}

