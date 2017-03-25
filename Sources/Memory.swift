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

internal struct MemoryStorageItem <KeyType: Hashable> {
    internal var key: KeyType
    internal var value: Any
    internal var cost: UInt
    internal var time: TimeInterval
    
    internal init(key: KeyType, value: Any, cost: UInt = 0, time: TimeInterval = CACurrentMediaTime()) {
        self.key = key
        self.value = value
        self.cost = cost
        self.time = time
    }
}

extension MemoryStorageItem : Equatable {
    
    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func ==(lhs: MemoryStorageItem<KeyType>, rhs: MemoryStorageItem<KeyType>) -> Bool {
        return lhs.key == rhs.key
    }
    
}

extension MemoryStorageItem : Comparable {
    
    /// Returns a Boolean value indicating whether the value of the first
    /// argument is less than that of the second argument.
    ///
    /// This function is the only requirement of the `Comparable` protocol. The
    /// remainder of the relational operator functions are implemented by the
    /// standard library for any type that conforms to `Comparable`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func <(lhs: MemoryStorageItem<KeyType>, rhs: MemoryStorageItem<KeyType>) -> Bool {
        return lhs.time < rhs.time
    }
    
    /// Returns a Boolean value indicating whether the value of the first
    /// argument is less than or equal to that of the second argument.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func <=(lhs: MemoryStorageItem<KeyType>, rhs: MemoryStorageItem<KeyType>) -> Bool {
        return lhs.time <= rhs.time
    }
    
    /// Returns a Boolean value indicating whether the value of the first
    /// argument is greater than or equal to that of the second argument.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func >=(lhs: MemoryStorageItem<KeyType>, rhs: MemoryStorageItem<KeyType>) -> Bool {
        return lhs.time >= rhs.time
    }
    
    /// Returns a Boolean value indicating whether the value of the first
    /// argument is greater than that of the second argument.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func >(lhs: MemoryStorageItem<KeyType>, rhs: MemoryStorageItem<KeyType>) -> Bool {
        return lhs.time > rhs.time
    }

}

extension MemoryStorageItem : Hashable {
    
    /// The hash value.
    ///
    /// Hash values are not guaranteed to be equal across different executions of
    /// your program. Do not save hash values to use during a future execution.
    public var hashValue: Int {
        return key.hashValue
    }
    
}


public typealias MemoryCacheEscapeHandler<KeyType : Hashable> = ((_ : MemoryCache<KeyType>) -> ())

public class MemoryCache <KeyType: Hashable> {
    
    fileprivate var lock = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
    fileprivate var queue = DispatchQueue(label: "com.eggswift.cache.memory")
    fileprivate var storage = Dictionary<KeyType, MemoryStorageItem<KeyType>>()
    
    ///
    public var algorithmType: OvenType
    
    /// The name of the cache. Default is `<no description>`.
    public let name: String
    
    /// The number of objects in the cache (read-only).
    public fileprivate(set) var totalCost: UInt = 0
    /// The total cost of objects in the cache (read-only).
    public fileprivate(set) var totalCount: UInt = 0
    
    /// The maximum number of objects the cache should hold.
    /// The default value is UInt.max, which means no limit. This is not a strict limit—if the cache goes over the limit, some objects in the cache could be evicted later in backgound thread.
    public var countLimit: UInt = UInt.max
    
    /// The maximum total cost that the cache can hold before it starts evicting objects.
    /// The default value is UInt.max, which means no limit. This is not a strict limit—if the cache goes over the limit, some objects in the cache could be evicted later in backgound thread.
    public var costLimit: UInt = UInt.max
    
    /// The maximum expiry time of objects in cache.
    /// The default value is Double.greatestFiniteMagnitude, which means no limit. This is not a strict limit—if an object goes over the limit, the object could be evicted later in backgound thread.
    public var ageLimit: TimeInterval = Double.greatestFiniteMagnitude
    
