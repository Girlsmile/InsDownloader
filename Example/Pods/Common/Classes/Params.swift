//
//  Params.swift
//  Strategy
//
//  Created by team on 06/12/2016.
//  Copyright © 2016 xyz. All rights reserved.
//

import UIKit
import SwiftyJSON
import Reachability

public let ParamsUpdatedNotification = Notification.Name.init("ParamsUpdatedNotification")

public class Params: NSObject {
    
    public static let `default` = Params()
    
    private var defaults: [String: Any]?
    private var reachability = Reachability.forInternetConnection()
    private var mappingParams = JSON.null
    private lazy var dateFormatter: Formatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
    
    // 如果一个参数名"p1"包含在 onlineTrueLockedParamNames 中，则如果过去 Params.named("p1").boolValue 返回过true，那么永远返回true，除非 "p1" 从 onlineTrueLockedParamNames 移除
    // 用于处理 “如果用户被允许使用下载功能(true)，那么即使参数关闭，该用户也可以继续使用打开下载功能”
    private var onlineTrueLockedOptions: [String]?
    private let timestampSeparator = "<=" // 如："p10-1<=20191020
    
    struct UD {
        static let ReturnedTrueRecords = "Params.ReturnedTrueRecords"
    }
    
    // 如果不需要取本地参数，则 localized = false
    static public func named(_ name: String, localized: Bool = true) -> JSON {
        return Params.default.named(name, localized: localized)
    }
    
    public func setup(defaults: [String: Any]?) {
        Params.default.defaults = defaults
    }
    
    public func updateDefaults(_ defaults: [String: Any]) {
        if self.defaults == nil {
            self.defaults = defaults
        }
        else {
            for (k, v) in defaults {
                self.defaults?[k] = v
            }
        }
    }
    
