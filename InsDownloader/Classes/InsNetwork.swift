//
//  Network.swift
//  Repost
//
//  Created by 古智鹏 on 2019/2/28.
//  Copyright © 2019 kevinslab. All rights reserved.
//

import Foundation
import Alamofire
import Kanna
import Common
import SwiftyJSON

enum AnalysisResult: String, Error {
    case failure
    case invalid
    case successed
}

public class ResultContext {
    
    public typealias VoidAction = () -> Void
    public typealias IntActionn = (_ count: Int) -> Void
    
    public var isNeedDownload: Bool = false
    public var willAddMediaAction: VoidAction?
    public var didReceiveMediaAmountAction: IntActionn?
    public var didDownloadSingleMediaAction: IntActionn? //called while download one at a time
    public var didEndAction: VoidAction? //called whether download or not
    
    init() {}
}

class InsNetwork {
    
    static let `shared` = InsNetwork()
    fileprivate var context = ResultContext()
    
    var isDownloading = false {
        didSet {
            if !isDownloading {
                
                if InsParameter.needShowDefaultPregressView {
                    InsPreparingView.shared.dismiss(after: 0.8, animation: true)
                }
                
                NotificationCenter.default.post(Notification.init(name: Notification.Name.init(rawValue: InsParameter.Notification.DidEndHandleMediaNotification)))
            }
        }
    }
    
    fileprivate var request: DownloadRequest?
    fileprivate var currentDownloadMedias:[InsMedia]?
    
    fileprivate let destination:DownloadRequest.DownloadFileDestination = { _, response in
        let floderPath = InsParameter.Folder.InstaFolder
        var suggestedFilename = response.suggestedFilename!
        suggestedFilename = suggestedFilename.correctFileName(name: suggestedFilename)
        let fileURL = URL(fileURLWithPath: Util.join(component: floderPath, suggestedFilename))
        return (fileURL,[.createIntermediateDirectories, .removePreviousFile])
    }
    
    public func cancelDownload() {
        if let request = request {
            request.cancel()
        }
        
        if InsParameter.isCancelNeedDeleteDBRecord {
            if let medias = currentDownloadMedias {
                for media in medias {
                    InsMediaManager.shared.remove(media: media)
                }
            }
        }
        
        InsNetwork.shared.isDownloading = false
    }
    
    func startAnalysicInstaURL(_ url: String, completion: @escaping AnalysisResultcompletion) {
        Alamofire.request(url).responseString(completionHandler: { (response) in
            if let json = response.result.value {
                
                let medias = self.processStringToMedia(json, link: url)
                
                if medias.count > 0 {
                    completion(.successed, medias)
                } else {
                    completion(.failure, nil)
                }
                
            } else {
                completion(.invalid, nil)
            }
        })
    }
    
    fileprivate func checkInput(_ inputString: String, needDelete: Bool = true) -> Bool {
        
        LLog("original link:", inputString)
        
        guard let url = URL(string: inputString) else { LLog("url format mistake")
            return false
        }
        
        guard url.host?.contains("instagram") == true else { LLog("link is not from instagram")
            return false
        }
        
        if needDelete && InsParameter.needCleanPasteboardWhileStartHandlingLink {
            let pasteboard = UIPasteboard.general
            pasteboard.setValue("", forPasteboardType: UIPasteboard.Name.general.rawValue)
            LLog("clean pasteboard:", pasteboard.string)
        }
        
        return true
    }
    
    fileprivate func containUrl(_ inputString: String) -> Bool {
        let mediaList = InsMediaManager.shared.fetchAll()
        
        for item in mediaList {
            if let mediaUrl = item.urlString {
                if mediaUrl == inputString {
                    LLog("local catain this link:", item.urlString)
                    return true
                }
            }
        }
        
        return false
    }
    
    fileprivate func processStringToMedia(_ jsonString: String, link: String) -> [InsMedia] {
        var medias:[InsMedia] = []
        guard let doc = try? HTML(html: jsonString, encoding: .utf8) else { return medias }
        guard let content = doc.sharedData() else { return medias }
        
        let describlText = doc.describeString()
        let json = JSON(parseJSON: content)
        let originalMedia = json["entry_data"]["PostPage"][0]["graphql"]["shortcode_media"]
        let blogMediaCount = originalMedia["edge_sidecar_to_children"]["edges"].count
        
        //single media handle
        if blogMediaCount == 0 {
            let mediaJson = json["entry_data"]["PostPage"][0]["graphql"]["shortcode_media"]
            guard let media = InsMedia.init(sharedData: mediaJson, describeText: describlText, Date()) else {return medias}
            media.urlString = link
            if !InsMediaManager.shared.isLocalContain(media: media) {
                medias.append(media)
            }
            
            currentDownloadMedias = medias
            return medias
        } else {
            //multiple media handle
            for index in 0...blogMediaCount {
                guard let media = InsMedia.init(sharedData: originalMedia, describeText: describlText, Date(), displayUrlLocation: index) else { continue }
                media.urlString = link
                if !InsMediaManager.shared.isLocalContain(media: media) {
                    medias.append(media)
                }
                
            }
            
            currentDownloadMedias = medias
            return medias
        }
    }
    
    public func storeMedia(_ mediaURL: String, completion: ((Bool) -> Void)? = nil) {
        self.request = Alamofire.download(mediaURL, to: destination).response { (defaultDownloadResponse) in
            completion?(defaultDownloadResponse.error == nil)
        }
    }
    
}

