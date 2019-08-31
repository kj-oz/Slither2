//
//  Adviser.swift
//  Slither2
//
//  Created by KO on 2019/08/10.
//  Copyright © 2019 KO. All rights reserved.
//

import Foundation
import UIKit

class Adviser {
  /// 対象の問題
  let puzzle: Puzzle
  /// 盤面
  let board: Board
  /// ここまでユーザーが行ってきた手（正規化済み）
  var userActions: [SetEdgeStatusAction] = []
  
  
  /// アドバイザを初期化する
  ///
  /// - Parameter puzzle: 問題
  init(puzzle: Puzzle) {
    self.puzzle = puzzle
    self.board = puzzle.board
    var edgeSet: Set<Edge> = []
    for action in puzzle.actions.reversed() {
      let target = action.edge
      if !edgeSet.contains(target) {
        edgeSet.insert(target)
        self.userActions.insert(action, at: 0)
      }
    }
  }
  
  /// アドバイスする情報を構築する
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
    
    for action in userActions {
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
    let finder = ActionFinder(board: Board(width: board.width, height: board.height, numbers: board.numbers))
    finder.doInitialStep()
    if let action = finder.findAbsentAction(board: board) {
      // initialize
      return action
    }
    
    finder.currentStep.rewind()
    finder.doUserActions(userActions)
    if let action = finder.findAbsentAction(board: board) {
      // minLoop
      // 小ループ1歩手前の状態は、これ以降新たなエッジがONにならない限り発生しない
      return action
    }
    
    do {
      try finder.findSurroundingElements()
    } catch {
      if error is FinderException {
        
      }
    }
    
    return nil
  }
}
