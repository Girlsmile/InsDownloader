//
//  AssetManager.swift
//  CalculatorPhotoVault
//
//  Created by ljk on 17/2/21.
//  Copyright © 2017年 Tracy. All rights reserved.
//

import UIKit
import Photos
import Common
import FileKit

public typealias ExportImageBlock = (Data?, String?, UIImageOrientation, [AnyHashable : Any]?, PHAsset, URL) -> Swift.Void
public typealias ExportVideoBlock = (_ asset: PHAsset,_ fileURL: URL) -> Swift.Void
public typealias ExportProgressBlock = (Double) -> Swift.Void

public class AssetManager: NSObject {
    
    fileprivate var exportAssets: [PHAsset]?
    fileprivate var exportFilesPath: [String]!
    fileprivate var requestID: PHImageRequestID?
    fileprivate var exportSession: AVAssetExportSession?
    
    fileprivate var finishedCount = 0
    fileprivate var unExportCount = 0
    fileprivate var totalCount = 0
    
    //    fileprivate var exportImageBlock: ExportImageBlock?
    //    fileprivate var exportVideoBlock: ExportVideoBlock?
    public var fileSizeCallBack: ((Int64)->Void)?
    
    fileprivate var callBack: ((String, PHAsset)->Void)?
    fileprivate var progressBlock: ExportProgressBlock?
    fileprivate var completionHandler: ((_ result: Bool, _ filesPath: [String]) -> Swift.Void)?
    fileprivate var isCancel = false
    
    fileprivate var directory: File! //导入沙盒的路径
    
    fileprivate var timer: Timer?
    
    static private let descriptor = NSSortDescriptor(key: "creationDate", ascending: false)
    
    public static var thumbnailSize: CGSize = {
        let size = CGSize(width: 70 * UIScreen.main.scale, height: 70 * UIScreen.main.scale)
        return size
    }()
    
    static var thumbnailDegradedSize: CGSize = {
        let size = CGSize(width: 10, height: 10)
        return size
    }()
    
    //    init() {
    //
    //    }
}

// MARK: - ExportAsset
public extension AssetManager {
    public func exportAssets(_ assets: [PHAsset], at path: String ,progressBlock: @escaping ExportProgressBlock, callBack: @escaping (String, PHAsset)->Void ,completionHandler: @escaping (_ result: Bool, _ filesPath: [String]) -> Swift.Void) {
        
        self.directory = File(path: path)
        self.exportFilesPath = [String]()
        self.exportAssets = assets
        self.progressBlock = progressBlock
        self.callBack = callBack
        self.completionHandler = completionHandler
        self.totalCount = assets.count
        self.isCancel = false
        
        self.progressBlock?(0)
        processAssets()
        
        let timer = Timer(timeInterval: 0.5, target: self, selector: #selector(timerAction), userInfo: nil, repeats: true)
        RunLoop.current.add(timer, forMode: .commonModes)
        
        self.timer = timer
    }
    
    private func processAssets() {
        guard isCancel == false else { return }
        if let assets = exportAssets, let item = assets.first {
            exportAssets?.removeFirst()
            self.exportSession = nil
            
            switch item.mediaType {
            case .image:
                let id = requestImageData(with: item)
                requestID = id
            case .video:
                getAVAssetAndExport(asset: item, completion: { (asset) in
                    if let asset = asset {
                        let id = self.exportVideo(asset, phasset: item)
                        self.requestID = id
                    } else {
                        self.unExportCount += 1
                        self.processAssets()
                    }
                })
                
            default:
                unExportCount += 1
                self.processAssets()
            }
        } else {
            endTask(true)
        }
    }
    
    private func requestImageData(with asset: PHAsset) -> PHImageRequestID {
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.progressHandler = { [weak self] (progress, _, _, _) in
            guard let `self` = self else { return }
            self.processProgress(progress)
        }
        
        let id = PHImageManager.default().requestImageData(for: asset, options: requestOptions, resultHandler: { (imageData, uti, imageOrientation, info) in
            if let data = imageData, self.fileSizeCallBack != nil {
                self.fileSizeCallBack?(Int64(data.count))
            }
            let name = self.assetName(asset, info: info)
            
            DispatchQueue.global(qos: .default).async(execute: {
                
                if let file = AssetManager.saveImage(with: imageData, fileName: name, to: self.directory) {
                    self.exportFilesPath?.append(file.path)
                    self.callBack?(file.path, asset)
                }
                self.finishedCount += 1
                self.processProgress()
                
                self.processAssets()
            })
        })
        
        return id
    }
    
    static func saveImage(with data: Data?, fileName: String?, to directory: File) -> File? {
        guard let data = data, let fileName = fileName else { return nil }
        
        let name = File.notDuplicatedName(for: fileName, underDirectory: directory)
        if let file = try? File.createFile(name: name, data: data, underDirectory: directory) {
            
            let image = UIImage(data: data)
            if let thumbnail = image?.aspectScaled(toFill: self.thumbnailSize) {
                file.saveThumbnail(thumbnail)
            }
            
            if let thumbnailDegraded = image?.aspectScaled(toFill: self.thumbnailDegradedSize) {
                file.saveThumbnailDegraded(thumbnailDegraded)
            }
            
            return file
        } else {
            return nil
        }
    }
    
    private func getAVAssetAndExport(asset: PHAsset, completion: @escaping (AVAsset?)->Void ) {
        let requestOptions = PHVideoRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: requestOptions) { [weak self] (asset, _, _) in
            guard let `self` = self else { return }
            if self.fileSizeCallBack != nil {
                if let urlAsset = asset as? AVURLAsset, let resources = try? urlAsset.url.resourceValues(forKeys: [.fileSizeKey]), let fileSize = resources.fileSize {
                    self.fileSizeCallBack?(Int64(fileSize))
                }
            }
            completion(asset)
        }
    }
    
