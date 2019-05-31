//
//  Reminder.swift
//  CalculatorVault
//  
//  计数器、计时器
//
//  Created by Tracy on 01/04/2017.
//  Copyright © 2017 Tracy. All rights reserved.
//

/*
Example：

场景：创建n个相册弹出评论
 
1. 配置在线参数：
名称：p1-1
值：  2
描述：每创建n个相册弹出评论

2. 注册：
Counter.register(key: K.ParamName.AlbumsLimit, persistent: true)

3. 创建相册后：
let counter = Counter.find(key: K.ParamName.AlbumsLimit)
 
if RT.default.hasUserRTed == false && counter.isActive() {
    counter.increase()
    
    if counter.hitsMax {
        showRatingAlert(withDataKey: K.ParamName.RatingData4Album, limited: true, ratedAction: nil)
        counter.reset()
    }
}
*/

import UIKit
import SwiftyJSON

public class Counter: NSObject {

    //
    public static var isEnabled = true
    
    //
    public private(set) var times: Int = 0
    public private(set) var currentTimes: Int = 0
    
    public private(set) var seconds: Int = 0
    public private(set) var fireDate = Date.distantFuture
    public var expiredDate: Date {
        if fireDate == Date.distantFuture {
            return Date.distantFuture
        }
        
        let timeInterval = fireDate.timeIntervalSince1970 + Double(self.seconds)
        return Date.init(timeIntervalSince1970: timeInterval)
    }
    
    private var key: String!
    private var isPersistent = false
    private var isFrozen: Bool = false
    
    // 类型：计数器、计时器
    private enum CounterType: Int {
        case times // 达到次数n则hitsMax
        case seconds // n秒后hitsMax
    }
    
    // 在线参数配置项
    private struct OptionKey {
        static let times = "times"
        static let seconds = "seconds"
        static let days = "days"
    }
    
    private static var allCounters = [Counter]()
    
    // 注册 名称 & 参数名称
    @discardableResult
    public static func register(key: String, persistent: Bool) -> Counter {
        if let existedCounter = self.allCounters.first(where: { $0.key == key }) {
            return existedCounter
        }
        
        let newCounter = Counter()
        newCounter.key = key
        newCounter.isPersistent = persistent
        newCounter.loadPersistentAttrs()

        self.allCounters.append(newCounter)
        
        return newCounter
    }
    
    //
    public static func find(key: String) -> Counter {
        let foundCounter = self.allCounters.first(where: { $0.key == key })
        
        var counter: Counter!
        
        if foundCounter == nil {
            counter = self.register(key: key, persistent: true)
        }
        else {
            counter = foundCounter
        }
        
        if Counter.isEnabled && counter.isFrozen == false {
            counter.update()
        }
        
        return counter
    }
    
    private override init() {
        //
    }
    
    // 是否激活？（不是frozen 且 在线参数有效）
    public var isActive: Bool {
        return activeCounterType != nil
    }
    
    // 增加计数
    public func increase(times: Int = 1) {
        if self.isActive(counterType: .times) {
            self.currentTimes += times
            self.save()
        }
    }
    
    // 开始计时
    public func fire() {
        if self.isActive(counterType: .seconds) {
            if self.fireDate == .distantFuture {
                self.fireDate = Date()
                self.save()
            }
        }
    }
    
    // 复位
    public func reset() {
        self.update(resets: true)
    }
    
    // 计数是否达到最大值 或 计时是否达到expiredDate
    public var hitsMax: Bool {
        if self.isActive == false {
            return false
        }
        
        var hits = false
        
        if self.times > 0 && self.currentTimes >= self.times {
            hits = true
        }
        
        if self.seconds > 0 && (self.expiredDate.compare(Date()) == .orderedAscending) {
            hits = true
        }
        
        return hits
    }
    
    // freeze后，不能再激活
    public func freeze() {
        self.isFrozen = true
        self.save()
    }
    
    // MARK: - Private
    
    private func isActive(counterType: CounterType) -> Bool {
        if Counter.isEnabled == false {
            return false
        }
        
        if self.isFrozen {
            return false
        }
        
        switch counterType {
        case .times:
            return self.times > 0
        case .seconds:
            return self.seconds > 0
        }
    }
    
    private var activeCounterType: CounterType? {
        if isActive(counterType: .times) {
            return .times
        }
        else if isActive(counterType: .seconds) {
            return .seconds
        }
        
        return nil
    }
    
    private func update(resets: Bool = false) {
        let originalActiveCounterType = self.activeCounterType
        
        self.times = self.parseOption(for: .times)
        if resets || originalActiveCounterType != .times {
            self.currentTimes = 0
        }
        
        self.seconds = self.parseOption(for: .seconds)
        if resets || originalActiveCounterType != .seconds {
            self.fireDate = Date.distantFuture
        }
        
        self.save()
    }
    
    // MARK: - Options
    
    private func parseOption(for counterType: CounterType) -> Int {
        let option = Params.named(self.key)
        
        switch counterType {
        case .times:
            let arg = option[OptionKey.times]
            if arg.exists() {
                return arg.intValue
            }
            
            return option.intValue
            
        case .seconds:
            var arg = option[OptionKey.seconds]
            if arg.exists() {
                return arg.intValue
            }
            
            arg = option[OptionKey.days]
            if arg.exists() {
                return arg.intValue * 60 * 60 * 24
            }
        }
        
        return 0
    }

    // MARK: - Persistent
    
    private func save() {
        if self.isPersistent == false {
            return
        }
        
        let rawValue: [String: Any] = [
            "times": self.times,
            "currentTimes": self.currentTimes,
            "seconds": self.seconds,
            "fireDate": self.fireDate.timeIntervalSince1970,
            "isFrozen": self.isFrozen
            ]
        UserDefaults.standard.set(rawValue, forKey: self.persistentKey())
    }
    
    private func loadPersistentAttrs() {
        if self.isPersistent == false {
            return
        }
        
        var json = JSON.null
        if let rawValue = UserDefaults.standard.dictionary(forKey: self.persistentKey()) {
            json = JSON.init(rawValue: rawValue) ?? JSON.null
        }
        
        self.times = json["times"].intValue
        self.currentTimes = json["currentTimes"].intValue
        self.seconds = json["seconds"].intValue
        self.fireDate = Date.init(timeIntervalSince1970: json["fireDate"].doubleValue)
        self.isFrozen = json["isFrozen"].boolValue
    }
    
    private func persistentKey() -> String {
        return "Counter.\(self.key)"
    }
}
