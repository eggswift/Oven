//
//  Memory.swift
//  Oven
//
//  Created by lihao on 2017/3/21.
//
//  Copyright © 2017年 Vincent Li <lihao_ios@hotmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UIKit

fileprivate class MemoryStorageItem {
    var prev: MemoryStorageItem?
    var next: MemoryStorageItem?
    
    var key: String
    var value: Any
    
    var cost: UInt = 0
    var time: TimeInterval = CACurrentMediaTime()
    
    init(key: String, value: Any) {
        self.key = key
        self.value = value
    }
    
    deinit {
        
    }
}


public struct MemoryStorage {
    var dict = [String: MemoryStorageItem]()
    var totalCost = 0
    var totalCount = 0
    var head: MemoryStorageItem?
    var tail: MemoryStorageItem?
    var releaseOnMainThread: Bool = false
    var releaseAsynchronously: Bool = true
    
    
    
    
    

}


public typealias MemoryCacheEscapeHandler = ((_ : MemoryCache) -> ())

public class MemoryCache: NSObject {

    fileprivate static let globalSerialQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
    
    fileprivate var lock = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
    fileprivate var linkedMap = LinkedMap.init()
    fileprivate var queue = DispatchQueue.init(label: "com.eggswift.cache.memory")
    
    public let name: String
    
    public var countLimit: UInt = UInt.max
    public var costLimit: UInt = UInt.max
    public var ageLimit: TimeInterval = Double.greatestFiniteMagnitude
    public var autoTrimInterval: TimeInterval = 5.0
    
    public var shouldRemoveAllObjectsOnMemoryWarning: Bool = true
    public var shouldRemoveAllObjectsWhenEnteringBackground: Bool = true
    
    public var didReceiveMemoryWarningBlock: MemoryCacheEscapeHandler?
    public var didEnterBackgroundBlock: MemoryCacheEscapeHandler?
    
    public var releaseOnMainThread: Bool = false
    public var releaseAsynchronously: Bool = true
    
    
    public init(name: String = "<no description>") {
        self.name = name
        
        super.init()
        
        pthread_mutex_init(lock, nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(appDidReceiveMemoryWarningNotification), name: .UIApplicationDidReceiveMemoryWarning, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackgroundNotification), name: .UIApplicationDidEnterBackground, object: nil)
        
