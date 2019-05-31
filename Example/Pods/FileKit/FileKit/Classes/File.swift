//
//  File.swift
//  CalculatorPhotoVault
//
//  Created by Tracy on 27/02/2017.
//  Copyright © 2017 com.Flow. All rights reserved.
//

import UIKit
import SwiftyJSON
import Common

public class File: NSObject, SelfAware {
    
    // constant
    public enum MediaType: Int {
        case unknown = 0, image, video
    }
    
    public enum FilenameError: Error {
        case duplicated, empty, reserveCharacters, hiddenPrefix
    }
    
    public enum RunTimeError: Error {
        case unknown
        case directoryRequired
    }
    
    public struct ExtendedAttributedKey {
        static let ID = "net.flow.ID"
        static let duration = "net.flow.Duration"
    }
    
    public struct SupportingFilenames {
        static let preview = "preview"
        static let thumbnail = "thumbnail"
        static let thumbnailDegraded = "degraded"
    }
    
    public static var extensions: [[String]] {
        let unknow: [String] = []
        let images = ["TIFF", "TIF", "JPG", "JPEG", "GIF", "PNG", "BMP", "BMPF", "ICO", "CUR", "XBM", "HEIC"] + onlineExtensions(mediaType: .image)
        let videos = ["MOV", "MP4", "MPV", "3GP", "M4V", "MKV", "RM", "RMVB", "WMV", "FLV", "AVI", "MPG", "MPEG", "DAT", "VOB", "ASF", "TS", "M2TS", "WEBM"] + onlineExtensions(mediaType: .video)
        
        return [unknow, images, videos]
    }
    
    static func onlineExtensions(mediaType: MediaType) -> [String] {
        return Params.named(extensionsParamName)[mediaType.rawValue].arrayValue.compactMap { return $0.string }
    }
    
    private static let extensionsParamName = "S.File.extensions"
    
    // static
    public static var supportingFilesRoot = Path.join(component: Path.library, "File.supportingFilesRoot")

    // property
    public fileprivate(set) var ID: String!
    public fileprivate(set) var path: String!
    public var name: String {
        return (self.path as NSString).lastPathComponent
    }
    public fileprivate(set) var attributes: [FileAttributeKey: Any]!
    
    private override init() {
        super.init()
    }
    
    public static func awake() {
        try? FileManager.default.createDirectory(atPath: File.supportingFilesRoot, withIntermediateDirectories: true, attributes: nil)
    }
    
    //
    public init?(path: String) {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path) {
            super.init()
            
            self.path = path
            self.attributes = attrs
            
            // ID
            self.loadID()
            if self.ID == nil {
                self.setupID()
            }
            
            //
            self.prepareForSupportingFiles()
        }
        else {
            return nil
        }
    }
}

// MARK: - Readwrite

extension File {
    public func data() -> Data? {
        if self.isDirectory() == false {
            let url = URL(fileURLWithPath: self.path)
            return try? Data(contentsOf: url)
        }
        
        return nil
    }
    
    public func saveData(data: Data) {
        if self.isDirectory() == false {
            let url = URL(fileURLWithPath: self.path)
            try? data.write(to: url)
        }
    }
    
    public func duration() -> Int {
        let json = extendedAttribute(name: File.ExtendedAttributedKey.duration, path: self.path, attributes: self.attributes)
        return json.intValue
    }
    
    public func saveDuraction(_ duration: Int) {
        setExtendedAttribute(name: File.ExtendedAttributedKey.duration, value: JSON.init(rawValue: duration), path: self.path)
        self.reloadAttributes()
    }
}

// MARK: - Readwrite (image)

extension File {
    public func preview() -> UIImage? {
        return UIImage(contentsOfFile: File.previewPath(forFileOrDirectory: self))
    }
    
    public func savePreview(_ preview: UIImage?) {
        self.saveSupportingImage(preview, toPath: File.previewPath(forFileOrDirectory: self))
    }
    
    public func thumbnail() -> UIImage? {
        return UIImage(contentsOfFile: File.thumbnailPath(forFileOrDirectory: self))
    }
    
    public func saveThumbnail(_ thumbnail: UIImage?) {
        self.saveSupportingImage(thumbnail, toPath: File.thumbnailPath(forFileOrDirectory: self))
    }
    
    public func thumbnailDegraded() -> UIImage? {
        return UIImage(contentsOfFile: File.thumbnailDegradedPath(forFileOrDirectory: self))
    }
    
    public func saveThumbnailDegraded(_ thumbnailDegraded: UIImage?) {
        self.saveSupportingImage(thumbnailDegraded, toPath: File.thumbnailDegradedPath(forFileOrDirectory: self))
    }
    
