//
//  Adviser.swift
//  Slither2
//
//  Created by KO on 2019/08/10.
//  Copyright © 2019 KO. All rights reserved.
//

import Foundation
import UIKit

class FindResult {
  let action: SetEdgeStatusAction
  let context: SolvingContext
  
  init(action: SetEdgeStatusAction, context: SolvingContext) {
    self.action = action
    self.context = context
  }
}

class Adviser {
  /// 対象の問題
  let puzzle: Puzzle
  /// 盤面
  let board: Board
  /// ここまでユーザーが行ってきた手（正規化済み、現盤面上の要素を利用）
  var userActions: [SetEdgeStatusAction] = []
  
  /// アドバイザを初期化する
  ///
  /// - Parameter puzzle: 問題
  init(puzzle: Puzzle) {
    self.puzzle = puzzle
    self.board = puzzle.board
    var edgeSet: Set<Edge> = []
    for i in (0 ... puzzle.currentIndex).reversed() {
      let action = puzzle.actions[i]
      let target = action.edge
      if !edgeSet.contains(target) {
        edgeSet.insert(target)
        self.userActions.insert(action, at: 0)
      }
    }
  }
  
  /// アドバイスする情報を構築する
  func advise() -> AdviseInfo? {
    if let index = findMistake() {
      return MistakeAdviseInfo(puzzle: puzzle, index: index)
    }
    
    if let result = findNextAction() {
      switch result.context.function {
      case .initialize, .smallLoop, .checkNode, .checkCell, .checkGate, .checkColor:
        return MissAdviseInfo(result: result)
      case .tryFail:
        return TryFailAdviseInfo(result: result)
      case .trySameResult:
        return TrySameResultAdviseInfo(result: result)
      case .checkArea:
        return AreaCheckAdviseInfo(result: result)
      }
    }
    return nil
  }
  
  func findMistake() -> Int? {
    let solver = Solver(board: Board(width: board.width, height: board.height, numbers: board.numbers))
    var solveOption = SolveOption()
    // solveOption.debug = true
    solveOption.doAreaCheck = false
    let result = solver.solve(option: solveOption)
    // solver.dump(title: "SOLVED")
    guard result.reason == .solved, let loop = solver.loop else {
      return nil
    }
    let onEdges = Set<String>(loop.map({ $0.id }))
    
    for action in userActions {
      if onEdges.contains(action.edge.id) {
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
  
  private func findLastAction(on edge: Edge, from actions: [SetEdgeStatusAction]) -> Int? {
    for i in (0 ..< actions.count).reversed() {
      let action = actions[i]
      if action.edge == edge {
        return i
      }
    }
    return nil
  }
  
  func findNextAction() -> FindResult? {
    let finder = ActionFinder(board: Board(width: board.width, height: board.height, numbers: board.numbers))
    finder.option.debug = true
    finder.doInitialStep()
    if let action = finder.findAbsentAction(board: board) {
      finder.solvingContext.function = .initialize
      return FindResult(action: action, context: finder.solvingContext)
    }
    
    finder.currentStep.rewind()
    finder.doUserActions(userActions)

    if let action = finder.findAbsentAction(board: board) {
      // 小ループ1歩手前の状態は、これ以降新たなエッジがONにならない限り発生しない
      finder.solvingContext.function = .smallLoop
      let edge = action.edge
      let node = edge.nodes[0]
      let (_, loop) = finder.board.getLoopEnd(from: node, and: node.onEdge(connectTo: edge)!)
      finder.solvingContext.mainElements = loop
      return FindResult(action: action, context: finder.solvingContext)
    }
    
    do {
      try finder.findSurroundingElements()
    } catch {
      if let findException = error as? FinderException {
        return FindResult(action: findException.action, context: finder.solvingContext)
      }
    }
    
    return nil
  }
}
