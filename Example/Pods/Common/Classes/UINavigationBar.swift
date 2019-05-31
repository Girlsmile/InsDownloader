//
//  UINavigationBar.swift
//  Common
//
//  Created by lsc on 27/02/2017.
//
//

import UIKit

public extension UINavigationBar {
    
    public func setBottomBorderColor(color: UIColor, height: CGFloat) -> UIView {
        let bottomBorderRect = CGRect(x: 0, y: self.height, width: self.width, height: height)
        let bottomBorderView = UIView(frame: bottomBorderRect)
        bottomBorderView.backgroundColor = color
        return bottomBorderView
    }
    
}