    private override init() {
        super.init()
        
        self.mappingParams = self.extractMappingParams()
        
        self.reachability?.startNotifier()
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(notification:)), name: NSNotification.Name.reachabilityChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive(notification:)), name: UIApplication.didFinishLaunchingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive(notification:)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    public func named(_ name: String, localized: Bool = true) -> JSON {
        var result: JSON = JSON.null
        
        if self.mappingParams[name].exists() {
            result = self.mappingParams[name]
            if localized {
                result = localizedJson(result)
            }
        }
        else {
            let rawValue = self.rawParams?[name]
            result = self.parseJSON(rawValue: rawValue, localized: localized)
            
            // 锁定true值的参数
            if let remoteTrueLockedOption = self.remoteTrueLockedOption(for: name) {
                let localReturnedTrueRecord = self.localReturnedTrueRecord(for: name)
                
                if result.boolValue && localReturnedTrueRecord == nil {
                    self.saveLocalReturnedTrueRecord(for: name)
                }
                else if result.boolValue == false && localReturnedTrueRecord != nil {
                    if timestamp(from: remoteTrueLockedOption) >= timestamp(from: localReturnedTrueRecord!) {
                        result = JSON.init(true)
                    }
                }
            }
        }
    
        return result
    }
    
    // MARK: - Notification
    @objc func appDidBecomeActive(notification: NSNotification) {
        self.updateParams()
    }
    
    @objc func reachabilityChanged(notification: NSNotification) {
        if self.reachability?.isReachable() == true {
            self.updateParams()
        }
    }
    
    // MARK: - Private
    private var rawParams: [String: Any]? {
        return OnlineCloud.params() ?? self.defaults
    }
    
    private func updateParams() {
        OnlineCloud.updateOnlineConfig { (_) in
            self.mappingParams = self.extractMappingParams()
            self.onlineTrueLockedOptions = Params.named("S.Params.trueLocked").array?.map({ $0.stringValue })
            NotificationCenter.default.post(name: ParamsUpdatedNotification, object: nil)
        }
    }
    
    internal func parseJSON(rawValue: Any?, localized: Bool = true) -> JSON {
        guard let rawValue = rawValue else {
            return JSON.null
        }
        
        var json: JSON? = nil
        
        if let stringJSON = (rawValue as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            let j = JSON.init(parseJSON: stringJSON)
            
            if j.dictionary != nil || j.array != nil { // JSON string
                json = j
            } else {
                json = JSON.init(rawValue: rawValue) // string
            }
        }
        
        let param = json ?? JSON.init(rawValue: rawValue) ?? JSON.null
        
        return localized == false ? param : localizedJson(param)
    }
    
    // 映射参数，参数名称为：pv<app version>，如pv1.2
    private func extractMappingParams() -> JSON {
        let rawValue = self.rawParams?["pv" + Util.appVersion()]
        return self.parseJSON(rawValue: rawValue)
    }
    
    // MARK: - Localizations
    private func localizedJson(_ json: JSON) -> JSON {
        var param = json
        
        if param.dictionary != nil {
            param = self.processRegxKey(for: param)
            
            if self.isLanguageLocalizable(json: param) {
                let jsonForCurrentLanguage = param[Util.languageCode()]
                param = jsonForCurrentLanguage != JSON.null ? jsonForCurrentLanguage : param["others"]
            }
            else if self.isCountryLocalizable(json: param) {
                let jsonForCurrentCountry = param[Util.countryCode()]
                param = jsonForCurrentCountry != JSON.null ? jsonForCurrentCountry : param["OTHERS"]
            }
        }
        
        return param
    }
    
    private func isLanguageLocalizable(json: JSON) -> Bool {
        return json["others"] != JSON.null
    }
    
    private func isCountryLocalizable(json: JSON) -> Bool {
        return json["OTHERS"] != JSON.null
    }
    
    // 处理正则表达式key，如 把 { "/US|CN|JP/": 1 } 处理成 { "US": 1, "CN": 1, "JP": 1 }
    private func processRegxKey(for json: JSON) -> JSON {
        var result = json
        
        var dictionary = json.dictionary
        if dictionary != nil {
            var regxKeys = [String]()
            
            for (k, _) in dictionary! {
                if (k as NSString).range(of: "^/[a-zA-Z\\|]*/$", options: .regularExpression).length > 0 {
                    regxKeys.append(k)
                }
            }
            
            if regxKeys.count > 0 {
                for regxKey in regxKeys {
                    let componentString = (regxKey as NSString).substring(with: NSRange.init(location: 1, length: regxKey.count-2))
                    let components = componentString.components(separatedBy: "|")
                    for component in components {
                        dictionary![component] = dictionary![regxKey]
                    }
                }
                
                result = JSON.init(rawValue: dictionary as Any) ?? JSON.null
            }
        }
        
        return result
    }
    
    func remoteTrueLockedOption(for paramName: String) -> String? {
        for option in (self.onlineTrueLockedOptions ?? []) {
            let components = option.components(separatedBy: timestampSeparator)
            guard let name = components.first, name == paramName else {
                continue
            }
            
            if components.count == 2 {
                return option
            }
            else {
                return "\(paramName)\(timestampSeparator)\(dateFormatter.string(for: Date.distantFuture)!)"
            }
        }
        
        return nil
    }
    
    func localReturnedTrueRecord(for paramName: String) -> String? {
        for item in UserDefaults.standard.stringArray(forKey: UD.ReturnedTrueRecords) ?? [] {
            if let name = item.components(separatedBy: timestampSeparator).first, name == paramName {
                return item
            }
        }
        
        return nil
    }
    
    func saveLocalReturnedTrueRecord(for paramName: String) {
        var records = UserDefaults.standard.stringArray(forKey: UD.ReturnedTrueRecords) ?? []
        let newRecord = "\(paramName)\(timestampSeparator)\(dateFormatter.string(for: Date())!)"
        records.append(newRecord)
        UserDefaults.standard.set(records, forKey: UD.ReturnedTrueRecords)
    }
    
    func timestamp(from trueLockedOption: String) -> String {
        let components = trueLockedOption.components(separatedBy: timestampSeparator)
        if components.count == 2 {
            return components[1]
        }
        
        return ""
    }
}

