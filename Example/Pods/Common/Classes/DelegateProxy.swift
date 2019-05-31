//
//  DelegateProxy.swift
//  CalculatorVault
//
//  Created by Kevin on 11/10/2017.
//  Copyright © 2017 Tracy. All rights reserved.
//

import UIKit

public class DelegateProxy: NSObject {
    
    public typealias Callback = () -> Void
    
    @objc public weak var delegate: AnyObject?
    
    private struct Observer {
        var selector: Selector!
        var callback: Callback!
    }
    private var observers = [Observer]()
    private var nothing = Nothing()
    private static var objectIDToProxy = [AnyHashable: DelegateProxy]()
    
    // MARK: - Public
    
    public func on(_ selector: Selector, action: @escaping Callback) {
        let observer = Observer.init(selector: selector, callback: action)
        self.observers.append(observer)
    }
    
    // MARK: - Private
    
    func actsAsProxy(for obj: AnyObject) {
        let delegateSEL = #selector(getter: delegate)
        let setDelegateSEL = #selector(setter: delegate)
        
        guard obj.responds(to: delegateSEL), obj.responds(to: setDelegateSEL) else {
            self.delegate = nil
            return
        }
        
        let objDelegate = obj.perform(delegateSEL).takeUnretainedValue()
        
        if objDelegate.isEqual(self) {
            return
        }
        
        self.delegate = objDelegate
        DispatchQueue.main.async {
            _ = obj.perform(setDelegateSEL, with: self)
        }
    }
    
    fileprivate static func proxy(for obj: AnyHashable) -> DelegateProxy {
        var proxy = self.objectIDToProxy[obj]
        
        if proxy == nil {
            proxy = DelegateProxy()
            self.objectIDToProxy[obj] = proxy
        }
        
        proxy?.actsAsProxy(for: obj as AnyObject)
        
        return proxy!
    }
    
    // MARK: - Override
    
    override public func responds(to aSelector: Selector!) -> Bool {
        if self.observers.first(where: { $0.selector == aSelector }) != nil {
            return true
        }

        //
        if self.delegate?.responds(to: aSelector) == true {
            return true
        }

        return super.responds(to: aSelector)
    }
    
    override public func forwardingTarget(for aSelector: Selector!) -> Any? {
        self.observers.forEach { (observer) in
            if observer.selector == aSelector {
                observer.callback()
            }
        }
        
        //
        if self.delegate?.responds(to: aSelector) == true {
            return self.delegate
        }
        
        return nothing
    }
    
    override public func conforms(to aProtocol: Protocol) -> Bool {
        return true
    }
}

extension NSObject {
    public var dp: DelegateProxy {
        return DelegateProxy.proxy(for: self)
    }
}

