//
//  ViewController.swift
//  Oven-demo
//
//  Created by lihao on 2017/3/23.
//  Copyright © 2017年 Vincent Li. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        var count = 100
       // for i in 1...10 {
       //     count = 100 * i
            Benchmark.memoryCacheBenchmark(count: count, countLimit: 0)
            print("\n")
       // }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

