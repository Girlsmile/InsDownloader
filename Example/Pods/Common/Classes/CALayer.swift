//
//  CALayer.swift
//  Common
//
//  Created by lsc on 27/02/2017.
//
//

import UIKit

public extension CALayer {
    
    public func effect(cornerRadius: CGFloat, shadowOffset: CGSize, shadowOpacity: Float, shadowRadius: CGFloat, shadowColor: CGColor?, bounds: CGRect? = nil) {
        self.cornerRadius = cornerRadius
        self.shadowOffset = shadowOffset
        self.shadowOpacity = shadowOpacity
        self.shadowRadius = shadowRadius
        self.shadowColor = shadowColor
        
        if let bounds = bounds {
            let shadowPath = UIBezierPath(rect: bounds)
            self.shadowPath = shadowPath.cgPath
        }
    }
    
}
