//
//  LeanCloud.swift
//  Common
//
//  Created by Kevin on 09/10/2017.
//

import UIKit
import Alamofire
import SwiftyJSON

public class OnlineCloud: NSObject {
    
    static var appID: String?
    static var appKey: String?
    static var endPoint: String?
    static var backupURL: URL?
    
    private static var _params: [String: Any]?
    
    static var cloudURL: URL? {
        if let appID = self.appID, let appKey = self.appKey, let endPoint = self.endPoint {
            let urlStr = String(format: "https://%@.%@/%@.json", appID, endPoint, appKey)
            return URL(string: urlStr)
        }
        
        return nil
    }
    
    static var cloudURL2: URL? {
        if let appID = self.appID, let appKey = self.appKey, let endPoint = self.endPoint {
            let urlStr = String(format: "http://%@.%@/%@.json", appID, endPoint, appKey)
            return URL(string: urlStr)
        }
        
        return nil
    }
    
    struct UD {
        static let Params = "LC.1"
    }
    
    public static func params() -> [String: Any]? {
        if _params == nil {
            self.loadLocalParams()
        }
        
        return _params
    }
    
    public static func setup(appID: String, appKey: String, endPoint: String, backupURLStr: String? = nil) {
        self.appID = appID
        self.appKey = appKey
        self.endPoint = endPoint
        
        if let backupURLStr = backupURLStr {
            self.backupURL = URL(string: backupURLStr)
        }
        
        self.loadLocalParams()
    }
    
    /// 使用https
    internal static func updateOnlineConfig(completion: (([String: Any]?) -> Void)?) {
        guard let url = self.cloudURL else {
            completion?(nil)
            return
        }
        
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10.0)
        
        Alamofire.request(request).responseJSON { (response) in
            var result: [String: Any]?
            
            // 请求失败
            if response.value == nil {
                self.updateOnlineConfig2(completion: completion)
                return
            }
            
            if let rawValue = response.value, let json = JSON.init(rawValue: rawValue) {
                result = json.rawValue as? [String: Any]
            }
            
            if result != nil {
                _params = result
                UserDefaults.standard.set(_params, forKey: UD.Params)
            }
            
            completion?(nil)
        }
    }
    
    /// 使用http
    internal static func updateOnlineConfig2(completion: (([String: Any]?) -> Void)?) {
        guard let url = self.cloudURL2 else {
            completion?(nil)
            return
        }
        
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10.0)
        
        Alamofire.request(request).responseJSON { (response) in
            var result: [String: Any]?
            
            // 请求失败
            if response.value == nil {
                self.updateBackupOnlineConfig(completion: completion)
                return
            }
            
            if let rawValue = response.value, let json = JSON.init(rawValue: rawValue) {
                result = json.rawValue as? [String: Any]
            }
            
            if result != nil {
                _params = result
                UserDefaults.standard.set(_params, forKey: UD.Params)
            }
            
            completion?(nil)
        }
    }
    
    /// 使用备用
    internal static func updateBackupOnlineConfig(completion: (([String: Any]?) -> Void)?) {
        guard let url = self.backupURL else {
            completion?(nil)
            return
        }
        
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10.0)
        
        Alamofire.request(request).responseJSON { (response) in
            var result: [String: Any]?
            
            if let rawValue = response.value, let json = JSON.init(rawValue: rawValue) {
                result = json.rawValue as? [String: Any]
            }
            
            if result != nil {
                _params = result
                UserDefaults.standard.set(_params, forKey: UD.Params)
            }
            
            completion?(nil)
        }
    }
    
    public static func sendFeedback(_ content: String, appID: String) {
        let url = "https://api.leancloud.cn/1.1/classes/Feedback"
        
        let headers: HTTPHeaders = [
            "X-LC-Id": "qIrhMxI3NrUvrhsTOEqySc1c-gzGzoHsz",
            "X-LC-Key": "2jeY1ct7zPJmPuPcbSabx490"
        ]
        
        let parameters = [
            "appID": appID,
            "content": content,
            "bundleName": Bundle.main.bundleIdentifier ?? "",
            "languageCode": Locale.current.languageCode ?? "OTHER",
            "countryCode": Locale.current.regionCode ?? "OTHER",
            "datetime": Date().description,
            "version": Util.appVersion(),
            "device": Util.deviceModel(),
            "systemVersion": UIDevice.current.systemVersion
        ]
        
        request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
    }
    
    // MARK: - Private
    
    static func loadLocalParams() {
        _params = UserDefaults.standard.object(forKey: UD.Params) as? [String: Any]
    }
    
    static var clientParam: [String: Any] = [
        "id": UIDevice.current.identifierForVendor?.uuidString ?? "",
        "platform": "iOS",
        "app_version": Util.appVersion(),
        "app_channel": "App Store"
    ]
    
    static var requestHeader: HTTPHeaders = [
        "X-LC-Id": appID ?? "",
        "X-LC-Key": appKey ?? ""
    ]
}