    // MARK: - Private
    func saveSupportingImage(_ supportingImage: UIImage?, toPath path: String) {
        let url = URL(fileURLWithPath: path)
        
        if supportingImage != nil {
            let data = UIImageJPEGRepresentation(supportingImage!, 0.99)
            try? data?.write(to: url)
        }
        else {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Directory

extension File {
    public func isDirectory() -> Bool {
        return self.attributes[FileAttributeKey.type] as? FileAttributeType == FileAttributeType.typeDirectory
    }
    
    public func parentDirectory() -> File? {
        let dir = (self.path as NSString).deletingLastPathComponent
        return File(path: dir)
    }
    
    public func items() -> [File]? {
        if self.isDirectory() == false {
            return nil
        }
        
        var items = [File]()
        if let names = try? FileManager.default.contentsOfDirectory(atPath: self.path) {
            for name in names {
                if name.hasPrefix(".") {
                    continue
                }
                
                let fullPath = Path.join(component: self.path, name)
                if let file = File(path: fullPath) {
                    items.append(file)
                }
            }
        }
        
        return items
    }
}

// MARK: - Operate

extension File {
    public func move(intoDirectory directory: File) throws {
        let name = File.notDuplicatedName(for: self.name, underDirectory: directory)
        let newPath = Path.join(component: directory.path, name)
        
        try FileManager.default.moveItem(atPath: self.path, toPath: newPath)
        self.path = newPath
    }
    
    public func rename(fileOrDirectory: File, newName: String) throws {
        if fileOrDirectory.name == newName {
            return
        }
        
        if let parentDirectory = self.parentDirectory() {
            let r = File.isValidSubItemName(newName, underDirectory: parentDirectory)
            if r.valid {
                let newPath = Path.join(component: parentDirectory.path, newName)
                try FileManager.default.moveItem(atPath: fileOrDirectory.path, toPath: newPath)
                fileOrDirectory.path = newPath
            }
            else {
                throw r.error!
            }
        }
    }
    
    public func remove(fileOrDirectory: File) throws {
        try FileManager.default.removeItem(atPath: fileOrDirectory.path)
        try FileManager.default.removeItem(atPath: File.supportingFilesPath(forFileOrDirectory: self))
    }
}

// MARK: - Attributes

extension File {
    public func updateAttributes(_ newAttributes: [FileAttributeKey: Any]) {
        // 复制原始attributes
        var attrs = [FileAttributeKey: Any]()
        for (k, v) in self.attributes {
            attrs[k] = v
        }
        
        // 读新的attributes
        for (k, v) in newAttributes {
            attrs[k] = v
        }
        
        // 设置
        do {
            try FileManager.default.setAttributes(attrs, ofItemAtPath: self.path)
            self.attributes = attrs
        }
        catch {
            //
        }
    }
    
    public func reloadAttributes() {
        self.attributes = try? FileManager.default.attributesOfItem(atPath: self.path)
    }
}

// MARK: - Private - Paths

extension File {
    public static func supportingFilesPath(forFileOrDirectory fileOrDirectory: File) -> String {
        return Path.join(component: self.supportingFilesRoot, fileOrDirectory.ID)
    }
    
    public static func previewPath(forFileOrDirectory fileOrDirectory: File) -> String {
        return Path.join(component: self.supportingFilesPath(forFileOrDirectory: fileOrDirectory), SupportingFilenames.preview)
    }
    
    public static func thumbnailPath(forFileOrDirectory fileOrDirectory: File) -> String {
        return Path.join(component: self.supportingFilesPath(forFileOrDirectory: fileOrDirectory), SupportingFilenames.thumbnail)
    }
    
    public static func thumbnailDegradedPath(forFileOrDirectory fileOrDirectory: File) -> String {
        return Path.join(component: self.supportingFilesPath(forFileOrDirectory: fileOrDirectory), SupportingFilenames.thumbnailDegraded)
    }
}

// MARK: - Private - ID

extension File {
    fileprivate func loadID() {
        self.ID = extendedAttribute(name: File.ExtendedAttributedKey.ID, path: self.path, attributes: self.attributes).string
    }
    
    fileprivate func resetID() {
        removeExtendedAttribute(name: File.ExtendedAttributedKey.ID, path: path)
        self.ID = nil
    }
    
    fileprivate func setupID() {
        self.ID = UUID().uuidString
        setExtendedAttribute(name: File.ExtendedAttributedKey.ID, value: JSON.init(rawValue: self.ID), path: self.path)
        self.reloadAttributes()
    }
}

// MARK: - Private

extension File {
    fileprivate func prepareForSupportingFiles() {
        let dir = File.supportingFilesPath(forFileOrDirectory: self)
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
    }
}
