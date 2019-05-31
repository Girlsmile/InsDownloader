//
//  StatesButton.swift
//  Cloud-Music-Tube
//
//  Created by Tracy on 20/06/2017.
//  Copyright © 2017 Tina. All rights reserved.
//

import UIKit

public class StatesButton<T: Equatable>: UIButton {

    public var currentState: T? = nil {
        didSet {
            self.currentStateChanged()
        }
    }
    
    public var changesStateAutomatically = true
    
    private var stateInfos = [StateInfo]()
    
    struct StateInfo {
        var state: T
        var image: UIImage?
        var title: String?
        var titleColor: UIColor?
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    public func register(state: T, image: UIImage?, title: String? = nil, titleColor: UIColor? = nil) {
        let info = StateInfo(state: state, image: image, title: title, titleColor: titleColor)
        self.stateInfos.append(info)
        
        if self.stateInfos.count == 1 {
            self.currentState = state
        }
    }
    
    public func updateImage(_ image: UIImage?, for state: T) {
        for var info in self.stateInfos {
            if info.state == state {
                info.image = image
                break
            }
        }
        
        if self.currentState == state {
            self.setImage(image, for: .normal)
        }
    }
    
    // MARK: - Action
    @objc func tapped(sender: UIButton) {
        if let index = self.currentStateIndex() {
            if self.changesStateAutomatically {
                let nextIndex = (index + 1) % self.stateInfos.count
                let nextInfo = self.stateInfos[nextIndex]
                self.currentState = nextInfo.state
            }
        }
    }
    
    // MARK: - Private
    private func currentStateChanged() {
        if let index = self.currentStateIndex() {
            let info = self.stateInfos[index]
            if let image = info.image {
                self.setImage(image, for: .normal)
            }
            if let title = info.title {
                self.setTitle(title, for: .normal)
            }
            if let titleColor = info.titleColor {
                self.setTitleColor(titleColor, for: .normal)
            }
        }
    }
    
    private func currentStateIndex() -> Int? {
        return self.stateInfos.index { (info) -> Bool in
            return info.state == self.currentState
        }
    }
    
    private func setup() {
        self.addTarget(self, action: #selector(tapped(sender:)), for: .touchUpInside)
    }
    
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
