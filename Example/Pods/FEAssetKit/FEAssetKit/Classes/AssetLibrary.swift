//
//  AssetLibrary.swift
//  VideoVault
//
//  Created by ljk on 2017/5/23.
//  Copyright © 2017年 flow. All rights reserved.
//

import Foundation
import Photos
import Common

public struct AlbumItem {
    //标题
    public var title: String?
    //相簿资源
    public var fetchResult: PHFetchResult<PHAsset>
    
}

final public class AssetLibrary {
    
    static private let descriptor = NSSortDescriptor(key: "creationDate", ascending: false)
    
    // MARK: - 所有图片
    public static func fetchPhotos(_ sortDescriptors: [NSSortDescriptor]? = nil) -> AlbumItem {
        
        let allPhotoAlbum = self.fetchAssets(withMediaType: PHAssetMediaType.image, sortDescriptors: sortDescriptors)
        
        return allPhotoAlbum
    }
    
    public static func fetchVideos(_ sortDescriptors: [NSSortDescriptor]? = nil) -> AlbumItem {
        
        var allVideoAlbum = self.fetchAssets(withMediaType: PHAssetMediaType.video, sortDescriptors: sortDescriptors)
        let videoTitle = systemAlbums(true, subType: .smartAlbumVideos).first?.title
        allVideoAlbum.title = videoTitle ?? allVideoAlbum.title
        
        return allVideoAlbum
    }
    
    public static func fetchAssets(withMediaType mediaType: PHAssetMediaType? = nil, sortDescriptors: [NSSortDescriptor]? = nil) -> AlbumItem {
        let assetOptions = PHFetchOptions()
        if sortDescriptors == nil {
            assetOptions.sortDescriptors = [descriptor]
        } else {
            assetOptions.sortDescriptors = sortDescriptors
        }
        
        if let mediaType = mediaType {
            assetOptions.predicate = NSPredicate(format: "mediaType = %d", mediaType.rawValue)
        }
        
        let assets = PHAsset.fetchAssets(with: assetOptions)
        
        let systemLibrary = systemAlbums(false, subType: .smartAlbumUserLibrary)
        let title = systemLibrary.first?.title ?? "Camera Roll"
        
        let album = AlbumItem(title: title, fetchResult: assets)
        
        return album
    }
    
    public static func userAlbums(_ includeEmpty: Bool = false, subType: PHAssetCollectionSubtype = .albumRegular,  mediaType: PHAssetMediaType? = nil, options: PHFetchOptions? = nil, sortDescriptors: [NSSortDescriptor]? = nil) -> [AlbumItem] {
        let userAssetCollections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: subType, options: options)
        
        var items = [AlbumItem]()
        
        userAssetCollections.enumerateObjects({ (asset, _, _) in
            if let item = self.album(of: asset, includeEmpty: includeEmpty, mediaType: mediaType, sortDescriptors: sortDescriptors) {
                items.append(item)
            }
        })
        
        return items
    }
    
    public static func systemAlbums(_ includeEmpty: Bool = false, subType: PHAssetCollectionSubtype = .albumRegular, mediaType: PHAssetMediaType? = nil, options: PHFetchOptions? = nil, sortDescriptors: [NSSortDescriptor]? = nil) -> [AlbumItem] {
        
        let systemAssetCollections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: subType, options: options)
        var items = [AlbumItem]()
        
        systemAssetCollections.enumerateObjects({ (asset, _, _) in
            if let item = self.album(of: asset, includeEmpty: includeEmpty, mediaType: mediaType, sortDescriptors: sortDescriptors) {
                items.append(item)
            }
        })
        
        return items
    }
    
    private static func album(of collection: PHAssetCollection, includeEmpty: Bool = false, mediaType: PHAssetMediaType? = nil, sortDescriptors: [NSSortDescriptor]? = nil) -> AlbumItem? {
        let result = self.fetchResult(collection, mediaType: mediaType, sortDescriptors: sortDescriptors)
        if result.count == 0 && includeEmpty == false {
            return nil
        } else {
            let albumItem = AlbumItem(title: collection.localizedTitle, fetchResult: result)
            return albumItem
        }
    }
    
    private static func fetchResult(_ collection: PHAssetCollection, mediaType: PHAssetMediaType? = nil, sortDescriptors: [NSSortDescriptor]? = nil) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        if sortDescriptors == nil {
            options.sortDescriptors = [descriptor]
        } else {
            options.sortDescriptors = sortDescriptors
        }
        if let mediaType = mediaType {
            options.predicate = NSPredicate(format: "mediaType = %d", mediaType.rawValue)
        }
        
        let fetchResult = PHAsset.fetchAssets(in: collection, options: options)
        return fetchResult
    }
    
    public static func image(asset: PHAsset, size: CGSize = CGSize(width: 720, height: 1280), completion: @escaping (_ image: UIImage?) -> Void) {
        
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .opportunistic
        
        imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: requestOptions, resultHandler: { (image, info) in
            
            DispatchQueue.main.async(execute: {
                completion(image)
            })
        })
    }
    
    public static func rawImage(ofAsset asset: PHAsset, completion: @escaping (_ image: UIImage?) -> Void) {
        let imageManager = PHImageManager.default()
        imageManager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: nil) { (image, _) in
            completion(image)
        }
    }
}

// MARK: - Permission
extension AssetLibrary {
    public static func requestPermissions(_ authorizedBlock: @escaping () -> Void, deniedBlock: @escaping (()->Void)) {
        let currentStatus = PHPhotoLibrary.authorizationStatus()
        
        switch currentStatus {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({ (status) in
                if status == .authorized {
                    DispatchQueue.main.async(execute: {
                        authorizedBlock()
                    })
                } else if status == .denied {
                    DispatchQueue.main.async(execute: {
                        deniedBlock()
                    })
                }
            })
        case .authorized:
            authorizedBlock()
        case .denied:
            deniedBlock()
        case .restricted:
            break
        }
    }
    
    private static func presentAskPermissionAlert() {
        let message = String(format: "In order to add photos, You must allow %@ to access Photos.", Util.appName())
        
        let alert = UIAlertController(title: "Can’t access Photos", message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title:  "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { (_) in
            guard let url = URL(string: UIApplicationOpenSettingsURLString) else { return }
            UIApplication.shared.openURL(url)
        }))
        
        Util.topViewController().present(alert, animated: true, completion: nil)
    }
}
