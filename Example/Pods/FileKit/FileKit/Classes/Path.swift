//
//  Path.swift
//  Pods
//
//  Created by team on 22/04/2017.
//
//

import Foundation

public class Path {
    public static var documents: String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    }
    
    public static var library: String {
        return NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
    }
    
    public static var caches: String {
        return NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
    }
    
    public static func join(component: String...) -> String {
        let components = component
        var result: NSString = ""
        for c in components {
            if result.length == 0 {
                result = c as NSString
            }
            else {
                result = result.appendingPathComponent(c) as NSString
            }
        }
        
        return result as String
    }
}
