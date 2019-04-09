//
//  AreaCheckerTest.swift
//  SlitherTests
//
//  Created by KO on 2018/10/15.
//  Copyright © 2018年 KO. All rights reserved.
//

import XCTest
@testable import Slither2

class AreaCheckerTest: XCTestCase {
  
  override func setUp() {
    super.setUp()
  }
  
  override func tearDown() {
    super.tearDown()
  }
  
  func testPointType() {
    var lines: [String] = []
    lines.append("6 6")
    lines.append("+-+-+ +-+ + +")
    lines.append("| x       x  ")
    lines.append("+x+x+x+ + + +")
    lines.append("| x   x      ")
    lines.append("+ + + + + + +")
    lines.append("      x      ")
    lines.append("+ + + + + + +")
    lines.append("  |          ")
    lines.append("+ +x+ +x+ + +")
    lines.append("      x   x  ")
    lines.append("+ +x+x+x+ + +")
    lines.append("      x      ")
    lines.append("+ + +x+x+ + +")
    var ac: AreaChecker?
    do {
      let solver = try Solver(lines: lines)
      ac = AreaChecker(solver: solver)
      try _ = ac!.check()
    } catch {
      XCTAssertTrue(false)
    }
    
    XCTAssertEqual(ac!.points[0][0].type, .wall)
    XCTAssertEqual(ac!.points[1][1].type, .wall)
    XCTAssertEqual(ac!.points[0][3].type, .terminal)
    XCTAssertEqual(ac!.points[0][4].type, .gate)
    XCTAssertEqual(ac!.points[2][4].type, .gate)
    XCTAssertEqual(ac!.points[3][1].type, .terminal)
    XCTAssertEqual(ac!.points[3][2].type, .gate)
    XCTAssertEqual(ac!.points[3][4].type, .gate)
    XCTAssertEqual(ac!.points[1][5].type, .space)
    XCTAssertEqual(ac!.points[5][6].type, .gate)
    XCTAssertEqual(ac!.points[5][1].type, .space)
  }
  
  func testMergeArea() {
    var lines: [String] = []
    lines.append("6 6")
    lines.append("+ + +x+x+ + +")
    lines.append("      x      ")
    lines.append("+ + +-+-+ + +")
    lines.append("      x      ")
    lines.append("+ + +x+x+ + +")
    lines.append("x | | x x | x")
    lines.append("+x+x+x+x+x+x+")
    lines.append("x | | x x | x")
    lines.append("+ + +x+x+ + +")
    lines.append("      x      ")
    lines.append("+ + +-+-+ + +")
    lines.append("      x      ")
    lines.append("+ + +x+x+ + +")
    var ac: AreaChecker?
    do {
      let solver = try Solver(lines: lines)
      ac = AreaChecker(solver: solver)
      try _ = ac!.check()
    } catch {
      XCTAssertTrue(false)
    }

    XCTAssertEqual(ac!.points[1][1].areas[0], ac!.points[5][1].areas[0])
    XCTAssertNotEqual(ac!.points[1][1].areas[0], ac!.points[1][5].areas[0])
    XCTAssertNotEqual(ac!.points[1][1].areas[0], ac!.points[5][5].areas[0])
    XCTAssertNotEqual(ac!.points[1][5].areas[0], ac!.points[5][5].areas[0])
  }
  
  func testChageStatus1() {
    var lines: [String] = []
    lines.append("6 6")
    lines.append("+ + + + + + +")
    lines.append("      x      ")
    lines.append("+ + +x+x+ + +")
    lines.append("      x      ")
    lines.append("+ + +x+x+ + +")
    lines.append("x | x x x | x")
    lines.append("+x+x+x+x+x+x+")
    lines.append("x | x x x | x")
    lines.append("+ + +x+x+ + +")
    lines.append("      x      ")
    lines.append("+ + +-+-+ + +")
    lines.append("      x      ")
    lines.append("+ + + + + + +")
    var ac: AreaChecker?
    do {
      let solver = try Solver(lines: lines)
      var changed = true
      while changed {
        ac = AreaChecker(solver: solver)
        try changed = ac!.check()
      }
      XCTAssertEqual(solver.board.hEdgeAt(x: 3, y: 0).status, EdgeStatus.on)
      XCTAssertEqual(solver.board.hEdgeAt(x: 3, y: 6).status, EdgeStatus.off)
    } catch {
      XCTAssertTrue(false)
    }
    

  }

  func testChageStatus2() {
    var lines: [String] = []
    lines.append("6 6")
    lines.append("+ + + + + + +")
    lines.append("             ")
    lines.append("+ + + +x+ + +")
    lines.append("      x      ")
    lines.append("+ + +x+x+ + +")
    lines.append("x | x x x | x")
    lines.append("+x+x+x+x+x+x+")
    lines.append("x | x x x | x")
    lines.append("+ + +-+-+ + +")
    lines.append("      x      ")
    lines.append("+ + + +x+ + +")
    lines.append("             ")
    lines.append("+ + + + + + +")
    var ac: AreaChecker?
    do {
      let solver = try Solver(lines: lines)
      var changed = true
      while changed {
        ac = AreaChecker(solver: solver)
        changed = try ac!.check()
      }
      XCTAssertEqual(solver.board.hEdgeAt(x: 3, y: 0).status, EdgeStatus.on)
      XCTAssertEqual(solver.board.hEdgeAt(x: 3, y: 6).status, EdgeStatus.off)
    } catch {
      XCTAssertTrue(false)
    }
    
    
  }
}
