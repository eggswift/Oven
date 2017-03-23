//
//  Benchmark.swift
//  Oven
//
//  Created by lihao on 2017/3/23.
//  Copyright © 2017年 Vincent Li. All rights reserved.
//

import UIKit
import Oven
import YYCache
import PINCache
import TMCache
import Cache

class Benchmark: NSObject {

    // Oven Memory Cache的测试 [String: NSAttributedString]
    static func memoryCacheBenchmark() {
        
        let count = 200000
        var begin: TimeInterval!
        var end: TimeInterval!
        var time: TimeInterval!
        
        let ocDict  =   NSMutableDictionary.init()
        var dict    =   [String: Any]()
        let oven    =   MemoryCache<String>()
        let cache   =   { () -> Cache<String> in
                            let config = Config(frontKind: .memory, backKind: .memory)
                            let cache = Cache<String>.init(name: "oven.emample", config: config)
                            return cache
                        }()
        let ns      =   NSCache<AnyObject, AnyObject>()
        let pin     =   PINMemoryCache()
        let yy      =   { () -> YYMemoryCache in
                            let yy = YYMemoryCache()
                            yy.releaseOnMainThread = true
                            return yy
                        }()
        let tm      =   TMMemoryCache()
        
        var keys = [String]()
        var values = [String]()
        for index in 1...count {
           // let str = NSAttributedString.init(string: "PINCache is a fork of TMCache re-architected to fix issues with deadlocking caused by heavy use. It is a key/value store designed for persisting temporary objects that are expensive to reproduce, such as downloaded data or the results of slow processing. It is comprised of two self-similar stores, one in memory (PINMemoryCache) and one on disk (PINDiskCache), all backed by GCD and safe to access from multiple threads simultaneously. On iOS, PINMemoryCache will clear itself when the app receives a memory warning or goes into the background. Objects stored in PINDiskCache remain until you trim the cache yourself, either manually or by setting a byte or age limit.")
            let str = "PINCache is a fork of TMCache re-architected to fix issues with deadlocking caused by heavy use. It is a key/value store designed for persisting temporary objects that are expensive to reproduce, such as downloaded data or the results of slow processing. It is comprised of two self-similar stores, one in memory (PINMemoryCache) and one on disk (PINDiskCache), all backed by GCD and safe to access from multiple threads simultaneously. On iOS, PINMemoryCache will clear itself when the app receives a memory warning or goes into the background. Objects stored in PINDiskCache remain until you trim the cache yourself, either manually or by setting a byte or age limit."
            keys.append("\(index)")
            values.append(str)
        }
        
        print("Data Ready! \n=====================================");
        print("Memory cache set 200000 [String : NSAttributedString] pairs");
        
        begin = CACurrentMediaTime()
        autoreleasepool {
            for i in 0..<count {
                ocDict[keys[i]] = values[i]
            }
        }
        end = CACurrentMediaTime()
        time = end - begin
        print("NSDictionary: \(String.init(format: "%8.2f", time * 1000))")
        
        begin = CACurrentMediaTime()
        autoreleasepool {
            for i in 0..<count {
                dict[keys[i]] = values[i]
            }
        }
        end = CACurrentMediaTime()
        time = end - begin
        print("Dictionary: \(String.init(format: "%8.2f", time * 1000))")
        
        
        begin = CACurrentMediaTime()
        autoreleasepool {
            for i in 0..<count {
                oven.set(object: values[i], forKey: keys[i])
            }
        }
        end = CACurrentMediaTime()
        time = end - begin
        print("Oven.MemoryCache: \(String.init(format: "%8.2f", time * 1000))")
        
        
        begin = CACurrentMediaTime()
        autoreleasepool {
            for i in 0..<count {
                yy.setObject(values[i], forKey: keys[i])
            }
        }
        end = CACurrentMediaTime()
        time = end - begin
        print("YYMemoryCache: \(String.init(format: "%8.2f", time * 1000))")
        
        
        begin = CACurrentMediaTime()
        autoreleasepool {
            for i in 0..<count {
                pin.setObject(values[i], forKey: keys[i])
            }
        }
        end = CACurrentMediaTime()
        time = end - begin
        print("PINMemoryCache: \(String.init(format: "%8.2f", time * 1000))")
        
        
        begin = CACurrentMediaTime()
        autoreleasepool {
            for i in 0..<count {
                ns.setObject(values[i] as AnyObject, forKey: keys[i] as AnyObject)
            }
        }
        end = CACurrentMediaTime()
        time = end - begin
        print("NSCache: \(String.init(format: "%8.2f", time * 1000))")
        
        
        begin = CACurrentMediaTime()
        autoreleasepool {
            for i in 0..<count {
                tm.setObject(values[i], forKey: keys[i])
            }
        }
        end = CACurrentMediaTime()
        time = end - begin
        print("TMMemoryCache: \(String.init(format: "%8.2f", time * 1000))")
        
        
        begin = CACurrentMediaTime()
        autoreleasepool {
            for i in 0..<count {
                cache.add(keys[i], object: values[i])
            }
        }
        end = CACurrentMediaTime()
        time = end - begin
        print("Cache: \(String.init(format: "%8.2f", time * 1000))")
        
    }
    
}
