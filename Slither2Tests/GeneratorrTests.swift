//
//  SolverTests.swift
//  SolverTests
//
//  Created by KO on 2018/09/20.
//  Copyright © 2018年 KO. All rights reserved.
//

import XCTest
@testable import Slither2

class GeneratorTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }
  
  func testGenarateLoop() {
    let generator = Generator(width: 20, height: 15)
    let option = GenerateOption()
    _ = generator.generateLoop(option: option, retryHandler: { (count) in
      
    })
//    print(String(format: "GenerateLoop:Elapsed: %.0f ms",
//                 generator.stats.elapsed.last! * 1000))
    print(" Max Level:\(generator.maxLevel)")
  }

//  func testPruneNumbers() {
//    let generator = Generator(width: 20, height: 15)
//    let loopOption = GenerateOption()
//    _ = generator.generateLoop(option: loopOption)
//    print(String(format: "GenerateLoop:Elapsed: %.0f ms",
//                 generator.elapsedGL * 1000))
//
//    var option = SolveOption()
//    option.doAreaCheck = false
//    option.doTryOneStep = true
//    option.useCache = true
//    option.doColorCheck = true
//    option.doGateCheck = true
//    option.maxGuessLevel = 0
//    option.elapsedSec = 0.2
//    let numbers = generator.pruneNumbers(solveOption: option)
//    for line in Board(width: 20, height: 15, numbers: numbers).dump() {
//      print(line)
//    }
//  }

//  func testCreateWorkbook() {
//    var solveOption = SolveOption()
//    solveOption.doAreaCheck = false
//    solveOption.doTryOneStep = true
//    solveOption.useCache = true
//    solveOption.doColorCheck = true
//    solveOption.doGateCheck = true
//    solveOption.maxGuessLevel = 0
//    solveOption.elapsedSec = 0.2
//
//    Generator.createWorkbook(path: "/tmp", numProblem: 3, width: 21, height: 14,
//                             solveOption: solveOption, boardType: .xySymmetry)
//  }
//
//  func testCreateWorkbook2() {
//    var options: [SolveOption] = []
//
//    var solveOption = SolveOption()
//    solveOption.doAreaCheck = false
//    solveOption.doTryOneStep = false
//    solveOption.useCache = true
//    solveOption.doColorCheck = false
//    solveOption.doGateCheck = false
//    solveOption.maxGuessLevel = 0
//    solveOption.elapsedSec = 0.1
//    options.append(solveOption)
//
//    solveOption.doColorCheck = true
//    options.append(solveOption)
//
//    solveOption.doColorCheck = false
//    solveOption.doGateCheck = true
//    options.append(solveOption)
//
//    solveOption.doColorCheck = true
//    options.append(solveOption)
//
//    solveOption.doTryOneStep = true
//    options.append(solveOption)
//
//    solveOption.doAreaCheck = true
//    options.append(solveOption)
//
//    solveOption.doAreaCheck = false
//    solveOption.doColorCheck = false
//    solveOption.doGateCheck = false
//    options.append(solveOption)
//
//    solveOption.doColorCheck = true
//    options.append(solveOption)
//
//    solveOption.doColorCheck = false
//    solveOption.doGateCheck = true
//    options.append(solveOption)
//
//    solveOption.doAreaCheck = false
//    solveOption.doTryOneStep = false
//    solveOption.useCache = true
//    solveOption.doColorCheck = false
//    solveOption.doGateCheck = false
//    solveOption.maxGuessLevel = 0
//    solveOption.elapsedSec = 0.2
//    options.append(solveOption)
//
//    solveOption.doColorCheck = true
//    options.append(solveOption)
//
//    solveOption.doColorCheck = false
//    solveOption.doGateCheck = true
//    options.append(solveOption)
//
//    solveOption.doColorCheck = true
//    options.append(solveOption)
//
//    solveOption.doTryOneStep = true
//    options.append(solveOption)
//
//    solveOption.doAreaCheck = true
//    options.append(solveOption)
//
//    solveOption.doAreaCheck = false
//    solveOption.doColorCheck = false
//    solveOption.doGateCheck = false
//    options.append(solveOption)
//
//    solveOption.doColorCheck = true
//    options.append(solveOption)
//
//    solveOption.doColorCheck = false
//    solveOption.doGateCheck = true
//    options.append(solveOption)
//
//    Generator.createWorkbook(path: "/tmp", width: 21, height: 14, solveOptions: options)
//  }
  
//  func testPerformanceExample() {
//    // This is an example of a performance test case.
////    self.measure {
////      // Put the code you want to measure the time of here.
////    }
//  }
  
}
