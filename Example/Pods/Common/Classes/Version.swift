//
//  Version.swift
//  AVOSCloud-flow
//
//  Created by ljk on 2017/9/14.
//

import Foundation

public protocol SelfAware: class {
    static func awake()
}

public class Version: SelfAware {
    public let number: String
    public let upgradeTime: Date
    
    private static let versionKey = "Version.persistent"
    private static let numberKey = "number"
    private static let dateKey = "date"
    
    init?(dict: [String: Any]) {
        guard let version = dict[Version.numberKey] as? String else { return nil }
        guard let time = dict[Version.dateKey] as? Date else { return nil }
        self.number = version
        self.upgradeTime = time
    }
    
    public class func all() -> [Version] {
        guard let array = UserDefaults.standard.array(forKey: versionKey) as? [[String: Any]] else { return [] }
        let versions = array.compactMap { Version.init(dict: $0) }
        
        return versions
    }
    
    public class func current() -> Version {
        return all().last!
    }
    
    public static func awake() {
        saveCurrentVersionIfNeed()
    }
    
    private static func saveCurrentVersionIfNeed() {
        var versions: [[String: Any]] = []
        if let array = UserDefaults.standard.array(forKey: versionKey) as? [[String: Any]] {
            versions = array
        }
        let currentVersion = Util.appVersion()
        
        let lastVersion = versions.last?[numberKey] as? String
        
        guard lastVersion != currentVersion else { return }
        
        saveCurrentVersion(currentVersion, to: versions)
    }
    
    private static func saveCurrentVersion(_ version: String, to array: [[String: Any]]) {
        let dict = [numberKey: version, dateKey: Date()] as [String : Any]
        
        var newArray = array
        
        newArray.append(dict)
        
        UserDefaults.standard.set(newArray, forKey: versionKey)
    }
}

class NothingToSeeHere {
    
    static func harmlessFunction() {
        let typeCount = Int(objc_getClassList(nil, 0))
        let types = UnsafeMutablePointer<AnyClass?>.allocate(capacity: typeCount)
        let autoreleaseintTypes = AutoreleasingUnsafeMutablePointer<AnyClass>(types)
        objc_getClassList(autoreleaseintTypes, Int32(typeCount)) //获取所有的类
        for index in 0 ..< typeCount{
            (types[index] as? SelfAware.Type)?.awake() //如果该类实现了SelfAware协议，那么调用awake方法
        }
        types.deallocate()
    }
    
}

extension UIApplication {
    private static let runOnce:Void = { //使用静态属性以保证只调用一次(该属性是个方法)
        NothingToSeeHere.harmlessFunction()
    }()
    
    open override var next: UIResponder?{ //重写next属性
        UIApplication.runOnce
        return super.next
    }
}
