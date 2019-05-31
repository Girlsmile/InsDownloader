//
//  Util.swift
//  Common
//
//  Created by lsc on 27/02/2017.
//
//

import Foundation
import UIKit
import SwiftyJSON
import LocalAuthentication

/// Logging
public func LLog(_ items: Any...,
    file: String = #file,
    method: String = #function,
    line: Int = #line)
{
    #if DEBUG
        var output = ""
        for item in items {
            output += "\(item) "
        }
        output += "\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss:SSS"
        let timestamp = dateFormatter.string(from: Date())
        print("\(timestamp) | \((file as NSString).lastPathComponent)[\(line)] > \(method): ")
        print(output)
    #endif
}

/// Localizations
public func __(_ text: String) -> String {
    return NSLocalizedString(text, tableName: "Localizations", bundle: Bundle.main, value: "", comment: "")
}

public class Util {

//    /// 是否有安全区Insets
//    public static var hasSafeAreaInsets: Bool {
//        if #available(iOS 11.0, tvOS 11.0, *) {
//            return UIApplication.shared.delegate?.window??.safeAreaInsets != .zero
//        }
//        return false
//    }
    
    /// 是否有刘海
    @available(iOSApplicationExtension, unavailable)
    public static var hasTopNotch: Bool {
        if #available(iOS 11.0, tvOS 11.0, *) {
            // with notch: 44.0 on iPhone X, XS, XS Max, XR.
            // without notch: 20.0 on iPhone 8 on iOS 12+.
            return UIApplication.shared.delegate?.window??.safeAreaInsets.top ?? 0 > 20
        }
        
        return false
    }
    
    /// 是否有底部Home区域
    @available(iOSApplicationExtension, unavailable)
    public static var hasBottomSafeAreaInsets: Bool {
        if #available(iOS 11.0, tvOS 11.0, *) {
            // with home indicator: 34.0 on iPhone X, XS, XS Max, XR.
            return UIApplication.shared.delegate?.window??.safeAreaInsets.bottom ?? 0 > 0
        }
        
        return false
    }
    
    /// 安全区
    @available(iOSApplicationExtension, unavailable)
    public static var safeAreaInsets: UIEdgeInsets {
        if #available(iOS 11.0, tvOS 11.0, *) {
            if let safeAreaInsets = UIApplication.shared.delegate?.window??.safeAreaInsets {
                return safeAreaInsets
            }
        }
    
        return UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
    }
    
    /// 用于实现屏幕闪动效果
    public static func flashScreen(on view: UIView, backgroundColor: UIColor) {
        let whiteScreen = UIView()
        
        whiteScreen.frame = view.bounds
        whiteScreen.layer.opacity = 0.0
        whiteScreen.layer.backgroundColor = backgroundColor.cgColor
        view.addSubview(whiteScreen)
        
        view.bringSubviewToFront(whiteScreen)
        
        let opacityAnimation = CAKeyframeAnimation.init()
        opacityAnimation.keyPath = "opacity"
        let animationValues = [0.8, 0.0]
        let animationTimes = [0.3, 1.0]
        let timingFunction = CAMediaTimingFunction.init(name: CAMediaTimingFunctionName.linear)
        
        opacityAnimation.values = animationValues
        opacityAnimation.keyTimes = animationTimes as [NSNumber]?
        opacityAnimation.timingFunctions = [timingFunction, timingFunction]
        opacityAnimation.fillMode = CAMediaTimingFillMode.forwards
        opacityAnimation.isRemovedOnCompletion = true
        opacityAnimation.duration = 0.5
        
        whiteScreen.layer.add(opacityAnimation, forKey: "animation")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            whiteScreen.removeFromSuperview()
        }
    }

    /// 生成指定前景色图片
    public static func tintImage(source: UIImage, color: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(source.size, false, 0.0)
        let rect = CGRect(x: 0, y: 0, width: source.size.width, height: source.size.height)
        source.draw(in: rect)
        
        color.set()
        UIRectFillUsingBlendMode(rect, .sourceAtop)
        let tintImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return tintImage
    }

    /// 生成指定大小图像
    public static func resizeImage(image: UIImage, width: CGFloat, height: CGFloat = -1) -> UIImage? {
        if height == -1 {
            let newHeight = width*image.size.height/image.size.width
            UIGraphicsBeginImageContext(CGSize(width: width, height: newHeight))
            image.draw(in: CGRect(x: 0, y: 0, width: width, height: newHeight))
        } else {
            if height/width > image.size.height/image.size.width {
                let expectedWidth = width*image.size.height/height
                let left = image.size.width/2-expectedWidth/2
                
                UIGraphicsBeginImageContext(CGSize(width: width, height: height))
                
                let cropRegion = CGRect(x: left, y: 0, width: expectedWidth, height: image.size.height)
                if let cgImage = image.cgImage?.cropping(to: cropRegion) {
                    let croppedImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: image.imageOrientation)
                    croppedImage.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
                }
            } else {
                let expectedHeight = height*image.size.width/width
                let top = image.size.height/2-expectedHeight/2
                
                UIGraphicsBeginImageContext(CGSize(width: width, height: height))
                
                let cropRegion = CGRect(x: 0, y: top, width: image.size.width, height: expectedHeight)
                if let cgImage = image.cgImage?.cropping(to: cropRegion) {
                    let croppedImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: image.imageOrientation)
                    croppedImage.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
                }
            }
        }
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }

    /// 根据文件大小返回可读的字符串
    public static func formattedSize(size: UInt) -> String {
        let kb = Double(size) / 1000.0
        let mb = Double(size) / 1000.0 / 1000.0
        let gb = Double(size) / 1000.0 / 1000.0 / 1000.0
        
        if gb > 1.0 {
            return String(format: "%.1lfG", gb)
        }
        
        if mb > 1.0 {
            return String(format: "%.1lfM", mb)
        }
        
        if kb > 1.0 {
            return String(format: "%.1lfK", kb)
        }
        
        return "0K"
    }

    /// 返回格式化的时间字符串
    public static func formattedTime(from time: Int) -> String {
        let hours = time / 3600
        let minutes = time / 60 % 60
        let seconds = time % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// 返回最顶层的 view controller
    @available(iOSApplicationExtension, unavailable)
    public static func topViewController() -> UIViewController {
        var vc = UIApplication.shared.keyWindow?.rootViewController
        while vc?.presentedViewController != nil {
            vc = vc?.presentedViewController
        }
        return vc!
    }

    /// 去评论
    @available(iOSApplicationExtension, unavailable)
    public static func rateApp(appID: String) {
        if let url = URL(string: "http://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=\(appID)&pageNumber=0&sortOrdering=2&type=Purple+Software&mt=8") {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                UIApplication.shared.openURL(url)
            }
        }
    }

    /// 返回本地化的app名称
    public static func appName() -> String {
        if let appName = Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String {
            return appName
        } else if let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String {
            return appName
        } else {
            return Bundle.main.infoDictionary?["CFBundleName"] as! String
        }
    }
    
    /// 返回版本号
    public static func appVersion() -> String {
        return (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
    }

    /// 自定义 UINavigationbar 返回按钮
    public static func customNavigationBarBackIndicator(navigationItem: UINavigationItem, navigationBar: UINavigationBar?, image: UIImage) {
        let backButtonItem = UIBarButtonItem(title: " ", style: .plain, target: self, action: nil)
        navigationItem.backBarButtonItem = backButtonItem
        if let navigationBar = navigationBar {
            navigationBar.backIndicatorTransitionMaskImage = image
            navigationBar.backIndicatorImage = image
        }
    }

    /// 检测合法 URL
    public static func isUrlValid(_ text: String) -> Bool {
        let reg = "((http|https)://)?((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+"
        
        let urlTest = NSPredicate(format: "SELF MATCHES %@", reg)
        
        return urlTest.evaluate(with: text)
    }
    
    /// 检测合法 schemed URL
    public static func isUrlReachable(string urlString: String) -> Bool {
        
        if let url = URL(string: urlString), let _ = url.scheme, let _ = url.host {
            return true
        }
        
        return false
    }

    /// 返回合法的URL
    public static func formatURL(_ string: String, withPrefix prefix: String) -> String {
        
        var urlString = string
        
        let httpRange = string.range(of: "http://")
        let httpsRange = string.range(of: "https://")
        
        if httpRange != nil {
            urlString.removeSubrange(httpRange!)
        } else if httpsRange != nil {
            urlString.removeSubrange(httpsRange!)
        }
        
        urlString = urlString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed)!
        
        urlString = "\(prefix)\(urlString)"
        
        return urlString
    }

    /// 移动文件
    public static func moveFile(from source: URL, to target: URL) {
        if FileManager.default.fileExists(atPath: source.absoluteString) == false {
            LLog("Souce file does't exist")
            return
        }
        
        if FileManager.default.fileExists(atPath: target.absoluteString) == false {
            LLog("Target file does't exist")
            return
        }
        
        do {
            try FileManager.default.moveItem(at: source, to: target)
        } catch {
            LLog(error)
        }
    }
    
    public static func countryCode() -> String {
        return NSLocale.current.regionCode ?? ""
    }
    
    public static func languageCode() -> String {
        let languageCode = NSLocale.preferredLanguages.first ?? ""
        let suffix = "-\(self.countryCode())"
        
        if languageCode.hasSuffix(suffix) {
            return (languageCode as NSString).substring(to: languageCode.count - suffix.count)
        }
        else {
            return languageCode
        }
    }
    
    /// 把rawValue封装成JSON，rawValue如果支持本地化，则取当前国家/语言对应的值
    public static func parseJSON(rawValue: Any?) -> JSON {
        return Params.default.parseJSON(rawValue: rawValue)
    }
    
    // MARK: - Touch ID
    
    /// 设备是否支持Touch ID
    public static func isTouchIDAvailable() -> Bool {
        let context = LAContext()
        var error: NSError? = nil
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        if error?.code == LAError.touchIDNotAvailable.rawValue {
            return false
        }
        
        return true
    }
    
    /// 设备是否已登记Touch ID（打开了Passcode 且 设置了Touch ID）
    public static func isTouchIDEnrolled() -> Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
    
    // MARK: - Path
    
    /// 连接路径
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
    
    public static var documentsPath: String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    }
    
    public static var libraryPath: String {
        return NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
    }
    
    public static var cachesPath: String {
        return NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
    }
    
}