    /// The auto trim check time interval in seconds. Default is `20.0`.
    /// The cache holds an internal timer to check whether the cache reaches its limits, and if the limit is reached, it begins to evict objects.
    fileprivate var isAutoTriming: Bool = true
    fileprivate var needCancelAutoTriming: Bool = false
    public var autoTrimInterval: TimeInterval = 20 {
        didSet {
            pthread_mutex_lock(lock)
            if autoTrimInterval == Double.greatestFiniteMagnitude {
                if isAutoTriming {
                    needCancelAutoTriming = true
                }
            } else {
                if !isAutoTriming {
                    pthread_mutex_unlock(lock)
                    private_trimRecursively()
                    return
                }
            }
            pthread_mutex_unlock(lock)
        }
    }
    
    ///  If `true`, the cache will remove all objects when the app receives a memory warning. The default value is `true`.
    public var shouldRemoveAllObjectsOnMemoryWarning: Bool = true
    /// If `true`, The cache will remove all objects when the app enter background. The default value is `false`.
    public var shouldRemoveAllObjectsWhenEnteringBackground: Bool = false

    /// A block to be executed when the app receives a memory warning. The default value is nil.
    public var didReceiveMemoryWarningBlock: MemoryCacheEscapeHandler<KeyType>?
    /// A block to be executed when the app enter background. The default value is nil.
    public var didEnterBackgroundBlock: MemoryCacheEscapeHandler<KeyType>?
    
    public init(name: String = "<no description>", algorithmType type: OvenType = .LRU) {
        self.name = name
        self.algorithmType = type
        pthread_mutex_init(lock, nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(appDidReceiveMemoryWarningNotification), name: .UIApplicationDidReceiveMemoryWarning, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackgroundNotification), name: .UIApplicationDidEnterBackground, object: nil)
        
        self.private_trimRecursively()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidReceiveMemoryWarning, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidEnterBackground, object: nil)
        private_removeAll()
        pthread_mutex_destroy(lock)
        lock.deinitialize()
        lock.deallocate(capacity: 1)
    }
    
    /// Returns a Boolean value that indicates whether a given key is in cache.
    ///
    /// - Parameter key: An object identifying the value.
    /// - Returns: Whether the key is in cache.
    public func contains(forKey key: KeyType) -> Bool {
        var contains = false
        pthread_mutex_lock(lock)
        if let _ = storage.index(forKey: key) {
            contains = true
        }
        pthread_mutex_unlock(lock)
        
        return contains
    }
    
    /// Returns the value associated with a given key.
    ///
    /// - Parameter key: An object identifying the value. If nil, just return nil.
    /// - Returns: The value associated with key, or nil if no value is associated with key.
    public func object(forKey key: KeyType) -> Any? {
        var object: Any?
        pthread_mutex_lock(lock)
        if var item = storage[key] {
            object = item.value
            item.time = CACurrentMediaTime()
            storage.updateValue(item, forKey: key)
        }
        pthread_mutex_unlock(lock)
        
        return object
    }
    
    /// Sets the value of the specified key in the cache, and associates the key-value pair with the specified cost.
    ///
    /// - Parameters:
    ///   - object: The object to store in the cache. If nil, it calls `remove(_:)`.
    ///   - key: The key with which to associate the value. If nil, this method has no effect.
    ///   - cost: The cost with which to associate the key-value pair.
    public func set(object: Any?, forKey key: KeyType, withCost cost: UInt = 0) {
        guard let value = object else {
            remove(forKey: key) // Remove item safety.
            return
        }
        pthread_mutex_lock(lock)
        
        if var item = storage[key] {
            totalCost -= item.cost
            
            item.value = value
            item.cost = cost
            item.time = CACurrentMediaTime()
            
            storage.updateValue(item, forKey: key)
        } else {
            storage[key] = MemoryStorageItem.init(key: key, value: value, cost: cost, time: CACurrentMediaTime())
            totalCost += cost
            totalCount += 1
        }
        
        if totalCost > costLimit {
            queue.async { [weak self] in
                guard let weakSelf = self else {
                    return
                }
                weakSelf.private_trim(toCost: weakSelf.costLimit)
            }
        }
        if totalCount > countLimit {
            // 因为是添加一个缓存单元，所以这里删除一个就可以了。
            private_trim()
        }
        
        pthread_mutex_unlock(lock)
    }
    
    /// Removes the value of the specified key in the cache.
    ///
    /// - Parameter key: The key identifying the value to be removed. If nil, this method has no effect.
    public func remove(forKey key: KeyType) {
        pthread_mutex_lock(lock)
        if let item = storage[key] {
            totalCost -= item.cost
            totalCount -= 1
            storage.removeValue(forKey: key)
        }
        
        pthread_mutex_unlock(lock)
    }
    
    /// Clear cache safety.
    public func removeAll() {
        pthread_mutex_lock(lock)
        private_removeAll()
        pthread_mutex_unlock(lock)
    }
    
    
    // MARK: - Trim

    /// Removes objects from the cache with giving deadline.
    ///
    /// - Parameter dateLimit: The deadline (in seconds).
    public func trim(toDate dateLimit: Date) {
        let ageLimit = Date().timeIntervalSince(dateLimit)
        private_trim(toAge: ageLimit)
    }
    
    /// Removes objects from the cache with LRU, until the `totalCount` is below or equal to the specified value.
    ///
    /// - Parameter count: The total count allowed to remain after the cache has been trimmed.
    public func trim(toCount count: UInt) {
        private_trim(toCount: count)
    }
    
    /// Removes objects from the cache with LRU, until the `totalCost` is or equal to the specified value.
    ///
    /// - Parameter cost: The total cost allowed to remain after the cache has been trimmed.
    public func trim(toCost cost: UInt) {
        private_trim(toCost: cost)
    }
    
    /// Removes objects from the cache with LRU, until all expiry objects removed by the specified value.
    ///
    /// - Parameter age: The maximum age (in seconds) of objects.
    public func trim(toDate date: TimeInterval) {
        private_trim(toAge: date)
    }
    
    
    // MARK: - Notification
    
    @objc func appDidReceiveMemoryWarningNotification() {
        if let didReceiveMemoryWarningBlock = didReceiveMemoryWarningBlock {
            didReceiveMemoryWarningBlock(self)
        }
        if shouldRemoveAllObjectsOnMemoryWarning {
            removeAll() // Clear cache, safety.
        }
    }
    
    @objc func appDidEnterBackgroundNotification() {
        if let didEnterBackgroundBlock = didEnterBackgroundBlock {
            didEnterBackgroundBlock(self)
        }
        if shouldRemoveAllObjectsWhenEnteringBackground {
            removeAll() // Clear cache, safety.
        }
    }
    
}