    private func exportVideo(_ asset: AVAsset, phasset: PHAsset) -> PHImageRequestID {
        let requestOptions = PHVideoRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.progressHandler = { [weak self] (progress, error, stop, info) in
            guard let `self` = self else { return }
            self.processProgress(progress)
        }
        
        let id = PHImageManager.default().requestExportSession(forVideo: phasset, options: requestOptions, exportPreset: AVAssetExportPresetPassthrough) { [weak self] (exportSession, info) in
            guard let `self` = self else { return }

            if let session = exportSession {
                let path = URL(fileURLWithPath: self.directory.path)
                let fileName = self.assetName(phasset, info: info)
                let notDuplicatedName = File.notDuplicatedName(for: fileName, underDirectory: self.directory)
                let filePath = path.appendingPathComponent(notDuplicatedName)
                
                session.outputFileType = session.supportedFileTypes.first ?? self.outputFileType(filePath.pathExtension)
                
                session.outputURL = filePath
                
                let videoComposition = self.fixedComposition(with: asset)
                if videoComposition.renderSize.width != 0 {
                    session.videoComposition = videoComposition
                }
                
                self.exportSession = session
                
                session.exportAsynchronously { [weak self] in
                    guard let `self` = self else { return }
                    self.saveThumbnail(phasset, to: filePath.path)
                    self.exportFilesPath.append(filePath.path)
                    self.callBack?(filePath.path, phasset)
                    self.finishedCount += 1
                    self.processProgress()
                    self.processAssets()
                }
                
            } else {
                self.unExportCount += 1
                self.processAssets()
            }
            
        }
        return id
    }
    
