//
//  Adviser.swift
//  Slither2
//
//  Created by KO on 2019/08/10.
//  Copyright © 2019 KO. All rights reserved.
//

import Foundation

class Adviser {
  let puzzle: Puzzle
  let board: Board
  var actions: [SetEdgeStatusAction] = []
  
  init(puzzle: Puzzle) {
    self.puzzle = puzzle
    self.board = puzzle.board
    var edgeSet: Set<Edge> = []
    for action in puzzle.actions.reversed() {
      let target = action.edge
      if !edgeSet.contains(target) {
        edgeSet.insert(target)
        self.actions.insert(action, at: 0)
      }
    }
  }
  
  func advide() {
    if let action = findMistake() {
      // showMistake(action)
      return
    }
    
    if let action = findNextAction() {
      // showNextAction(action)
      return
    }
  }
  
  func findMistake() -> SetEdgeStatusAction? {
    let solver = Solver(board: Board(width: board.width, height: board.height, numbers: board.numbers))
    let solveOption = SolveOption()
    let result = solver.solve(option: solveOption)
    guard result.reason == .solved, let loop = solver.loop else {
      return nil
    }
    let onEdges = Set<Edge>(loop)
    
    for action in actions {
      if onEdges.contains(action.edge) {
        if action.newStatus == .off {
          return findLastAction(on: action.edge, from: puzzle.actions)
        }
      } else {
        if action.newStatus == .on {
          return findLastAction(on: action.edge, from: puzzle.actions)
        }
      }
    }
    return nil
  }
  
  private func findLastAction(on edge: Edge, from actions: [SetEdgeStatusAction]) -> SetEdgeStatusAction? {
    for action in actions.reversed() {
      if action.edge == edge {
        return action
      }
    }
    return nil
  }
  
  func findNextAction() -> SetEdgeStatusAction? {
    let af0 = ActionFinder(board: Board(width: board.width, height: board.height, numbers: board.numbers))
    af0.doInitialStep()
    if let action = af0.findAbsentAction(board: board) {
      // initialize
      return action
    }

    let af1 = ActionFinder(board: Board(width: board.width, height: board.height, numbers: board.numbers))
    af1.doUserActions(actions)
    if let action = af1.findAbsentAction(board: board) {
      // minLoop
      // 小ループ1歩手前の状態は、これ以降新たなエッジがONにならない限り発生しない
      return action
    }
    
    do {
      try af1.findSurroundingElements()
    } catch {
      if error is FinderException {
        
      }
    }
    
    return nil
  }
}
