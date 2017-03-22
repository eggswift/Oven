//
//  Disk.swift
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

public typealias EmptyBlock                 =   (() -> ())
public typealias ArchiveHandler             =   ((_ value: Any) -> Data?)
public typealias UnarchiveHandler           =   ((_ data: Data) -> Any?)
public typealias FileNameHandler            =   ((_ key: String) -> String?)
public typealias RemoveProgressCallback     =   ((_ removedCount: Int, _ totalCount: Int) -> ())
public typealias RemoveCompletionCallback   =   ((_ isSucceed: Bool, _ error: Error?) -> ())


public class Disk: NSObject {
    
    /// weak reference for all instances
    public static var instances = NSMapTable<AnyObject, AnyObject>.strongToWeakObjects()
    public static let semaphore = DispatchSemaphore.init(value: 1)

    public let name: String
    public let path: String
    public let inlineThreshold: UInt
    
    public var archiveHandler: ArchiveHandler?
    public var unarchiveHandler: UnarchiveHandler?
    public var fileNameHandler: FileNameHandler?

    public var countLimit: UInt = UInt.max
    public var costLimit: UInt = UInt.max
    public var ageLimit: TimeInterval = Double.greatestFiniteMagnitude
    public var freeDiskSpaceLimit: UInt = 0
    public var autoTrimInterval: TimeInterval = 60
    public var errorLogsEnabled: Bool {
        set {
            lock()
            storage.errorLogsEnabled = newValue
            unlock()
        }
        get {
            lock()
            let enabled = storage.errorLogsEnabled
            unlock()
            return enabled
        }
    }
    
    fileprivate var storage: Storage
    fileprivate let semaphore = DispatchSemaphore.init(value: 1)
    fileprivate var queue = DispatchQueue.init(label: "com.eggswift.cache.disk", attributes: DispatchQueue.Attributes.concurrent)
    
    public static func SharedDisk(forPath path: String) -> Disk? {
        guard path.characters.count > 0 else {
            return nil
        }
        let _ = Disk.semaphore.wait(timeout: DispatchTime.distantFuture)
        let disk = Disk.instances.object(forKey: path as AnyObject?)
        Disk.semaphore.signal()
        
        if let disk = disk as? Disk {
            return disk
        }
        
        let newDisk = Disk.init(path: path)
        
        let _ = Disk.semaphore.wait(timeout: DispatchTime.distantFuture)
        Disk.instances.setObject(newDisk, forKey: path as AnyObject?)
        Disk.semaphore.signal()
        
        return newDisk
    }

    public init(path: String, name: String = "<no description>", threshold: UInt = 20480) {
        self.path = path
        self.name = name
        self.inlineThreshold = threshold
        
        var type = StorageType.File
        if threshold == 0 {
            type = .File
        } else if threshold == UInt.max {
            type = .SQLite
        } else {
            type = .Mixed
        }
        
        self.storage = Storage.init(path: path, type: type)
        
        super.init()
        
        __trimRecursively()
    }
    
    deinit {
        // deinit
    }
    
    public override var description: String {
        get {
            return "<\(self.classForCoder): \(self)> (\(self.name): \(self.path))"
        }
    }
    
    public func contains(forKey key: String) -> Bool {
        lock()
        let contains = storage.exists(forKey: key)
        unlock()
        return contains
    }
    