extension HTMLDocument {
    func sharedData() -> String? {
        for link in self.css("script")  {
            if var content = link.content, content.hasPrefix(InsParameter.UrlAnalyzer.JsonPrefix) {
                if content.count > 24 {
                    content = content.substring(to: content.index(before: content.endIndex))
                    
                    let pattern = InsParameter.UrlAnalyzer.JsonContentPattern
                    let regex = try? NSRegularExpression.init(pattern: pattern, options: [])
                    let result = regex?.matches(in: content, options: [], range: NSRange.init(location: 0
                        , length: content.count))
                    
                    if let index = result?.first?.range {
                        let startIndex = content.index(content.startIndex, offsetBy: index.length)
                        content = content.substring(from: startIndex)
                    } else {
                        return nil
                    }
                }
                return content
            }
        }
        return nil
    }
    
    func describeString() -> String? {
        return self.title
    }
}

// MARK: - 处理逻辑
extension InsNetwork {
    
    func requestSingleMediaResource(media: InsMedia, completion: @escaping ((_ isSuccessed:Bool) -> Void)) {
        
        if InsParameter.needShowDefaultPregressView {
            InsPreparingView.shared.showInWindow()
        }
        
        InsMediaManager.shared.saveMediaResources(media: media) { (isSuccessed) in
            if isSuccessed {
                
                if InsParameter.needShowDefaultPregressView {
                    InsPreparingView.shared.updateProgress(totalCount: 1, didDownLoadCount: 1)
                    InsPreparingView.shared.dismiss(after: 0.8, animation: true)
                    delay(after: 0.8, execute: {
                        completion(true)
                    })
                } else {
                    completion(true)
                }
                
            } else {
                if InsParameter.needShowDefaultPregressView {
                    InsPreparingView.shared.showFail()
                }
                completion(false)
            }
        }
    }
    
    @discardableResult
    func requestUrl() -> ResultContext {
        
        LLog("pasteboard content:",UIPasteboard.general.string)
        LLog("download state:",InsNetwork.shared.isDownloading)
        let ctx = self.context
        if let url = UIPasteboard.general.string {
            if InsNetwork.shared.isDownloading {
                cancelDownloadWhileDownloading()
                return ctx
            }
            
            if InsNetwork.shared.checkInput(url) {
                let isLocalContainUrl = InsNetwork.shared.containUrl(url)
                InsNetwork.shared.isDownloading = true
                
                if !isLocalContainUrl {
                    readyToDownload()
                }
                
                InsNetwork.shared.startAnalysicInstaURL(url) { (result, medias) in
                    
                    LLog("json analysic result:", result.rawValue)
                    
                    guard let medias = medias, medias.count > 0 else {
                        InsNetwork.shared.isDownloading = false
                        self.context.didEndAction?()
                        return
                    }
                    
                    if isLocalContainUrl {
                        self.readyToDownload()
                    }
                    
                    let totalDownloadItemCount = medias.count
                    var didDownLoadItemCount = 0
                    self.didReceiveAmount(count: totalDownloadItemCount)
                    
                    let group = DispatchGroup()
                    
                    for media in medias {
                        
                        group.enter()
                        InsMediaManager.shared.saveMediaResources(media: media, completion: { (isSuccessed) in
                            
                            if isSuccessed {
                                InsMediaManager.shared.add(media: media, completion: { (isSuccessed) in
                                    didDownLoadItemCount += 1
                                    self.downLoadSingleMediaSuccessed(totalDownloadItemCount, didDownLoadItemCount)
                                    group.leave()
                                })
                            } else {
                                 group.leave()
                            }
                            
                        })
                    }
                    
                    group.notify(queue: DispatchQueue.main) {
                        LLog("finish handling")
                        delay(after: 0.8, execute: {
                            self.didEndDownload()
                        })
                    }
                }
            }
        } else {
            ctx.isNeedDownload = false
            ctx.didEndAction?()
        }
        
        return ctx
    }
    
    fileprivate func readyToDownload() {
        
        if InsParameter.needShowDefaultPregressView {
            InsPreparingView.shared.showInWindow()
        }
        
        NotificationCenter.default.post(Notification.init(name: Notification.Name.init(rawValue: InsParameter.Notification.WillAddMediaNotification)))
        context.isNeedDownload = true
        context.willAddMediaAction?()
    }
    
    fileprivate func cancelDownloadWhileDownloading() {
        InsNetwork.shared.isDownloading = false
        context.isNeedDownload = false
        context.didEndAction?()
    }
    
    fileprivate func didReceiveAmount(count: Int) {
        NotificationCenter.default.post(name: NSNotification.Name.init(InsParameter.Notification.DidReceiveMediaAmountNotification), object: self, userInfo: ["downLoadItemCount" : count])
        self.context.didReceiveMediaAmountAction?(count)
    }
    
    fileprivate func downLoadSingleMediaSuccessed(_ downLoadItemCount: Int, _ didDownLoadItemCount: Int) {
        
        if InsParameter.needShowDefaultPregressView {
            InsPreparingView.shared.updateProgress(totalCount: downLoadItemCount, didDownLoadCount: didDownLoadItemCount)
        }
        
        NotificationCenter.default.post(name: NSNotification.Name.init(InsParameter.Notification.DidDownLoadSingleMediaNotification), object: self, userInfo: ["didDownLoadItemCount" : didDownLoadItemCount])
        self.context.didDownloadSingleMediaAction?(didDownLoadItemCount)
        LLog("have downloaded:",didDownLoadItemCount)
    }
    
    fileprivate func didEndDownload() {
        InsNetwork.shared.isDownloading = false
        self.context.didEndAction?()
    }
    
}
