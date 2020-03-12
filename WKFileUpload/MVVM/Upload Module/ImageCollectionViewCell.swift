//
//  ImageCollectionViewCell.swift
//  WKFileUpload
//
//  Created by Brian on 01/10/19.
//  Copyright © 2019 WeKan. All rights reserved.
//

import UIKit

class ImageCollectionViewCell: UICollectionViewCell {
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var progressView: UIProgressView!
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet var deleteBtn: UIButton!

    override func awakeFromNib() {
           super.awakeFromNib()
           // Initialization code
           self.imageView.contentMode = .redraw
           self.imageView.clipsToBounds = true
    }
    
    func configureCell(imageModel: AWSUploadFile) {
        self.imageView.image = UIImage(data: imageModel.fileData!)
        self.updateProgress(imageModel: imageModel)
        self.deleteBtn.tag = imageModel.fileIndex
     }
    
    /// update upload progress in cell
    func updateProgress(imageModel: AWSUploadFile) {
        print(imageModel.uploadProgress as Any)
        self.progressView.progress = imageModel.uploadProgress //uploadProgress
        switch imageModel.uploadStatus {
        case UploadStatus.inProgress.rawValue:
            self.statusLabel.text = "\(Int(100 * imageModel.uploadProgress!))%"
            self.statusLabel.textColor = UIColor.green
        case UploadStatus.complete.rawValue:
            self.statusLabel.text = "✓"
            self.statusLabel.textColor = UIColor.green
        case UploadStatus.failed.rawValue:
            self.statusLabel.text = "X"
            self.statusLabel.textColor = UIColor.red
        default:
            self.statusLabel.text = ""
        }
    }
}
