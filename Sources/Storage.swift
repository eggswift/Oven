//
//  Storage.swift
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

struct StorageItem {
    var key: String
    var value: Data
    var filename: String?
    var size: Int64 = -1
    var modTime: TimeInterval = -1
    var accessTime: TimeInterval = -1
    var extendedData: Data?
    
    init(key: String, value: Data) {
        self.key = key
        self.value = value
    }
    
}

class Storage: NSObject {
    
    // MARK: - Property

    private(set) var path: String
    private(set) var type: StorageType
    var errorLogsEnabled: Bool = true
    
    init(path: String, type: StorageType) {
        self.path = path
        self.type = type
        super.init()
    }
    
    
    // MARK: - SAVE

    func save(item: StorageItem) -> Bool {
        return true
    }

    func save(value: Data, forKey key: String, filename: String? = nil, extendedData: Data? = nil) -> Bool {
        return true
    }
    
    
    // MARK: - REMOVE
    
    @discardableResult
    func remove(forKey key: String) -> Bool {
        return true
    }
    
    func remove(forKeys: [String]) -> Bool {
        return true
    }
    
    func remove(largerThanSize size: UInt) -> Bool {
        
        return true
    }
    
    @discardableResult
    func remove(earlierThanTime time: TimeInterval) -> Bool {
        return true
    }
    
    @discardableResult
    func remove(toFitSize size: UInt) -> Bool {
        return true
    }
    
    @discardableResult
    func remove(toFitCount count: UInt) -> Bool {
        return true
    }
    
    @discardableResult
    func removeAll() -> Bool {
        return true
    }
    
    func removeAll(progress: RemoveProgressCallback?, completion: RemoveCompletionCallback?) {
        
    }
    
    
    // MARK: - GET
    
    func get(forKey key: String) -> StorageItem? {
        
        return nil
    }
    
    func getInfo(forKey key: String) -> StorageItem? {
        
        return nil
    }
    
    func getValue(forKey key: String) -> Data? {
        
        return nil
    }
    
    func get(forKeys keys: [String]) -> [StorageItem]? {
        
        return nil
    }
    
    func getInfo(forKeys keys: [String]) -> [StorageItem]? {
        
        return nil
    }
    
    func getValue(forKeys key: [String]) -> [String: Data?]? {
        
        return nil
    }
    
    
    // MARK: - GET Storage Status

    func exists(forKey key: String) -> Bool {
        
        return true
    }
    
    func itemsCount() -> Int {
        
        return 0
    }
    
    func itemsSize() -> Int {
        
        return 0
    }
    
}



fileprivate extension Storage /* Private */ {
    
    
    
    
    
    
}






