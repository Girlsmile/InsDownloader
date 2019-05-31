//
//  ContactUsViewController.swift
//  CalculatorVault
//
//  Created by Tracy on 20/07/2017.
//  Copyright © 2017 Tracy. All rights reserved.
//

import Foundation
import MessageUI

public class FeedbackMailMaker: NSObject, MFMailComposeViewControllerDelegate {
    public static let shared = FeedbackMailMaker()
    
    private var mailComposeControlerToDismissAction = [UIViewController: (() -> Void)]()
    
    public func presentMailComposeViewController(from controller: UIViewController, recipient: String? = nil, bodyComponents: ((_ components: [String]) -> [String])? = nil, dismissAction: (() -> Void)? = nil) {
        let c = MFMailComposeViewController()
        c.mailComposeDelegate = self
        
        c.setSubject(subject())
        
        let emailRecipient = Params.named("S.Feedback.recipient").string ?? recipient ?? ""
        c.setToRecipients([emailRecipient])
        
        var components = self.mailBodyComponents()
        if bodyComponents != nil {
            components = bodyComponents!(components)
        }
        c.setMessageBody(components.joined(separator: "\n"), isHTML: false)
        
        if MFMailComposeViewController.canSendMail() {
            controller.present(c, animated: true)
            
            if dismissAction != nil {
                self.mailComposeControlerToDismissAction[c] = dismissAction!
            }
        }
    }
    
    private func mailBodyComponents() -> [String] {
        let device = UIDevice.current
        let systemInfo = "System: \(device.systemName) (\(device.systemVersion))"
        
        //
        let model = "Device: \(Util.deviceModel())"
        
        //
        let appName = Util.appName()
        let version = Util.appVersion()
        let appInfo = "\(appName) version: \(version)"
        
        //
        let languageAndCountry = "Local: \(Util.languageCode()) (\(Util.countryCode()))"
        
        //
        let breaks = "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
        return [breaks, systemInfo, model, appInfo, languageAndCountry].filter{ $0 != "" }
    }
    
    private func subject() -> String {
        if let r = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String {
            return r
        }

        if let r = Bundle.main.infoDictionary?["CFBundleName"] as? String {
            return r
        }
    
        return ""
    }
    
    // MARK: - MFMailComposeViewControllerDelegate
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        let dismissAction = self.mailComposeControlerToDismissAction[controller]
        self.mailComposeControlerToDismissAction.removeValue(forKey: controller)
        controller.dismiss(animated: true, completion: dismissAction)
    }
}
