//
//  AWSUploadFile.swift
//  WKFileUpload
//
//  Created by Brian on 01/10/19.
//  Copyright © 2019 WeKan. All rights reserved.
//

import Foundation

class AWSUploadFile: Codable {
    var fileData: Data?
    var fileIndex: Int!
    var uploadProgress: Float!
    var uploadStatus: Int!
    var fileType: String?
    var s3UrlPath: String?

    private enum CodingKeys: String, CodingKey {
        case fileData
        case fileIndex
        case uploadProgress
        case uploadStatus
        case fileType
        case s3UrlPath
    }

    init() {
        self.fileData = Data.init()
        self.fileIndex = 0
        self.uploadProgress = 0.0
        self.uploadStatus = 0
        self.s3UrlPath = ""
    }
    
    // MARK: - Codable
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(fileData, forKey: .fileData)
        try container.encodeIfPresent(fileIndex, forKey: .fileIndex)
        try container.encodeIfPresent(uploadProgress, forKey: .uploadProgress)
       try container.encodeIfPresent(uploadStatus, forKey: .uploadStatus)
       try container.encodeIfPresent(fileType, forKey: .fileType)
       try container.encodeIfPresent(s3UrlPath, forKey: .s3UrlPath)
   }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileData = try container.decodeIfPresent(Data.self, forKey: .fileData)
        fileIndex = try container.decodeIfPresent(Int.self, forKey: .fileIndex)
        uploadProgress = try container.decodeIfPresent(Float.self, forKey: .uploadProgress)
        uploadStatus = try container.decodeIfPresent(Int.self, forKey: .uploadStatus)
        fileType = try container.decodeIfPresent(String.self, forKey: .fileType)
        s3UrlPath = try container.decodeIfPresent(String.self, forKey: .s3UrlPath)
    }

}