    private func fixedComposition(with videoAsset: AVAsset) -> AVMutableVideoComposition {
        let degress = degreeFromVideoAsset(videoAsset)
        
        //旋转
        let videoComposition = AVMutableVideoComposition()
        
        if degress != 0, let videoTrack = videoAsset.tracks(withMediaType: AVMediaType.video).first {
            var translateToCenter: CGAffineTransform
            var mixedTransform: CGAffineTransform
            
            videoComposition.frameDuration = videoTrack.minFrameDuration
            
            let rotateInstruction = AVMutableVideoCompositionInstruction()
            rotateInstruction.timeRange = CMTimeRange(start: kCMTimeZero, duration: videoAsset.duration)
            
            let rotateLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            
            if degress == 90 {
                // 顺时针旋转90°
                translateToCenter = CGAffineTransform(translationX: videoTrack.naturalSize.height, y: 0.0)
                mixedTransform = translateToCenter.rotated(by: .pi / 2.0)
                videoComposition.renderSize = CGSize(width: videoTrack.naturalSize.height, height: videoTrack.naturalSize.width)
                rotateLayerInstruction.setTransform(mixedTransform, at: kCMTimeZero)
            } else if degress == 180 {
                // 顺时针旋转180°
                translateToCenter = CGAffineTransform(translationX: videoTrack.naturalSize.width, y: videoTrack.naturalSize.height)
                mixedTransform = translateToCenter.rotated(by: .pi)
                videoComposition.renderSize = CGSize(width: videoTrack.naturalSize.width, height: videoTrack.naturalSize.height)
                rotateLayerInstruction.setTransform(mixedTransform, at: kCMTimeZero)
            } else if degress == 270 {
                // 顺时针旋转270°
                translateToCenter = CGAffineTransform(translationX: 0.0, y: videoTrack.naturalSize.width)
                mixedTransform = translateToCenter.rotated(by: .pi * 3.0 / 2.0)
                videoComposition.renderSize = CGSize(width: videoTrack.naturalSize.height, height: videoTrack.naturalSize.width)
                rotateLayerInstruction.setTransform(mixedTransform, at: kCMTimeZero)
            }
            
            rotateInstruction.layerInstructions = [rotateLayerInstruction]
            videoComposition.instructions = [rotateInstruction]
        }
        
        return videoComposition
    }
    
    private func degreeFromVideoAsset(_ asset: AVAsset) -> Int {
        var degress = 0
        let tracks = asset.tracks(withMediaType: AVMediaType.video)
        if let videoTrack = tracks.first {
            let t = videoTrack.preferredTransform
            if t.a == 0, t.b == 1, t.c == -1.0, t.d == 0 {
                // Portrait
                degress = 90
            }else if (t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0) {
                // PortraitUpsideDown
                degress = 270
            }else if (t.a == 1.0 && t.b == 0 && t.c == 0 && t.d == 1.0) {
                // LandscapeRight
                degress = 0
            }else if (t.a == -1.0 && t.b == 0 && t.c == 0 && t.d == -1.0) {
                // LandscapeLeft
                degress = 180
            }
        }
        return degress
    }
    
    private func saveThumbnail(_ asset: PHAsset, to path: String) {
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true
        
        guard let file = File(path: path) else { return }
        file.saveDuraction(Int(asset.duration))
        PHImageManager.default().requestImage(for: asset, targetSize: AssetManager.thumbnailSize, contentMode: .aspectFill, options: requestOptions) { (image, _) in
            file.saveThumbnail(image)
            let thumbnailDegrade = image?.aspectScaled(toFill: AssetManager.thumbnailDegradedSize)
            file.saveThumbnailDegraded(thumbnailDegrade)
        }
    }
    
    private func outputFileType(_ extention: String) -> AVFileType {
        var type = AVFileType.mov
        
        if  isEqualInsensitive(extention, second: "mov"){
            type = AVFileType.mov
        } else if isEqualInsensitive(extention, second: "mp4") {
            type = AVFileType.mp4
        } else if isEqualInsensitive(extention, second: "m4v") {
            type = AVFileType.m4v
        } else if isEqualInsensitive(extention, second: "m4a") {
            type = AVFileType.m4a
        } else if isEqualInsensitive(extention, second: "3gp") {
            type = AVFileType.mobile3GPP
        } else if isEqualInsensitive(extention, second: "wav") {
            type = AVFileType.wav
        }
        
        return type
    }
    
    private func isEqualInsensitive(_ first: String, second: String) -> Bool {
        let result = first.caseInsensitiveCompare(second) == .orderedSame
        return result
    }
    
    fileprivate func assetName(_ asset: PHAsset, info: [AnyHashable : Any]?) -> String {
        if #available(iOS 9.0, *) {
            let resources = PHAssetResource.assetResources(for: asset)
            if let fileName = resources.first?.originalFilename {
                return fileName
            }
        } else {
            // Fallback on earlier versions
            if let fileURL = info?["PHImageFileURLKey"] as? URL {
                return FileManager.default.displayName(atPath: fileURL.path)
            }
        }
        