fileprivate extension MemoryCache /* Private */ {
    
    /// Returns item that the most should be deleted.
    /// Attention: This function in the process of execution is not locked, but the other functions that call this function implements the lock, so it is safe.
    /// 返回当前最应该删除的缓存单元
    /// 注意：这个函数在执行时内部并不会加锁，但是在`MemoryCache`中的其他函数调用该函数时都会加锁，所以它是安全的。
    @discardableResult fileprivate func private_needTrim() -> MemoryStorageItem<KeyType>? {
        var item: MemoryStorageItem<KeyType>?
        switch algorithmType {
        case .LRU:
            item = private_needTrimLRU()
        default: break
        }
        
        return item
    }
    
    @discardableResult fileprivate func private_needTrimLRU() -> MemoryStorageItem<KeyType>? {
        var output: MemoryStorageItem<KeyType>?
        if let value = (storage.sorted { return $1.value.time < $0.value.time }.last?.value) {
            output = value
        }
        
        return output
    }
    
    /// Trim an item by algorithm
    /// Attention: This function in the process of execution is not locked, but the other functions that call this function implements the lock, so it is safe.
    /// 裁剪一个缓存单元
    /// 注意：这个函数在执行时内部并不会加锁，但是在`MemoryCache`中的其他函数调用该函数时都会加锁，所以它是安全的。
    fileprivate func private_trim() {
        switch algorithmType {
        case .LRU:
            private_trimLRU()
        default: break
        }
    }
    
    fileprivate func private_trimLRU() {
        if let value = (storage.sorted { return $1.value.time < $0.value.time }.last?.value) {
            totalCount -= 1
            totalCost -= value.cost
            storage.removeValue(forKey: value.key)
        }
    }
    
    /**
     Clean all data and reset statistics property.
     Attention: This function in the process of execution is not locked, but the other functions that call this function implements the lock, so it is safe.
     清除所有缓存单元并重置统计属性
     注意：这个函数在执行时内部并不会加锁，但是在`MemoryCache`中的其他函数调用该函数时都会加锁，所以它是安全的。
     */
    fileprivate func private_removeAll() {
        totalCost = 0
        totalCount = 0
        storage.removeAll(keepingCapacity: true)
    }
    
    /**
     Create a dispatch delay and auto trim in background.
     Delay autoTrimInterval seconds.
     创建一个GCD延迟任务，并在后台对缓存自动裁剪。
     延迟`autoTrimInterval`秒
     */
    fileprivate func private_trimRecursively() {
        /// Check whether Memory need to continue to loop.
        /// 检查当前是否继续执行。
        pthread_mutex_lock(lock)
        if needCancelAutoTriming == true {
            needCancelAutoTriming = false
            isAutoTriming = false
            pthread_mutex_unlock(lock)
            return
        }
        /// Schedule trim recursively
        /// 循环定时裁剪
        let dtime = DispatchTime.now() + autoTrimInterval
        DispatchQueue.main.asyncAfter(deadline: dtime, execute: { [weak self] in
            guard let weakSelf = self else {
                return
            }
            weakSelf.private_trimInBackground()
            weakSelf.private_trimRecursively()
        })
        
        pthread_mutex_unlock(lock)
    }
    
    /**
     Trim in background according to cost & count & time by LRU.
     */
    fileprivate func private_trimInBackground() {
        queue.async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            weakSelf.private_trim(toCost: weakSelf.costLimit)
            weakSelf.private_trim(toCount: weakSelf.countLimit)
            weakSelf.private_trim(toAge: weakSelf.ageLimit)
        }
    }
    
    fileprivate func private_trim(toCost costLimit: UInt) {
        var finish = false
        pthread_mutex_lock(lock)
        if costLimit == 0 {
            private_removeAll()
            finish = true
        } else if totalCost <= costLimit {
            finish = true
        }
        pthread_mutex_unlock(lock)
        
        if finish { return }
        
        while !finish {
            if pthread_mutex_trylock(lock) == 0 {
                if totalCost > costLimit {
                    private_trim()
                } else {
                    finish = true
                }
                pthread_mutex_unlock(lock)
            } else {
                usleep(10 * 1000)
            }
        }
    }
    
    fileprivate func private_trim(toCount countLimit: UInt) {
        var finish = false
        pthread_mutex_lock(lock)
        if countLimit == 0 {
            private_removeAll()
            finish = true
        } else if totalCount <= countLimit {
            finish = true
        }
        pthread_mutex_unlock(lock)
        
        if finish { return }
        
        while !finish {
            if pthread_mutex_trylock(lock) == 0 {
                if totalCount > countLimit {
                    private_trim()
                } else {
                    finish = true
                }
                pthread_mutex_unlock(lock)
            } else {
                usleep(10 * 1000)
            }
        }
    }
    
    fileprivate func private_trim(toDate dateLimit: Date) {
        let ageLimit = Date().timeIntervalSince(dateLimit)
        private_trim(toAge: ageLimit)
    }
    
    fileprivate func private_trim(toAge ageLimit: TimeInterval) {
        var finish = false
        let now = CACurrentMediaTime()
        pthread_mutex_lock(lock)
        if ageLimit <= 0.0 {
            private_removeAll()
            finish = true
        } else {
            if let time = private_needTrim()?.time {
                if (now - time) <= ageLimit {
                    finish = true
                }
            } else {
                // If empty.
                finish = true
            }
        }
        pthread_mutex_unlock(lock)
        
        if finish { return }
        
        while !finish {
            if pthread_mutex_trylock(lock) == 0 {
                if let item = private_needTrim() {
                    let time = item.time
                    if (now - time) > ageLimit {
                        totalCount -= 1
                        totalCost -= item.cost
                        storage.removeValue(forKey: item.key)
                    } else {
                        finish = true
                    }
                } else {
                    finish = true
                }
                pthread_mutex_unlock(lock)
            } else {
                usleep(10 * 1000)
            }
        }
    }
    
}