    public func contains(forKey key: String, completion: ((_ key: String, _ result: Bool) -> ())?) {
        guard let completion = completion else {
            return
        }
        queue.async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            let contains = weakSelf.contains(forKey: key)
            completion(key, contains)
        }
    }
    
    public func object(forKey key: String) -> Any? {
        lock()
        let item = storage.get(forKey: key)
        unlock()
        
        guard let storageItem = item else {
            return nil
        }
        
        var object: Any?
        if let unarchiveHandler = unarchiveHandler {
            object = unarchiveHandler(storageItem.value)
        } else {
            object = NSKeyedUnarchiver.unarchiveObject(with: storageItem.value)
        }
        
//        if (object && item.extendedData) {
//            [YYDiskCache setExtendedData:item.extendedData toObject:object];
//        }
        
        return object
    }
    
    public func object(forKey key: String, completion: ((_ key: String, _ result: Any?) -> ())?) {
        guard let completion = completion else {
            return
        }
        queue.async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            let object = weakSelf.object(forKey: key)
            completion(key, object)
        }
    }
    
    public func set(object: Any?, forKey key: String) {
//        guard let object = object else {
//            remove(forKey: key)
//            return
//        }
//        
////        NSData *extendedData = [YYDiskCache getExtendedDataFromObject:object];
//
//        let value: Data?
//        if let archiveBlock = archiveBlock {
//            value = archiveBlock(object)
//        } else {
//            value = NSKeyedArchiver.archivedData(withRootObject: object)
//        }
//       
//        if let value = value {
//            
//        }
//        
//        
//        
//        
//        
//        lock()
////        storage.save(value: <#T##Data#>, forKey: <#T##String#>, filename: <#T##String?#>, extendedData: <#T##Data?#>)
//        unlock()
    }
    
    public func set(object: Any?, forKey key: String, completion: (() -> Void)?) {
        queue.async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            weakSelf.set(object: object, forKey: key)
            guard let completion = completion else {
                return
            }
            completion()
        }
    }
    
    
    public func remove(forKey key: String) {
        lock()
        storage.remove(forKey: key)
        unlock()
    }
    
    public func remove(forKey key: String, completion: ((_ : String) -> ())?) {
        queue.async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            weakSelf.remove(forKey: key)
            if let completion = completion {
                completion(key)
            }
        }
    }
    
    public func removeAll() {
        lock()
        storage.removeAll()
        unlock()
    }
    
    public func removeAll(completion: EmptyBlock?) {
        queue.async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            weakSelf.removeAll()
            guard let completion = completion else {
                return
            }
            completion()
        }
    }
    
    public func removeAll(progress: RemoveProgressCallback?, completion: RemoveCompletionCallback?) {
        queue.async { [weak self] in
            guard let weakSelf = self else {
                if let completion = completion {
                    completion (false, nil)
                }
                return
            }
            weakSelf.lock()
            weakSelf.storage.removeAll(progress: progress, completion: completion)
            weakSelf.unlock()
        }
    }
    
    
    // MARK: - GET

    public func totalCount() -> Int {
        lock()
        let count = storage.itemsCount()
        unlock()
        return count
    }
    
    public func totalCount(completion: ((_: Int) -> ())?) {
        guard let completion = completion else {
            return
        }
        queue.async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            let cost = weakSelf.totalCount()
            completion (cost)
        }
    }
    
    public func totalCost() -> Int {
        lock()
        let cost = storage.itemsSize()
        unlock()
        return cost
    }
    
    public func totalCost(completion: ((_: Int) -> ())?) {
        guard let completion = completion else {
            return
        }
        queue.async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            let cost = weakSelf.totalCost()
            completion (cost)
        }
    }
    
    
    // MARK: - Trim
    
    public func trim(toCount count: UInt) {
        lock()
        __trim(toCount: count)
        unlock()
    }

    public func trim(toCount count: UInt, completion: EmptyBlock?) {
        queue.async { [weak self] in
            guard let weakSelf = self else {
                if let completion = completion {
                    completion()
                }
                return
            }
            weakSelf.trim(toCount: count)
            if let completion = completion {
                completion()
            }
        }
    }
    
    public func trim(toCost cost: UInt) {
        lock()
        __trim(toCost: cost)
        unlock()
    }
    
    public func trim(toCost cost: UInt, completion: EmptyBlock?) {
        queue.async { [weak self] in
            guard let weakSelf = self else {
                if let completion = completion {
                    completion()
                }
                return
            }
            weakSelf.trim(toCost: cost)
            if let completion = completion {
                completion()
            }
        }
    }

    public func trim(toAge age: TimeInterval) {
        lock()
        __trim(toAge: age)
        unlock()
    }
    
    public func trim(toAge age: TimeInterval, completion: EmptyBlock?) {
        queue.async { [weak self] in
            guard let weakSelf = self else {
                if let completion = completion {
                    completion()
                }
                return
            }
            weakSelf.trim(toAge: age)
            if let completion = completion {
                completion()
            }
        }
    }

    
    // MARK: - Extension DispatchSemaphore
    fileprivate func lock() {
        let _ = self.semaphore.wait(timeout: DispatchTime.distantFuture)
    }
    
    fileprivate func unlock() {
        let _ = self.semaphore.signal()
    }
    
}

fileprivate extension Disk /* Private */ {
    
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
            weakSelf.lock()
            weakSelf.__trim(toCost: weakSelf.costLimit)
            weakSelf.__trim(toCount: weakSelf.countLimit)
            weakSelf.__trim(toAge: weakSelf.ageLimit)
            weakSelf.__trim(toFreeDiskSize: weakSelf.freeDiskSpaceLimit)
            weakSelf.unlock()
        }
    }
    
    
    fileprivate func __trim(toCost cost: UInt) {
        if cost >= UInt.max {
            return
        }
        storage.remove(toFitSize: cost)
    }
    
    fileprivate func __trim(toCount count: UInt) {
        if count >= UInt.max {
            return
        }
        storage.remove(toFitCount: count)
    }
    
    fileprivate func __trim(toAge age: TimeInterval) {
        if age <= 0 {
            storage.removeAll()
            return
        }
        
        let timeStamp = TimeInterval(time(nil))
        if timeStamp <= ageLimit {
            return
        }
        
        let age = timeStamp - ageLimit
        if age >= TimeInterval.greatestFiniteMagnitude {
            return
        }
        
        storage.remove(earlierThanTime: age)
    }
    
    fileprivate func __trim(toFreeDiskSize size: UInt) {
        let totalBytes = storage.itemsSize()
        let freeBytes = Disk.getFreeDiskSize()
        
        if totalBytes <= 0 || freeBytes < 0 {
            return
        }
        
        let needTrimBytes: Int = Int(size) - Int(freeBytes)
        
        if needTrimBytes <= 0 {
            return
        }
        
        var costLimit = totalBytes - needTrimBytes;
        if costLimit < 0 {
            costLimit = 0;
        }
        
        __trim(toCost: UInt(costLimit))
    }
    
}


public extension Disk /* Helper */ {

    /// Free disk space in bytes.
    public static func getFreeDiskSize() -> Int {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            let space = attrs[FileAttributeKey.systemFreeSize]
            if let space = space as? NSNumber {
                return space.intValue
            }
        } catch {
            return -1
        }
        
        return -1
    }
    
    /// String's md5 hash.
    public static func md5(string str: String) -> String? {
        return ""
    }

    public func filename(forKey key: String) -> String? {
        var filename: String?
        if let fileNameHandler = fileNameHandler {
            filename = fileNameHandler(key)
        }
        if let preMD5 = filename {
            filename = Disk.md5(string: preMD5)
        }
        return filename
    }
    
}