        if let fileName = asset.value(forKey: "filename") as? String {
            return fileName
        }
        
        if asset.mediaType == .video {
            return "IMG_01.mov"
        } else {
            return "IMG_01.jpg"
        }
    }
    
    @objc private func timerAction() {
        guard let progress = exportSession?.progress, progress > 0 else { return }
        self.processProgress(Double(progress))
    }
    
    private func processProgress(_ networkProgress: Double = 0) {
        
        let current = Double(self.finishedCount + self.unExportCount) + networkProgress
        let total = Double(self.totalCount)
        let progress = current/total
        
        DispatchQueue.main.async {
            self.progressBlock?(min(progress, 1))
        }
        
    }
    
    private func endTask(_ finished: Bool) {
        
        DispatchQueue.main.async(execute: {
            self.completionHandler?(finished, self.exportFilesPath)
            self.clean()
        })
    }
    
    public func cancel() {
        self.isCancel = true
        exportAssets?.removeAll()
        
        if let id = requestID {
            PHImageManager.default().cancelImageRequest(id)
        }
        
        if let session = exportSession {
            session.cancelExport()
        }
        
        endTask(false)
    }
    
    private func clean() {
        self.exportAssets = nil
        self.progressBlock = nil
        self.callBack = nil
        self.fileSizeCallBack = nil
        //        self.exportImageBlock = nil
        //        self.exportVideoBlock = nil
        self.completionHandler = nil
        self.requestID = nil
        self.exportSession = nil
        self.finishedCount = 0
        self.unExportCount = 0
        
        self.timer?.invalidate()
        self.timer = nil
    }
}

// MARK: - Import、Delete
extension AssetManager {
    static public func saveImage(url imageURL: URL, resultHandler: @escaping (_ success: Bool, _ error: Error?, _ localIdentifier: String?)
        ->
        Swift.Void) {
        var identifier: String?
        PHPhotoLibrary.shared().performChanges({
            let url = imageURL
            if #available(iOS 9.0, *) {
                let creationRequest = PHAssetCreationRequest.forAsset()
                
                creationRequest.addResource(with: .photo, fileURL: url, options: nil)
                
                identifier = creationRequest.placeholderForCreatedAsset?.localIdentifier
            } else {
                // Fallback on earlier versions
                let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                
                identifier = request?.placeholderForCreatedAsset?.localIdentifier
            }
            
        }) { (success, error) in
            DispatchQueue.main.async {
                resultHandler(success, error, identifier)
            }
        }
    }
    
    static public func saveImage(image: UIImage, resultHandler: @escaping (_ success: Bool, _ error: Error?, _ localIdentifier: String?)
        ->
        Swift.Void) {
        var identifier: String?
        
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            identifier = request.placeholderForCreatedAsset?.localIdentifier
            
        }) { (success, error) in
            DispatchQueue.main.async {
                resultHandler(success, error, identifier)
            }
        }
    }
    
    static public func saveVideo(_ videoURL:URL, resultHandler: @escaping (_ success: Bool, _ error: Error?, _ localIdentifier: String?) -> Swift.Void) {
        
        var identifier: String?
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            
            identifier = request?.placeholderForCreatedAsset?.localIdentifier
            
        }) { (success, error) in
            DispatchQueue.main.async {
                resultHandler(success, error, identifier)
            }
        }
    }
    
    @available(iOS 9.1, *)
    static public func saveLivePhoto(imageURL: URL, videoURL: URL, resultHandler: @escaping (_ success: Bool, _ error: Error?, _ localIdentifier: String?) -> Swift.Void) {
        var identifier: String?
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: imageURL, options: nil)
            request.addResource(with: .pairedVideo, fileURL: videoURL, options: nil)
            identifier = request.placeholderForCreatedAsset?.localIdentifier
        }) { (success, error) in
            DispatchQueue.main.async {
                resultHandler(success, error, identifier)
            }
        }
    }
    
    static public func deleteAsset(_ assets: [PHAsset], completionHandler: ((Bool, Error?) -> Swift.Void)? = nil) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }) { (success, error) in
            DispatchQueue.main.async {
                completionHandler?(success, error)
            }
        }
    }
}