        self.__trimRecursively()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidReceiveMemoryWarning, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidEnterBackground, object: nil)
        linkedMap.removeAll()
        pthread_mutex_destroy(lock)
        lock.deinitialize()
        lock.deallocate(capacity: 1)
    }
    
    public func contains(forKey key: String) -> Bool {
        guard key.characters.count > 0 else {
            return false
        }
        
        pthread_mutex_lock(lock)
        let contains = linkedMap.dic.contains { (k: String, v: LinkedMapNode?) -> Bool in
           return k == key
        }
        pthread_mutex_unlock(lock)
        
        return contains
    }
    
    public func object(forKey key: String) -> Any? {
        guard key.characters.count > 0 else {
            return false
        }
        
        pthread_mutex_lock(lock)
        var object: Any? = nil
        if var node = linkedMap.dic[key] {
            node.time = CACurrentMediaTime()
            linkedMap.bring(itemToHead: node)
            object = node.value
        }
        pthread_mutex_unlock(lock)
        
        return object
    }
    
    
    public func set(object: Any?, forKey key: String, withCost cost: UInt = 0) {
        
    }
    
    
    public func remove(forKey key: String) {
        guard key.characters.count > 0 else {
            return
        }

        pthread_mutex_lock(lock)
        if var node = linkedMap.dic[key] {
            linkedMap.remove(item: node)
            if linkedMap. {
                <#code#>
            }
        }
        
        pthread_mutex_unlock(lock)
    }

    public func removeAll() {
        pthread_mutex_lock(lock)
        linkedMap.removeAll()
        pthread_mutex_unlock(lock)
    }
    

    // MARK: - Trim
    
    public func trim(toCount count: UInt) {
        guard count > 0 else {
            removeAll()
            return
        }
        
        __trim(toCount: count)
    }
    
    public func trim(toCost cost: UInt) {
        __trim(toCost: cost)
    }
    
    public func trim(toAge age: TimeInterval) {
        __trim(toAge: age)
    }
    
    public func totalCount() -> UInt {
        pthread_mutex_lock(lock)
        let totalCount = linkedMap.totalCount
        pthread_mutex_unlock(lock)
        return totalCount
    }
    
    public func totalCost() -> UInt {
        pthread_mutex_lock(lock)
        let totalCost = linkedMap.totalCost
        pthread_mutex_unlock(lock)
        return totalCost
    }
    
    
    fileprivate func __trimRecursively() {
        let minseconds = autoTrimInterval * Double(NSEC_PER_SEC)
        let dtime = DispatchTime.now() + Double(Int64(minseconds)) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: dtime, execute: { [weak self] in
            guard let weakSelf = self else {
                return
            }
            weakSelf.__trimInBackground()
            weakSelf.__trimRecursively()
        })
    }
    
    fileprivate func __trimInBackground() {
        queue.async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            weakSelf.__trim(toCost: weakSelf.costLimit)
            weakSelf.__trim(toCount: weakSelf.countLimit)
            weakSelf.__trim(toAge: weakSelf.ageLimit)
        }
    }
    
    fileprivate func __trim(toCost cost: UInt) {
        var finish = false
        pthread_mutex_lock(lock)
        if costLimit == 0 {
            linkedMap.removeAll()
            finish = true
        }
        else if linkedMap.totalCost <= costLimit {
            finish = true
        }
        pthread_mutex_unlock(lock)
        
        if finish { return }
        
        var holder = [LinkedMapNode].init()
        while !finish {
            if pthread_mutex_trylock(lock) == 0 {
                if linkedMap.totalCost > costLimit {
                    if let node = linkedMap.remove() {
                        holder.append(node)
                    }
                } else {
                    finish = true
                }
                pthread_mutex_unlock(lock)
            } else {
                usleep(10 * 1000)
            }
        }
        
        if holder.count > 0 {
            (releaseOnMainThread ? DispatchQueue.main : Memory.queue).async {
                let _ = holder.count // release in queue
            }
        }
    }
    
    fileprivate func __trim(toCount count: UInt) {
        var finish = false
        pthread_mutex_lock(lock)
        if countLimit == 0 {
            linkedMap.removeAll()
            finish = true
        }
        else if linkedMap.totalCount <= countLimit {
            finish = true
        }
        pthread_mutex_unlock(lock)
        
        if finish { return }
        
        var holder = [LinkedMapNode].init()
        while !finish {
            if pthread_mutex_trylock(lock) == 0 {
                if linkedMap.totalCount > countLimit {
                    if let node = linkedMap.remove() {
                        holder.append(node)
                    }
                } else {
                    finish = true
                }
                pthread_mutex_unlock(lock)
            } else {
                usleep(10 * 1000)
            }
        }
        
        if holder.count > 0 {
            (releaseOnMainThread ? DispatchQueue.main : Memory.queue).async {
                let _ = holder.count // release in queue
            }
        }
    }
    
    fileprivate func __trim(toAge age: TimeInterval) {
        var finish = false
        let now = CACurrentMediaTime()
        pthread_mutex_lock(lock)
        
        if ageLimit <= 0.0 {
            linkedMap.removeAll()
            finish = true
        } else {
            if let lastNode = linkedMap.last() {
                if (now - lastNode.time) <= ageLimit {
                    finish = true
                }
            } else {
                // Empty
                finish = true
            }
        }
        pthread_mutex_unlock(lock)
        
        if finish { return }
        
        var holder = [LinkedMapNode].init()
        while !finish {
            if pthread_mutex_trylock(lock) == 0 {
                if let lastNode = linkedMap.last(), (now - lastNode.time) > ageLimit {
                    if let node = linkedMap.remove() {
                        holder.append(node)
                    }
                } else {
                    finish = true
                }
                pthread_mutex_unlock(lock)
            } else {
                usleep(10 * 1000)
            }
        }
        
        if holder.count > 0 {
            (releaseOnMainThread ? DispatchQueue.main : Memory.queue).async {
                let _ = holder.count // release in queue
            }
        }
    
    }
    
    
    // MARK: - Notification
    
    @objc func appDidReceiveMemoryWarningNotification() {
        if let didReceiveMemoryWarningBlock = didReceiveMemoryWarningBlock {
            didReceiveMemoryWarningBlock(self)
        }
        if shouldRemoveAllObjectsOnMemoryWarning {
            removeAll()
        }
    }
    
    @objc func appDidEnterBackgroundNotification() {
        if let didEnterBackgroundBlock = didEnterBackgroundBlock {
            didEnterBackgroundBlock(self)
        }
        if shouldRemoveAllObjectsWhenEnteringBackground {
            removeAll()
        }
    }

    
    
}
