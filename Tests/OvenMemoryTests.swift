//
//  OvenMemoryTests.swift
//  Oven
//
//  Created by lihao on 2017/3/25.
//  Copyright © 2017年 Vincent Li. All rights reserved.
//

import UIKit
import XCTest
import Oven

class OvenMemoryTests: XCTestCase {
    
    var oven = MemoryCache<String>()
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        oven.ageLimit = TimeInterval.greatestFiniteMagnitude
        oven.countLimit = 200
        oven.costLimit = UInt.max
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        
        oven.removeAll()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        var keys = [String]()
        var values = [String]()
        for index in 1...200000 {
            let str = "在Solaris ZFS 中实现的ARC(Adjustable Replacement Cache)读缓存淘汰算法真是很有意义的一块软件代码。它是基于IBM的Megiddo和Modha提出的ARC（Adaptive Replacement Cache）淘汰算法演化而来的。但是ZFS的开发者们对IBM 的ARC算法做了一些扩展，以更适用于ZFS的应用场景。ZFS ARC的最早实现展现在FAST 2003的会议上，并在杂志《;Login:》的一篇文章中被详细描述。"
            keys.append("\(index)")
            values.append(str)
        }
        for index in 0..<200000 {
            oven.set(object: values[index], forKey: keys[index])
        }
        
        
        
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
            var keys = [String]()
            var values = [String]()
            for index in 1...200000 {
                let str = "在Solaris ZFS 中实现的ARC(Adjustable Replacement Cache)读缓存淘汰算法真是很有意义的一块软件代码。它是基于IBM的Megiddo和Modha提出的ARC（Adaptive Replacement Cache）淘汰算法演化而来的。但是ZFS的开发者们对IBM 的ARC算法做了一些扩展，以更适用于ZFS的应用场景。ZFS ARC的最早实现展现在FAST 2003的会议上，并在杂志《;Login:》的一篇文章中被详细描述。"
                keys.append("\(index)")
                values.append(str)
            }
            for index in 0..<199999 {
                self.oven.set(object: values[index], forKey: keys[index])
            }
        }
    }
    
}
