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

fileprivate class MemoryStorageItem<KeyType: Equatable>: NSObject {
    var prev: MemoryStorageItem<KeyType>?
    var next: MemoryStorageItem<KeyType>?
    
    var key: KeyType
    var value: Any
    
    var cost: UInt = 0
    var time: TimeInterval = 0.0
    
    init(key: KeyType, value: Any) {
        self.key = key
        self.value = value
    }
    
    deinit {}
}

fileprivate class MemoryStorage<KeyType : Hashable>: NSObject {
    
    var dict = [KeyType: MemoryStorageItem<KeyType>]()
    var totalCost: UInt = 0
    var totalCount: UInt = 0
    var head: MemoryStorageItem<KeyType>?
    var tail: MemoryStorageItem<KeyType>?
 
    func insert(atHead item: MemoryStorageItem<KeyType>) {
        dict[item.key] = item
        totalCost += item.cost
        totalCount += 1
        
        if head != nil {
            item.next = head
            head!.prev = item
            head = item
        } else {
            head = item
            tail = item
        }
    }
    
    func bring(toHead item: MemoryStorageItem<KeyType>) {
        if head == item {
            return
        }
        if tail == item {
            tail = item.prev
            tail!.next = nil
        } else {
            item.next!.prev = item.prev
            item.prev!.next = item.next
        }
        item.next = head
        item.prev = nil
        head!.prev = item
        head = item
    }
    
    func remove(item: MemoryStorageItem<KeyType>) {
        dict[item.key] = nil
        totalCost = item.cost
        totalCount -= 1
        if item.next != nil {
            item.next!.prev = item.prev
        }
        if item.prev != nil {
            item.prev!.next = item.next
        }
        if head == item {
            head = item.next
        }
        if tail == item {
            tail = item.prev
        }
    }
    
    func removeTail() -> MemoryStorageItem<KeyType>? {
        if tail == nil {
            return nil
        }
        let v = tail
        dict[tail!.key] = nil
        totalCost -= tail!.cost
        totalCount -= 1
        if head == tail {
            head = nil
            tail = nil
        } else {
            tail = tail!.prev
            tail!.next = nil
        }
        
        return v
    }
    
    func removeAll() {
        totalCost = 0
        totalCount = 0
        head = nil
        tail = nil
        dict = [KeyType: MemoryStorageItem]()
    }
    
}


public typealias MemoryCacheEscapeHandler<KeyType : Hashable> = ((_ : MemoryCache<KeyType>) -> ())

public class MemoryCache <KeyType : Hashable>: NSObject {
    
    fileprivate var lock = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
    fileprivate var storage = MemoryStorage<KeyType>()
    fileprivate var queue = DispatchQueue(label: "com.eggswift.cache.memory")
    
    public let name: String
    
    public var countLimit: UInt = 1000
    public var costLimit: UInt = UInt.max
    public var ageLimit: TimeInterval = Double.greatestFiniteMagnitude
    public var autoTrimInterval: TimeInterval = 5.0
    
    public var shouldRemoveAllObjectsOnMemoryWarning: Bool = true
    public var shouldRemoveAllObjectsWhenEnteringBackground: Bool = true
    
    public var didReceiveMemoryWarningBlock: MemoryCacheEscapeHandler<KeyType>?
    public var didEnterBackgroundBlock: MemoryCacheEscapeHandler<KeyType>?
    
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
        storage.removeAll()
        pthread_mutex_destroy(lock)
        lock.deinitialize()
        lock.deallocate(capacity: 1)
    }
    
    public func contains(forKey key: KeyType) -> Bool {
        pthread_mutex_lock(lock)
        let contains = storage.dict.contains { (k, v) -> Bool in
            return k == key
        }
        pthread_mutex_unlock(lock)
        
        return contains
    }
    
    public func object(forKey key: KeyType) -> Any? {
        pthread_mutex_lock(lock)
        var object: Any?
        if let item = storage.dict[key] {
            item.time = CACurrentMediaTime()
            storage.bring(toHead: item)
            object = item.value
        }
        pthread_mutex_unlock(lock)
        
        return object
    }
    
    
    public func set(object: Any?, forKey key: KeyType, withCost cost: UInt = 0) {
        guard let object = object else {
            remove(forKey: key)
            return
        }
        
        pthread_mutex_lock(lock)
        if let item = storage.dict[key] {
            storage.totalCost -= item.cost
            storage.totalCost += cost
            item.cost = cost
            item.time = CACurrentMediaTime()
            item.value = object
            storage.bring(toHead: item)
        } else {
            let item = MemoryStorageItem.init(key: key, value: object)
            item.cost = cost
            item.time = CACurrentMediaTime()
            storage.insert(atHead: item)
        }
        
        if storage.totalCost > costLimit {
            queue.async { [weak self] in
                guard let weakSelf = self else {
                    return
                }
                weakSelf.trim(toCost: weakSelf.costLimit)
            }
        }
        
        if storage.totalCount > countLimit {
            let _ = storage.removeTail()
        }
        
        pthread_mutex_unlock(lock)
    }
    
    
    public func remove(forKey key: KeyType) {
        pthread_mutex_lock(lock)
        if let item = storage.dict[key] {
            storage.remove(item: item)
        }
        
        pthread_mutex_unlock(lock)
    }

    public func removeAll() {
        pthread_mutex_lock(lock)
        storage.removeAll()
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
        let totalCount = storage.totalCount
        pthread_mutex_unlock(lock)
        return totalCount
    }
    
    public func totalCost() -> UInt {
        pthread_mutex_lock(lock)
        let totalCost = storage.totalCost
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
            storage.removeAll()
            finish = true
        }
        else if storage.totalCost <= costLimit {
            finish = true
        }
        pthread_mutex_unlock(lock)
        
        if finish { return }
        
        while !finish {
            if pthread_mutex_trylock(lock) == 0 {
                if storage.totalCost > costLimit {
                    let _ = storage.removeTail()
                } else {
                    finish = true
                }
                pthread_mutex_unlock(lock)
            } else {
                usleep(10 * 1000)
            }
        }
    }
    
    fileprivate func __trim(toCount count: UInt) {
        var finish = false
        pthread_mutex_lock(lock)
        if countLimit == 0 {
            storage.removeAll()
            finish = true
        }
        else if storage.totalCount <= countLimit {
            finish = true
        }
        pthread_mutex_unlock(lock)
        
        if finish { return }
        
        while !finish {
            if pthread_mutex_trylock(lock) == 0 {
                if storage.totalCount > countLimit {
                    let _ = storage.removeTail()
                } else {
                    finish = true
                }
                pthread_mutex_unlock(lock)
            } else {
                usleep(10 * 1000)
            }
        }
    }
    
    fileprivate func __trim(toAge age: TimeInterval) {
        var finish = false
        let now = CACurrentMediaTime()
        pthread_mutex_lock(lock)
        
        if ageLimit <= 0.0 {
            storage.removeAll()
            finish = true
        } else {
            if let last = storage.tail {
                if (now - last.time) <= ageLimit {
                    finish = true
                }
            } else {
                // Empty
                finish = true
            }
        }
        pthread_mutex_unlock(lock)
        
        if finish { return }
        
        while !finish {
            if pthread_mutex_trylock(lock) == 0 {
                if let last = storage.tail, (now - last.time) > ageLimit {
                    let _ = storage.removeTail()
                } else {
                    finish = true
                }
                pthread_mutex_unlock(lock)
            } else {
                usleep(10 * 1000)
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
