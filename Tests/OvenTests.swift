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
            let str = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
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
