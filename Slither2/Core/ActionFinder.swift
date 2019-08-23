//
//  ActionFinder.swift
//  Slither2
//
//  Created by KO on 2019/08/10.
//  Copyright © 2019 KO. All rights reserved.
//

import Foundation

/// 次手探索時例外
class FinderException : Error {
}

/// アドバイス時の次の手を探し出すクラス
class ActionFinder : Solver {
  /// 次手が見つかるのを待っている状態かどうか
  private var watching = false
  
  private var minimumAction: SetEdgeStatusAction?
  
  private var minimumExtent = Int.max
  
  private var minimumStep: [Action] = []

  var solvingContext = SolvingContext()
  
  /// 初期配置の処理を行う
  /// （ユーザの着手に漏れがないかを検討する）
  func doInitialStep() {
    do {
      try initCorner()
      try initC0()
      try initC3()
      try initBorder()
    } catch {
      let exception = error as! SolveException
      if exception.reason == .finished {
        result.solved = true
        return
      }
      return
    }
  }
  
  /// ユーザーの着手をそのまま再現する
  func doUserActions(_ actions: [SetEdgeStatusAction]) {
    do {
      for action in actions {
        try changeEdgeStatus(of: action.edge, to: action.newStatus)
      }
    } catch {
      let exception = error as! SolveException
      if exception.reason == .finished {
        result.solved = true
        return
      }
      return
    }
  }
  
  /// ユーザーの着手と現状の算出状況を比較して、ユーザー着手側に漏れが無いかを調べる
  ///
  /// - Parameter board: ユーザーの着手盤面
  /// - Returns: ユーザーの着手盤面から漏れているアクション
  func findAbsentAction(board: Board) -> SetEdgeStatusAction? {
    for i in 0 ..< board.edges.count {
      if self.board.edges[i].status != .unset &&
          board.edges[i].status == .unset {
        let edge = board.edges[i]
        if (edge.nodes[0].onCount + edge.nodes[0].offCount < 3) ||
            (edge.nodes[1].onCount + edge.nodes[1].offCount < 3) {
          return SetEdgeStatusAction(edge: board.edges[i], status: self.board.edges[i].status)
        }
      }
    }
    return nil
  }
  
  /// これまでの打ち手による盤面の状況から、次の着手を探し出す
  ///
  /// - Throws: 着手探索例外（打ち手が見つかったら例外が発生する
  func findSurroundingElements() throws {
    watching = true
    defer {
      watching = false
    }
    
    // 単純なセル、ノードのエッジの状態のチェック
    while currentStep.changedEdges.count > 0 {
      let edge = currentStep.changedEdges.remove(at: 0)
      
      switch edge.status {
      case .on:
        try checkNodeOfOnEdge(edge: edge, pos: 0)
        try checkNodeOfOnEdge(edge: edge, pos: 1)
        
        try checkCellOfOnEdge(edge: edge, pos: 0)
        try checkCellOfOnEdge(edge: edge, pos: 1)
      case .off:
        try checkNodeOfOffEdge(edge: edge, pos: 0)
        try checkNodeOfOffEdge(edge: edge, pos: 1)
        
        try checkCellOfOffEdge(edge: edge, pos: 0)
        try checkCellOfOffEdge(edge: edge, pos: 1)
      default:
        break
      }
      
      currentStep.gateCheckCells.insert(edge.cells[0])
      currentStep.gateCheckCells.insert(edge.cells[1])
      currentStep.gateCheckCells.insert(edge.straightEdges[0].cells[0])
      currentStep.gateCheckCells.insert(edge.straightEdges[0].cells[1])
      currentStep.gateCheckCells.insert(edge.straightEdges[1].cells[0])
      currentStep.gateCheckCells.insert(edge.straightEdges[1].cells[1])
      
      currentStep.colorCheckCells.insert(edge.cells[0])
      currentStep.colorCheckCells.insert(edge.cells[1])
    }
    
    // 斜ゲートのチェック
    while currentStep.gateCheckCells.count > 0 {
      let cell = currentStep.gateCheckCells.popFirst()!
      try checkGate(of: cell)
    }
    
    // セル色のチェック
    while currentStep.colorCheckCells.count > 0 {
      let cell = currentStep.colorCheckCells.popFirst()!
      try checkColor(of: cell)
    }
    
    // 1手仮置を最大延長を10に制限して実施
    option.tryOneStepMaxExtent = 10
    let _ = try tryOneStep()
    
    // 領域チェックの実施
    let _ = try checkArea()
    
    // 1手仮置を最大延長を無制限（100）にして実施
    option.tryOneStepMaxExtent = 100
    let _ = try tryOneStep()
  }
  
  // エッジの状態変更時
  // 次手が見つかるのを待っている状態でこのメソッドが呼ばれたら、次手探索時例外を投げる
  override func changeEdgeStatus(of edge: Edge, to status: EdgeStatus) throws {
    if edge.status == status {
      return
    }
    if watching && !trying {
      throw FinderException()
    }
    try super.changeEdgeStatus(of: edge, to: status)
  }
  
