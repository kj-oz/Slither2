//
//  SolverTests.swift
//  SolverTests
//
//  Created by KO on 2018/09/20.
//  Copyright © 2018年 KO. All rights reserved.
//

import XCTest
@testable import Slither2

class SolverTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }
  
  func testBasic() {
    // 5ms -> B:3ms, A:3ms, A+O:10ms, C:10ms
    var lines: [String] = []
    lines.append("5 5")
    lines.append("2 1 1")
    lines.append("2  2 ")
    lines.append(" 3 12")
    lines.append("2  3 ")
    lines.append("2  2 ")
    
    let solver = Solver(board: Board(lines: lines))
    
    var option = SolveOption()
    option.doAreaCheck = false
    option.tryOneStepLevel = 2
    option.useCache = true
    option.doColorCheck = true
    option.doGateCheck = true
    option.maxGuessLevel = 120
    option.elapsedSec = 3600.0
    let result = solver.solve(option: option)

    print(String(format: "Basic:Elapsed: %.0f ms", result.elapsed * 1000))
    print(" Max Level:\(result.maxLevel)")
    XCTAssertTrue(result.solved)
  }
  
  func testHard1() {
    // 1330ms -> B:671ms, A:2282ms, A+O:593ms, C:514ms
    var lines: [String] = []
    lines.append("21 14")
    lines.append("12  2   232 0222  3  ")
    lines.append("2  22 2   1  2  221  ")
    lines.append("2 2222323  21  32 3 3")
    lines.append(" 122   21      11 2  ")
    lines.append("2 2 12 3 22  21 33 1 ")
    lines.append("1 2 1 22 23   211   3")
    lines.append("  131      12 2   1 2")
    lines.append("12  1 2212    3  3 3 ")
    lines.append("01  212   3  3 1 21  ")
    lines.append("   22  2  1 111  2322")
    lines.append("  0  1   3  1   0    ")
    lines.append("23 20 3      1 2 0 1 ")
    lines.append("  202 2  2132  1     ")
    lines.append("3    1  232 2 23 0 00")

    let solver = Solver(board: Board(lines: lines))
    
    var option = SolveOption()
    option.doAreaCheck = false
    option.tryOneStepLevel = 2
    option.useCache = true
    option.doColorCheck = true
    option.doGateCheck = true
    option.maxGuessLevel = 120
    option.elapsedSec = 3600.0
    let result = solver.solve(option: option)

    print(String(format: "Hard1:Elapsed: %.0f ms", result.elapsed * 1000))
    print(" Max Level:\(result.maxLevel)")
    XCTAssertTrue(result.solved)
  }
  
  func testHard2() {
    // 347ms -> B:51ms, A:116ms, A+O:40ms, C:44ms
    var lines: [String] = []
    lines.append("14 24")
    lines.append(" 3  3  2011   ")
    lines.append(" 3  23   2  01")
    lines.append(" 3 23        2")
    lines.append(" 2    13  32 2")
    lines.append(" 2   13   0  1")
    lines.append("     2   22   ")
    lines.append(" 331        3 ")
    lines.append(" 1 32 32302 1 ")
    lines.append("            23")
    lines.append("213  1 1     2")
    lines.append("2 2  202 2 3  ")
    lines.append("0        231  ")
    lines.append("  332        1")
    lines.append("  2 3 202  1 3")
    lines.append("1     2 3  223")
    lines.append("31            ")
    lines.append(" 3 02133 23 0 ")
    lines.append(" 1        112 ")
    lines.append("   12   0     ")
    lines.append("1  3   33   0 ")
    lines.append("3 21  20    1 ")
    lines.append("1        21 0 ")
    lines.append("01  2   10  3 ")
    lines.append("   3331  2  2 ")

    let solver = Solver(board: Board(lines: lines))
    
    var option = SolveOption()
    option.doAreaCheck = false
    option.tryOneStepLevel = 2
    option.useCache = true
    option.doColorCheck = true
    option.doGateCheck = true
    option.maxGuessLevel = 120
    option.elapsedSec = 3600.0
    let result = solver.solve(option: option)

    print(String(format: "Hard2:Elapsed: %.0f ms", result.elapsed * 1000))
    print(" Max Level:\(result.maxLevel)")
    XCTAssertTrue(result.solved)
  }
  
  func testBug1() {
    // 976ms -> B:79ms, A:127ms, A+O:60ms, C:105ms
    var lines: [String] = []
    lines.append("14 24")
    lines.append("  1 1  10 3 1 ")
    lines.append("0 3 0 2 2  12 ")
    lines.append("              ")
    lines.append(" 0101010101031")
    lines.append("              ")
    lines.append(" 3  2  1 20   ")
    lines.append("2  3 1 2   122")
    lines.append("              ")
    lines.append("1301010101010 ")
    lines.append("             2")
    lines.append("  3 3 1  0 121")
    lines.append("22 2  2  1    ")
    lines.append("    1  2  2 20")
    lines.append("111 2  1 1 3  ")
    lines.append("1             ")
    lines.append(" 0101010101031")
    lines.append("              ")
    lines.append("120   0 1 1  3")
    lines.append("   13 2  2  3 ")
    lines.append("              ")
    lines.append("1301010101010 ")
    lines.append("              ")
    lines.append(" 11  2 1 0 1 2")
    lines.append(" 1 1 10  1 1  ")
    
    let solver = Solver(board: Board(lines: lines))
    
    var option = SolveOption()
    option.doAreaCheck = false
    option.tryOneStepLevel = 2
    option.useCache = true
    option.doColorCheck = true
    option.doGateCheck = true
    option.maxGuessLevel = 120
    option.elapsedSec = 3600.0
    let result = solver.solve(option: option)

    
    print(String(format: "Bug1:Elapsed: %.0f ms", result.elapsed * 1000))
    print(" Max Level:\(result.maxLevel)")
    XCTAssertTrue(result.solved)
  }  
}
