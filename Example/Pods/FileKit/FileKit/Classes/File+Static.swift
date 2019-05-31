//
//  File+Static.swift
//  Pods
//
//  Created by Tracy on 21/04/2017.
//
//

import Foundation
import Common

// MARK: - Create sub item

extension File {
    public static func createDirectory(name: String, underDirectory directory: File) throws -> File {
        let r = File.isValidSubItemName(name, underDirectory: directory)
        if r.error != nil {
            throw r.error!
        }
        
        let path = Path.join(component: directory.path, name)
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        return File(path: path)!
    }
    
    public static func createFile(name: String, data: Data, underDirectory directory: File) throws -> File {
        let r = File.isValidSubItemName(name, underDirectory: directory)
        if r.error != nil {
            throw r.error!
        }
        
        let path = Path.join(component: directory.path, name)
        let url = URL(fileURLWithPath: path)
        try data.write(to: url)
        return File(path: path)!
    }
}


// MARK: - Filename

extension File {
    public static func mediaType(ofFile file: File) -> MediaType {
        let ext = (file.name as NSString).pathExtension
        
        for mediaType in [MediaType.image, MediaType.video] {
            let extensions = self.extensions[mediaType.rawValue]
            if extensions.contains(ext.uppercased()) {
                return mediaType
            }
        }
        
        return MediaType.unknown
    }
    
    public static func validExtensionsForMediaType(mediaType: MediaType) -> [String] {
        return self.extensions[mediaType.rawValue]
    }
    
    public static func isValidSubItemName(_ name: String, underDirectory directory: File) -> (valid: Bool, error: Error?) {
        if directory.isDirectory() == false {
            return (false, RunTimeError.directoryRequired)
        }
        
        if name.characters.count == 0 {
            return (false, FilenameError.empty)
        }
        
        if name.hasPrefix(".") {
            return (false, FilenameError.hiddenPrefix)
        }
        
        if (name as NSString).range(of: "/|#|%", options: .regularExpression).length > 0 {
            return (false, FilenameError.reserveCharacters)
        }
        
        let targetPath = Util.join(component: directory.path, name)
        if FileManager.default.fileExists(atPath: targetPath) {
            return (false, FilenameError.duplicated)
        }
        
        return (true, nil)
    }
    
    public static func notDuplicatedName(for basename: String, underDirectory directory: File) -> String {
        var number = 1
        let nameWithoutExt = (basename as NSString).deletingPathExtension
        let ext = (basename as NSString).pathExtension
        
        var filePath = Util.join(component: directory.path, basename)
        var filename = basename
        
        while FileManager.default.fileExists(atPath: filePath) {
            filename = "\(nameWithoutExt) (\(number)).\(ext)"
            filePath = Util.join(component: directory.path, filename)
            number += 1
        }
        
        return filename
    }
}
