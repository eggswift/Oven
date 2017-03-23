//
//  OvenTests.swift
//  OvenTests
//
//  Created by lihao on 2017/3/21.
//  Copyright © 2017年 Vincent Li. All rights reserved.
//

import XCTest
@testable import Oven

class OvenTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let cache = MemoryCache.init(name: "aaa")
        
        var keys = [String]()
        var values = [String]()
        for index in 1...200000 {
            let str = "在Solaris ZFS 中实现的ARC(Adjustable Replacement Cache)读缓存淘汰算法真是很有意义的一块软件代码。它是基于IBM的Megiddo和Modha提出的ARC（Adaptive Replacement Cache）淘汰算法演化而来的。但是ZFS的开发者们对IBM 的ARC算法做了一些扩展，以更适用于ZFS的应用场景。ZFS ARC的最早实现展现在FAST 2003的会议上，并在杂志《;Login:》的一篇文章中被详细描述。"
            keys.append("\(index)")
            values.append(str)
        }
        
        print("\n ======================== \n")
        print("Memory cache set 200000 key-value pairs\n");
        let begin = CACurrentMediaTime()
        
        for index in 0...199999 {
            cache.set(object: values[index], forKey: keys[index])
        }
        
        let end = CACurrentMediaTime()
        let time = end - begin
        
        print("Oven \(time * 1000)")
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
