//
//  UIImage.swift
//  Common
//
//  Created by lsc on 27/02/2017.
//
//

import UIKit

public extension UIImage {

    public convenience init(view: UIView) {
        UIGraphicsBeginImageContext(view.frame.size)
        
        if let context = UIGraphicsGetCurrentContext() {
            view.layer.render(in: context)
            if let cgImage = UIGraphicsGetImageFromCurrentImageContext()?.cgImage {
                self.init(cgImage: cgImage)
                UIGraphicsEndImageContext()
                return
            }
        }
        self.init()
    }

    public convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }

    public func tinted(color: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.size, false, 0.0)
        let rect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
        self.draw(in: rect)
        
        color.set()
        UIRectFillUsingBlendMode(rect, .sourceAtop)
        let tintImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return tintImage
    }

    public func rotated(by rotationAngle: CGFloat) -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        
        let rotatedViewBox = UIView(frame: CGRect(origin: .zero, size: self.size))
        rotatedViewBox.transform = CGAffineTransform(rotationAngle: rotationAngle)
        
        let size = rotatedViewBox.frame.size
        
        UIGraphicsBeginImageContext(size)
        
        if let bitmap = UIGraphicsGetCurrentContext() {
            bitmap.translateBy(x: size.width / 2.0, y: size.height / 2.0)
            bitmap.rotate(by: rotationAngle)
            bitmap.scaleBy(x: 1.0, y: -1.0)
            
            let origin = CGPoint(x: -self.size.width / 2.0, y: -self.size.height / 2.0)
            
            bitmap.draw(cgImage, in: CGRect(origin: origin, size: self.size))
        }
        
        if let newImage = UIGraphicsGetImageFromCurrentImageContext() {
            UIGraphicsEndImageContext()
            return newImage
        } else {
            UIGraphicsEndImageContext()
            return nil
        }
    }
    
}
