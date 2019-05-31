//
//  PreparingView.swift
//  Repost
//
//  Created by 古智鹏 on 2019/3/12.
//  Copyright © 2019 kevinslab. All rights reserved.
//

import Foundation
import SnapKit
import Common


class InsPreparingView: UIView {
    
    static let shared = InsPreparingView()
    
    lazy var bgView: UIView = {
        var view = UIView()
        view.backgroundColor = UIColor.black
        view.alpha = 0.3
        return view
    }()
    
    lazy var panelView: UIImageView = {
        var view = UIImageView()
        view.isUserInteractionEnabled = true
        view.backgroundColor = UIColor.white
        return view
    }()
  
    lazy var cancelButton: UIButton = {
        var view = UIButton()
        view.setTitleColor(InsParameter.Color.LightPink, for: .normal)
        view.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        view.addTarget(self, action: #selector(cancelButtonTapped), for: UIControl.Event.touchUpInside)
        return view
    }()
    
    lazy var label: UILabel  = {
        var label = UILabel()
        label.numberOfLines = 1
        label.text = __("Preparing")
        label.textAlignment = .center
        label.textColor = InsParameter.Color.Black
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        return label
    }()
    
    lazy var progressHintLabel: UILabel = {
        var view = UILabel()
        view.textColor = InsParameter.Color.DeepGray
        view.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        view.textAlignment = .left
        return view
    }()
    
    lazy var progressView: UIProgressView = {
        var view = UIProgressView()
        view.progressViewStyle = .default
        view.layer.cornerRadius = 5
        view.layer.masksToBounds = true
        view.progressTintColor = InsParameter.Color.LightPurple
        view.trackTintColor = InsParameter.Color.LightWhite
        view.progress = 0.0
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func setupUI() {
        panelView.addSubview(label)
        panelView.addSubview(cancelButton)
        panelView.addSubview(progressView)
        panelView.addSubview(progressHintLabel)
        self.addSubview(bgView)
        self.addSubview(panelView)
        setupConstrains()
    }
    
    fileprivate func setupConstrains() {
        
        bgView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        panelView.snp.makeConstraints { (make) in
            make.height.equalTo(180)
            make.top.equalTo(bgView.snp.bottom)
            make.right.left.equalToSuperview()
        }
        
        label.snp.makeConstraints { (make) in
            make.width.equalToSuperview()
            make.top.equalToSuperview().offset(15)
            make.height.equalTo(30)
        }
        
        progressHintLabel.snp.makeConstraints { (make) in
            make.top.equalTo(label.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(16)
            make.height.equalTo(22)
            make.width.equalTo(60)
        }
        
        progressView.snp.makeConstraints { (make) in
            make.top.equalTo(progressHintLabel.snp.bottom).offset(8)
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(10)
        }
        
        cancelButton.snp.makeConstraints { (make) in
            make.top.equalTo(progressView.snp.bottom).offset(30)
            make.height.equalTo(44)
            make.width.equalTo(100)
            make.centerX.equalToSuperview()
        }
        
    }
}

extension InsPreparingView {
    
    @objc func cancelButtonTapped() {
        InsNetwork.shared.cancelDownload()
        dismiss(after: 0.2, animation: true)
    }
    
    func updateProgress(totalCount: Int, didDownLoadCount: Int) {
        
        self.progressHintLabel.isHidden = false
        self.progressHintLabel.text = "\(didDownLoadCount)/\(totalCount)"
        if let progress = Float.init(exactly: Float(didDownLoadCount) / Float(totalCount)) {
            self.progressView.setProgress(progress, animated: true)
        }
        if didDownLoadCount == totalCount {
            self.label.text = __("Completed")
            cancelButton.setTitle(__(""), for: .normal)
            cancelButton.isUserInteractionEnabled = false
        }
        
    }
    
    func dismiss(after: TimeInterval, animation: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + after) {
            if animation {
                UIView.animate(withDuration: 0.4, animations: {
                    self.panelView.snp.updateConstraints { (make) in
                        make.top.equalTo(self.bgView.snp.bottom)
                    }
                    self.layoutIfNeeded()
                })
            } else {
                self.panelView.snp.updateConstraints { (make) in
                    make.top.equalTo(self.bgView.snp.bottom)
                }
            }
            
            delay(after: 0.4, execute: {
                self.isHidden = true
                self.removeFromSuperview()
            })
            
        }
    }
    
    func showFail() {
        self.label.text = __("Failed")
        dismiss(after: 0.8, animation: true)
    }
    
    func show(in view: UIView, animation: Bool) {
        
        removeAll()
        self.isHidden = false
        self.progressHintLabel.isHidden = true
        self.label.text = __("Preparing")
        cancelButton.setTitle(__("Cancel"), for: .normal)
        cancelButton.isUserInteractionEnabled = true
        self.progressView.setProgress(0, animated: false)
        view.addSubview(self)
        view.bringSubviewToFront(self)
        
        self.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        view.layoutIfNeeded()
        
        if animation {
            UIView.animate(withDuration: 0.3) {
                self.panelView.snp.updateConstraints { (make) in
                    make.top.equalTo(self.bgView.snp.bottom).offset(-180)
                }
                view.layoutIfNeeded()
            }
        } else {
            self.panelView.snp.updateConstraints { (make) in
                make.top.equalTo(self.bgView.snp.bottom).offset(-180)
            }
            view.layoutIfNeeded()
        }
        
        panelView.setCorner(corners: [.topLeft, .topRight], radii: 30)
        self.bringSubviewToFront(cancelButton)
    }
    
    func showInWindow(isCancelNeedDelete: Bool = true) {
        InsParameter.isCancelNeedDeleteDBRecord = isCancelNeedDelete
        if let window = UIApplication.shared.keyWindow {
            if window.subviews.contains(InsPreparingView.shared) {
                return
            }
            InsPreparingView.shared.show(in: window, animation: true)
        }
    }
    
    fileprivate func removeAll() {
        superview?.subviews.filter({ $0 is InsPreparingView }).forEach({ (view) in
            if view != self {
                view.layer.removeAllAnimations()
                view.removeFromSuperview()
            }
        })
    }
}

extension UIView {
    
    func setCorner(corners: UIRectCorner, radii: CGFloat, borderColor: CGColor?=nil) {
        self.layoutIfNeeded()
        let maskPath = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radii, height: radii))
        let maskLayer = CAShapeLayer()
        
        maskLayer.frame = self.bounds
        maskLayer.path = maskPath.cgPath
        self.layer.mask = maskLayer
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let color = borderColor {
                self.layer.borderWidth = 3.5
                self.layer.borderColor = color
            } else {
                self.layer.borderWidth = 0
                self.layer.borderColor = nil
            }
        }
        
    }
}
