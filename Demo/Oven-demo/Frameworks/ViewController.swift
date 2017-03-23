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
        Benchmark.memoryCacheBenchmark()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

