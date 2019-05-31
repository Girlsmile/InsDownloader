//
//  Media.swift
//  Repost
//
//  Created by 古智鹏 on 2019/3/12.
//  Copyright © 2019 kevinslab. All rights reserved.
//
 
import Foundation
import SwiftyJSON

let kMediaVideoKey = "kMediaVideoKey"
let kMediaImagesKey = "kMediaImagesKey"
let kMediaIdentifierKey = "kMediaIdentifierKey"
let kUsernameKey = "kUsernameKey"
let kSaveTimeKey = "saveTimeKey"
let kAvtarURLKey = "kAvtarURLKey"
let kUrlKey = "kUrlKey"
let kLocationKey = "kLocationKey"
let kDescribleKey = "kDescribleKey"
let kIsInsMediaKey = "kIsInsMediaKey"

class InsMedia: NSObject, NSCoding {
    
    var identifier: String!
    var videoURL: String?
    var imageURL: String!
    var avtarURL: String!
    var username: String!
    var saveTime: Date!
    var urlString: String?
    var location: String?
    var describeText: String?
    var isInsMedia: Bool = true
    
    var isVideo: Bool {
        return videoURL != nil
    }
    
    static var dateFormater: DateFormatter = {
        let dateFormater = DateFormatter()
        dateFormater.dateFormat = "HH:mm:ss.SSS"
        return dateFormater
    }()
    
    var thumbnailPath: String {
        return imageURL.thumbnailPath()
    }
    
    var resourceURL: [String] {
        var resources: [String] = []

        if let imagesURL = imageURL, !imagesURL.isEmpty {
            resources.append(imagesURL)
        }

        if let video = videoURL {
            resources.append(video)
        }
        return resources
    }

    var localResourceURL: URL {
        if let videoPath = videoURL {
            return URL(fileURLWithPath: videoPath.localPath())
        } else {
            return URL(fileURLWithPath: imageURL.localPath())
        }
    }
    
    var shareURLs: [URL] {
        if let videoPath = videoURL {
            return [URL(fileURLWithPath: videoPath.localPath())]
        } else {
            return [URL(fileURLWithPath: imageURL.localPath())]
        }
    }
    
    override init() {}

    init?(sharedData: JSON, describeText: String?, _ saveTime: Date = Date(), displayUrlLocation: Int) {
        
        let media = sharedData["edge_sidecar_to_children"]["edges"][displayUrlLocation]["node"]

        guard media["display_url"].string != nil else { return nil }
        
        self.imageURL = media["display_url"].stringValue
        self.videoURL = media["video_url"].string
        self.identifier = media["shortcode"].stringValue
        self.avtarURL = sharedData["owner"]["profile_pic_url"].stringValue
        self.username = sharedData["owner"]["username"].stringValue
        self.location = sharedData["location"]["name"].string
        
        self.describeText = describeText
        self.saveTime = saveTime
        self.describeText?.reMoveFirstNewlineCharacters()
    }
    
    init?(sharedData: JSON, describeText: String?, _ saveTime: Date) {
        let media = sharedData
        guard let displayURL = media["display_url"].string else { return nil }
        
        self.videoURL = media["video_url"].string
        self.identifier = media["shortcode"].stringValue
        self.avtarURL = media["owner"]["profile_pic_url"].stringValue
        self.username =  media["owner"]["username"].stringValue
        
        self.location = media["location"]["name"].string
        self.imageURL = displayURL
        self.describeText = describeText
        self.saveTime = Date()
        self.describeText?.reMoveFirstNewlineCharacters()
    }
    
    func encode(with aCoder: NSCoder) {
        
        if let videoURL = self.videoURL {
            aCoder.encode(videoURL, forKey: kMediaVideoKey)
        }
        if let imagesURL = self.imageURL {
            aCoder.encode(imagesURL, forKey: kMediaImagesKey)
        }
        aCoder.encode(identifier, forKey: kMediaIdentifierKey)
        if let avtarURL = self.avtarURL {
            aCoder.encode(avtarURL, forKey: kAvtarURLKey)
        }
        if let saveTime = self.saveTime {
            aCoder.encode(saveTime, forKey: kSaveTimeKey)
        }
        if let name = self.username {
            aCoder.encode(name, forKey: kUsernameKey)
        }
        if let url = self.urlString {
            aCoder.encode(url, forKey: kUrlKey)
        }
        if let location = self.location {
            aCoder.encode(location, forKey: kLocationKey)
        }
        if let describeText = self.describeText {
            aCoder.encode(describeText, forKey: kDescribleKey)
        }
        aCoder.encode(isInsMedia, forKey: kIsInsMediaKey)
    }

    required init?(coder aDecoder: NSCoder) {
        self.videoURL = aDecoder.decodeObject(forKey: kMediaVideoKey) as? String
        self.imageURL = aDecoder.decodeObject(forKey: kMediaImagesKey) as? String
        self.identifier = aDecoder.decodeObject(forKey: kMediaIdentifierKey) as? String
        self.avtarURL = aDecoder.decodeObject(forKey: kAvtarURLKey) as? String
        self.saveTime = aDecoder.decodeObject(forKey: kSaveTimeKey) as? Date
        self.username = aDecoder.decodeObject(forKey: kUsernameKey) as? String
        self.urlString = aDecoder.decodeObject(forKey: kUrlKey) as? String
        self.location = aDecoder.decodeObject(forKey: kLocationKey) as? String
        self.describeText = aDecoder.decodeObject(forKey: kDescribleKey) as? String
        self.isInsMedia = aDecoder.decodeBool(forKey: kIsInsMediaKey)
    }
    
    func isInsResurceExists() -> Bool {
        if let videoUrl = videoURL {
            return FileManager.default.fileExists(atPath: videoUrl.localPath())
        }
        return FileManager.default.fileExists(atPath: imageURL.localPath())
    }
    
}

extension InsMedia {
    static func Builer() -> InsMedia {
        let media = InsMedia()
        return media
    }
    
    func setIdentifier(_ identifier: String) -> InsMedia {
        self.identifier = identifier
        return self
    }
    
    func setImageURL(_ imageURL: String) -> InsMedia {
        self.imageURL = imageURL
        return self
    }
    
    func setAvtarURL(_ avtarURL: String) -> InsMedia {
        self.avtarURL = avtarURL
        return self
    }
    
    func setUsername(_ name: String) -> InsMedia {
        self.username = name
        return self
    }
    
    func setSaveTime(_ time: Date) -> InsMedia {
        self.saveTime = time
        return self
    }
}