  /// 試しに1ステップだけ未設定のEdgeをOnまたはOffに設定して、エラーになればその逆の状態に確定させる.
  ///
  /// - Returns: 新たな辺が確定したか
  /// - Throws: 解の探索時例外
  override func tryOneStep() throws -> Bool {
    startNewStep(useCache: false)
    minimumAction = nil
    minimumExtent = Int.max
    minimumStep = currentStep.actions
    for edge in board.edges {
      if edge.status == .unset {
        if try !tryEdge(edge, to: .on) {
          let _ = try tryEdge(edge, to: .off)
        }
      }
    }
    backToPreviousStep()
    if let action = minimumAction {
      try changeEdgeStatus(of: action.edge, to: action.newStatus)
    }
    return false
  }
  
  /// 与えられたEdgeを指定の状態に設定して解を求め、エラーになった場合は逆の状態に確定する
  ///
  /// - Parameters:
  ///   - edge: 対象のEdge
  ///   - status: 状態
  /// - Returns: 指定のEdgeの状態が確定したかどうか
  /// - Throws: 解の探索時例外
  override func tryEdge(_ edge: Edge, to status: EdgeStatus) throws -> Bool {
    
    do {
      startTrying()
      try changeEdgeStatus(of: edge, to: status)
      try checkSurroundingElements(trying: true)
    } catch {
      let exception = error as! SolveException
      if exception.reason == .finished || exception.reason == .cacheHit {
        // ここでは無視する
      } else if exception.reason == .failed {
        if tryingChainCont < minimumExtent {
          minimumExtent = tryingChainCont
          minimumAction = SetEdgeStatusAction(edge: edge, status: status.otherStatus())
          minimumStep = currentStep.actions
        }
        currentStep.rewind(addCache: false)
        endTrying()
        return true
      }
    }
    currentStep.rewind(addCache: false)
    endTrying()
    return false
  }
  
  override func checkNodeOfOnEdge(edge: Edge, pos: Int) throws {
    solvingContext.function = .checkNode
    solvingContext.mainElements = [edge.nodes[pos]]
    try super.checkNodeOfOnEdge(edge: edge, pos: pos)
  }
  
  /// 与えられた状態がOnに変化したEdgeの与えられた方向のCellをチェックする
  ///
  /// - Parameters:
  ///   - edge: 状態がOnに変化したEdge
  ///   - pos: 左右(0:indexが小さな側、1:indexが大きな側）
  /// - Throws: 解の探索時例外
  override func checkCellOfOnEdge(edge: Edge, pos: Int) throws {
    solvingContext.function = .checkCell
    solvingContext.mainElements = [edge.cells[pos]]
    try super.checkCellOfOnEdge(edge: edge, pos: pos)
  }
  
  /// 与えられた状態がOffに変化したEdgeの与えられた方向のNodeをチェックする
  ///
  /// - Parameters:
  ///   - edge: 状態がOffに変化したEdge
  ///   - pos: 前後(0:indexが小さな側、1:indexが大きな側）
  /// - Throws: 解の探索時例外
  override func checkNodeOfOffEdge(edge: Edge, pos: Int) throws {
    solvingContext.function = .checkNode
    solvingContext.mainElements = [edge.nodes[pos]]
    try super.checkNodeOfOffEdge(edge: edge, pos: pos)
  }
  
  /// 与えられた状態がOffに変化したEdgeの与えられた方向のCellをチェックする
  ///
  /// - Parameters:
  ///   - edge: 状態がOffに変化したEdge
  ///   - pos: 左右(0:indexが小さな側、1:indexが大きな側）
  /// - Throws: 解の探索時例外
  override func checkCellOfOffEdge(edge: Edge, pos: Int) throws {
    solvingContext.function = .checkCell
    solvingContext.mainElements = [edge.cells[pos]]
    try super.checkCellOfOffEdge(edge: edge, pos: pos)
  }
  
  /// 状態が変化したエッジに接していたセルの色をチェックする
  ///
  /// - Parameter cell: 対象のセル
  /// - Throws: 解の探索時例外
  override func checkColor(of cell: Cell) throws {
    solvingContext.function = .checkColor
    solvingContext.mainElements = [cell]
    try super.checkColor(of: cell)
  }
  
  override func checkGate(of cell: Cell) throws {
    solvingContext.function = .checkGate
    solvingContext.mainElements = [cell]
    try super.checkGate(of: cell)
  }
  
  /// 領域に接するループの末端の数をチェックする
  ///
  /// - Returns: 領域チェックの結果、エッジ、ゲートの状態に変更があったか
  /// - Throws: 解の探索時例外
  override func checkArea() throws -> Bool {
    let ac = AreaCheckerAF(finder: self)
    let stat = try ac.check()
    return stat
  }
}

class AreaCheckerAF : AreaChecker {
  /// ソルバを引数にチェッカーを生成する
  ///
  /// - Parameter solver: ソルバ
  init(finder: ActionFinder) {
    super.init(solver: finder)
  }

  /// ゲート部の（エッジの）ステータスを変更する
  ///
  /// - Parameters:
  ///   - gate: ゲート
  ///   - area: エリア
  ///   - status: ステータス
  /// - Throws: 解の探索時例外
  override func changeGateStatus(of gate: Point, from area: Area, to status: EdgeStatus) throws -> Bool {
    let af = solver as! ActionFinder
    af.solvingContext.function = .checkArea
    af.solvingContext.mainElements = [gate.node]
    return try super.changeGateStatus(of: gate, from: area, to: status)
  }
}
