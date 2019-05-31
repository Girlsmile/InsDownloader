//
//  Parameter.swift
//  Repost
//
//  Created by 古智鹏 on 2019/3/21.
//  Copyright © 2019 kevinslab. All rights reserved.
//
//  need             pod Alamofire
//                       Kanna
//                       Common
//                       SwiftyJSON
//                       FEAssetKit

import Foundation
import Common
class InsParameter {
    
    static var isCancelNeedDeleteDBRecord = false
    static var needShowDefaultPregressView = true
    static var recentlyMaxItem: Int = 10
    static var needCleanPasteboardWhileStartHandlingLink = true
    
    struct File {
        static let ThumbnailheightPixel: CGFloat = 100
    }
    
    struct Notification {
        static let WillAddMediaNotification = "willAddMediaNotification"
        static let DidReceiveMediaAmountNotification = "didReceiveMediaAmountNotification"
        static let DidDownLoadSingleMediaNotification = "DidDownLoadSingleMediaNotification"
        static let DidEndHandleMediaNotification = "DidEndHandleMediaNotification"
    }
    
    struct Folder {
        static let InstaFolder = Util.join(component: Util.libraryPath ,"/insta")
        static let DataBasePath = Util.join(component: Util.libraryPath ,"/instaDB")
        static let ImageCachePath = Util.join(component: Util.libraryPath ,"/instaImageCache")
    }
    
    struct UrlAnalyzer {
        static let JsonPrefix = "window._sharedData"
        static let JsonContentPattern = "^(" + JsonPrefix + "* +=\\s)"
        static let FileSuffixPattern = "[(\\.)].*?[(\\?)]"
    }
    
    struct Color {
        static let LightWhite = UIColor.init(hex: 0xF8F8F8)
        static let DeepGray = UIColor(hex: 0x949494)
        static let Black = UIColor(hex: 0x2C2C2C)
        static let LightPurple = UIColor(hex: 0xC13584)
        static let LightPink = UIColor(hex: 0xE1306C)
    }
    
}
