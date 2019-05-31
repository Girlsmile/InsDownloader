//
//  MediaManager.swift
//  Repost
//
//  Created by 古智鹏 on 2019/3/1.
//  Copyright © 2019 kevinslab. All rights reserved.
//


import Foundation
import Common
import Alamofire
import FEAssetKit

class InsMediaManager {
    
    static let  `shared` = InsMediaManager()
    
    fileprivate var dbListPath = InsParameter.Folder.DataBasePath + "/"
    
    fileprivate var MediaPath = InsParameter.Folder.InstaFolder + "/"
    
    fileprivate var ImageCachePath = InsParameter.Folder.ImageCachePath + "/"
    
    init() {
        creatFolder()
    }
    
    func creatFolder() {
        
        if !FileManager.default.fileExists(atPath: InsParameter.Folder.DataBasePath) {
            try? FileManager.default.createDirectory(atPath: InsParameter.Folder.DataBasePath, withIntermediateDirectories: true, attributes: nil)
        }
        
        if !FileManager.default.fileExists(atPath: InsParameter.Folder.InstaFolder) {
            try? FileManager.default.createDirectory(atPath: InsParameter.Folder.InstaFolder, withIntermediateDirectories: true, attributes: nil)
        }
        
        if !FileManager.default.fileExists(atPath: InsParameter.Folder.ImageCachePath) {
            try? FileManager.default.createDirectory(atPath: InsParameter.Folder.ImageCachePath, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    fileprivate func generateThumbnail(media: InsMedia) {
        _ = ImageCachePath
        let sourceUrl = media.imageURL.localPath()
        guard let image = UIImage.init(contentsOfFile: sourceUrl) else { return }
        let h = InsParameter.File.ThumbnailheightPixel
        let w = h * image.size.width / image.size.height
        UIGraphicsBeginImageContext(CGSize.init(width: w, height: h))
        image.draw(in: CGRect.init(x: 0, y: 0, width: w, height: h))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        try? thumbnail?.pngData()?.write(to: URL.init(fileURLWithPath: media.thumbnailPath))
    }
    
    func add(media: InsMedia, completion: ((Bool) -> Void)? = nil) {
        let data = NSKeyedArchiver.archivedData(withRootObject: media)
        let path = Util.join(component: dbListPath, media.identifier)
        let url = URL.init(fileURLWithPath: path)
        LLog("resource download path: ",url.absoluteString)
        
        if ((try? data.write(to: url)) != nil) {
            completion?(true)
        } else {
            completion?(false)
        }
        
    }
    
    func fetchAll() -> [InsMedia] {
        var mediaList: [InsMedia] = []
        let files = try? FileManager.default.contentsOfDirectory(atPath: InsParameter.Folder.DataBasePath)
        for fileName in files?.sorted() ?? [] {
            let path = Util.join(component: dbListPath, fileName)
            let url = URL.init(fileURLWithPath: path)
            if let data = try? Data.init(contentsOf: url), let media = NSKeyedUnarchiver.unarchiveObject(with: data) as? InsMedia {
                mediaList.append(media)
            }
        }
        
        return mediaList.sorted(by: { (media1, media2) -> Bool in
            return media2.saveTime.compare(media1.saveTime ?? Date()) == .orderedAscending
        })
    }
    
    func searchByName(_ name: String) ->[InsMedia] {
        let mediaList = fetchAll()
        let reg = "*" + name.map{ "\($0)*" }.joined()
        let preicate = NSPredicate.init(format: "SELF LIKE[cd] %@", reg)
        return mediaList.filter({ (media) -> Bool in
            return preicate.evaluate(with: media.username)
        })
    }
    
    func remove(media: InsMedia) {
        if let id = media.identifier {
            let path = Util.join(component: dbListPath, id)
            try? FileManager.default.removeItem(atPath: path)
        }
        
        for url in media.resourceURL {
            let url = URL.init(fileURLWithPath: url.localPath())
            try? FileManager.default.removeItem(at: url)
        }
        
        try? FileManager.default.removeItem(atPath: media.thumbnailPath)
    }
    
    func removeLocalInsResources() {
        let insMedias = fetchAll().filter { (media) -> Bool in
            return media.isInsMedia
        }
        
        insMedias.forEach { (media) in
            for url in media.resourceURL {
                LLog("deleteResource at :", url)
                let url = URL.init(fileURLWithPath: url.localPath())
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
    
    func isLocalContain(media: InsMedia) -> Bool {
        let mediaList = fetchAll()
        
        for item in mediaList {
            if item.identifier == media.identifier {
                return true
            }
        }
        
        return false
    }
    
    func saveMediaResources(media: InsMedia, completion: ((Bool) -> Void)? = nil) {
        let group = DispatchGroup()
        var isSuccessed = true
        for url in media.resourceURL {
            group.enter()
            InsNetwork.shared.storeMedia(url, completion: { (successed) in
                isSuccessed = successed
                if url == media.imageURL {
                    InsMediaManager.shared.generateThumbnail(media: media)
                    group.leave()
                } else {
                    group.leave()
                }
                
            })
        }
        
        group.notify(queue: DispatchQueue.main) {
            completion?(isSuccessed)
        }
    }
    
    func fetchRecently() -> [InsMedia] {
        var mediaList: [InsMedia] = []
        let files = try? FileManager.default.contentsOfDirectory(atPath: InsParameter.Folder.DataBasePath)
        for fileName in files?.sorted() ?? [] {
            let path = Util.join(component: dbListPath, fileName)
            let url = URL.init(fileURLWithPath: path)
            if let data = try? Data.init(contentsOf: url), let media = NSKeyedUnarchiver.unarchiveObject(with: data) as? InsMedia {
                mediaList.append(media)
            }
        }
        
        let allmediaList = mediaList.sorted(by: { (media1, media2) -> Bool in
            return media2.saveTime.compare(media1.saveTime ?? Date()) == .orderedAscending
        })
        mediaList.removeAll()
        
        for i in 0...allmediaList.count {
            if i <= InsParameter.recentlyMaxItem - 1, i < allmediaList.count {
                mediaList.append(allmediaList[i])
            } else {
                break
            }
            
        }
        
        return mediaList
    }
    
}

extension InsMediaManager {
    
    
    func shareMedia(_ media: InsMedia, completion: @escaping (UIActivity.ActivityType?, Bool, [Any]?, Error?) -> Swift.Void, from controller: UIViewController) {
        let items = media.shareURLs
        let shareVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        shareVC.completionWithItemsHandler = completion
        
        controller.present(shareVC, animated: true, completion: nil)
    }
    
    func saveMedia(_ media: InsMedia, resultHandler: @escaping (_ success: Bool, _ error: Error?, _ localIdentifier: String?)
        ->
        Swift.Void) {
        guard let url = media.shareURLs.first else { return }
        if media.isVideo {
            self.saveVideo(url: url, resultHandler: resultHandler)
        } else {
            self.saveImage(url: url, resultHandler: resultHandler)
        }
    }
    
    func saveImage(url: URL, resultHandler: @escaping (_ success: Bool, _ error: Error?, _ localIdentifier: String?)
        ->
        Swift.Void) {
        AssetLibrary.requestPermissions({
            AssetManager.saveImage(url: url, resultHandler: { (result, error, identifier) in
                resultHandler(result, error, identifier)
            })
        }) {
            
        }
    }
    
    func saveVideo(url: URL, resultHandler: @escaping (_ success: Bool, _ error: Error?, _ localIdentifier: String?)
        ->
        Swift.Void) {
        AssetLibrary.requestPermissions({
            AssetManager.saveVideo(url, resultHandler: { (result, error, identifier) in
                resultHandler(result, error, identifier)
            })
            
        }) {
            
        }
    }
    
}

extension String {
    
    func localPath() -> String {
        var name = (self as NSString).lastPathComponent
        
        let pattern = InsParameter.UrlAnalyzer.FileSuffixPattern
        let regex = try? NSRegularExpression.init(pattern: pattern, options: [])
        let result = regex?.matches(in: name, options: [], range: NSRange.init(location: 0
            , length: name.count))
        
        if var index = result?.first?.range.location, let length = result?.first?.range.length {
            index = index + length
            name = name.substring(to: name.index(before: String.Index.init(encodedOffset: index)))
        }
        
        let path = Util.join(component: InsParameter.Folder.InstaFolder, name)
        
        return path
    }
    
    func thumbnailPath() -> String {
        
        var name = (self as NSString).lastPathComponent
        let pattern = InsParameter.UrlAnalyzer.FileSuffixPattern
        let regex = try? NSRegularExpression.init(pattern: pattern, options: [])
        let result = regex?.matches(in: name, options: [], range: NSRange.init(location: 0
            , length: name.count))
        
        if var index = result?.first?.range.location, let length = result?.first?.range.length {
            index = index + length
            name = name.substring(to: name.index(before: String.Index.init(encodedOffset: index)))
        }
        
        let path = Util.join(component: InsParameter.Folder.ImageCachePath, name)
        
        return path
    }
    
    mutating func correctFileName(name: String) -> String {
        
        let pattern = InsParameter.UrlAnalyzer.FileSuffixPattern
        let regex = try? NSRegularExpression.init(pattern: pattern, options: [])
        let result = regex?.matches(in: name, options: [], range: NSRange.init(location: 0
            , length: name.count))
        
        if var index = result?.first?.range.location, let length = result?.first?.range.length {
            index = index + length
            self = self.substring(to: name.index(before: String.Index.init(encodedOffset: index)))
        }
        
        return self
    }
    
    
    mutating func reMoveFirstNewlineCharacters() {
        self = self.trimmingCharacters(in: .newlines)
    }
}
