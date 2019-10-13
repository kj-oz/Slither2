//
//  ActionFinder.swift
//  Slither2
//
//  Created by KO on 2019/08/10.
//  Copyright © 2019 KO. All rights reserved.
//

import Foundation

/// 次の手の探索結果
struct FindResult {
  /// エッジに対するアクション
  let action: SetEdgeStatusAction
  /// そのアクションを発見した理由等
  let context: SolvingContext
//
//  init(action: SetEdgeStatusAction, context: SolvingContext) {
//    self.action = action
//    self.context = context
//  }
}

/// アドバイス時の次の手を探し出すクラス
class ActionFinder : Solver {
  /// 次手探索時例外
  struct FinderException : Error {
    /// 次手
    let action: SetEdgeStatusAction
//
//    init(action: SetEdgeStatusAction) {
//      self.action = action
//    }
  }
  
  /// １手仮置時の結果（手数が最低の処理を見つけるために保存しておく）
  struct TryAction {
    /// 仮置のアクション
    var tryEdgeAction: SetEdgeStatusAction?
    /// 確定するまでの延長数
    var extent = Int.max
    /// 確定するまでのアクション
    var steps: [Action] = []
    /// 矛盾が発生した要素（
    var failedElement: Element?
    
    mutating func reset() {
      self = TryAction()
//      tryEdgeAction = nil
//      extent = Int.max
//      steps = []
//      failedElement = nil
    }
  }

  /// 次手が見つかるのを待っている状態かどうか
  private var watching = false
  
  /// 仮置で最小延長で確定したアクション
  private var minimumAction = TryAction()
  

//  /// 仮置で最小延長で確定したアクション
//  private var minimumAction: SetEdgeStatusAction?
//
//  /// 仮置で最小延長で確定した際の延長数
//  private var minimumExtent = Int.max
//
//  /// 仮置で最小延長で確定した際の確定するまでのアクション
//  private var minimumStep: [Action] = []
//
//  /// 仮置で最小延長で確定した際の矛盾の発生した要素
//  private var minimumFailed: Element?

  /// 解いている過程の状況
  var solvingContext: SolvingContext
  
  /// ONで仮置した際の手順
  var onActions: [Action] = []
  
  /// コンストラクタ
  ///
  /// - Parameter board: 次手検索用の盤面
  override init(board: Board) {
    solvingContext = SolvingContext(board: board)
    super.init(board: board)
  }
  
  /// 次の手を探索する
  ///
  /// - Parameter userActions: これまでのユーザの着手
  /// - Returns: 探索の結果
  func findNextAction(userActions: [SetEdgeStatusAction]) -> FindResult? {
    option.debug = true
    // 初期探索パターンの漏れのチェック
    doInitialStep()
    if let action = findAbsentAction(board: board) {
      solvingContext.function = .initialize
      return FindResult(action: action, context: solvingContext)
    }
    currentStep.rewind()
    
    // ユーザの着手のトレース
    doUserActions(userActions)
    
    // 小ループ防止のOFFエッジの見落としのチェック
    if let action = findAbsentAction(board: board) {
      // 小ループ1歩手前の状態は、これ以降新たなエッジがONにならない限り発生しない
      solvingContext.function = .smallLoop
      let edge = action.edge
      let node = edge.nodes[0]
      let (_, loop) = board.getLoopEnd(from: node, and: node.onEdge(connectTo: edge)!)
      solvingContext.mainElements = loop
      return FindResult(action: action, context: solvingContext)
    }
    
    // 次の手の探索
    do {
      try findSurroundingElements()
    } catch {
      if let findException = error as? FinderException {
        return FindResult(action: findException.action, context: solvingContext)
      }
    }
    
    return nil
  }

  /// 初期配置の処理を行う
  /// （ユーザの着手に漏れがないかを検討する）
  private func doInitialStep() {
    do {
      try initCorner()
      try initC0()
      try initC3()
      try initBorder()
    } catch {
      let exception = error as! SolveException
      if case .finished = exception {
        result.solved = true
        return
      }
      return
    }
  }
  
  /// ユーザーの着手をそのまま再現する
  private func doUserActions(_ actions: [SetEdgeStatusAction]) {
    do {
      for action in actions {
        let node = action.edge.nodes[0]
        let edge = action.edge.horizontal ?
          board.hEdgeAt(x: node.x, y: node.y) :board.vEdgeAt(x: node.x, y: node.y)
        try changeEdgeStatus(of: edge, to: action.newStatus)
      }
    } catch {
      let exception = error as! SolveException
      if case .finished = exception {
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
  private func findAbsentAction(board: Board) -> SetEdgeStatusAction? {
    for i in 0 ..< board.edges.count {
      let edge = board.edges[i]
      if edge.status == .unset {
        switch self.board.edges[i].status {
        case .on:
          return SetEdgeStatusAction(edge: self.board.edges[i], status: .on)
        case .off:
          let edge = board.edges[i]
          // onCountをチェックしないと、意味のない箇所で小ループの見落としとしてリストアップされる
          if !isEdgeObviouslyOff(edge) {
            return SetEdgeStatusAction(edge: self.board.edges[i], status: .off)
          }
        case .unset:
          break
        }
      }
    }
    return nil
  }
  
  /// そのエッジが明らかにOFFであるかどうかを調べる
  ///
  /// - Parameter edge: 対象のエッジ
  /// - Returns: 明らかにOFFならtrue
  private func isEdgeObviouslyOff(_ edge: Edge) -> Bool {
    if edge.nodes[0].onCount == 2 || edge.nodes[1].onCount == 2 {
      return true
    }
    if edge.status == .off {
      // エッジの変更watch時には、ステータスえ変更後に呼び出される
      if edge.nodes[0].offCount == 4 || edge.nodes[1].offCount == 4 {
        return true
      }
    } else {
      if edge.nodes[0].offCount >= 3 || edge.nodes[1].offCount >= 3 {
        return true
      }
    }
    if edge.cells[0].onCount == edge.cells[0].number ||
        edge.cells[1].onCount == edge.cells[1].number {
      return true
    }
    if edge.nodes[0].oppositeNode == edge.nodes[1] {
      var ed = edge
      var nd = edge.nodes[0]
      var count = 0
      while nd != edge.nodes[1] && count < 4 {
        ed = nd.onEdge(connectTo: ed)!
        nd = ed.anotherNode(of: nd)
        count += 1
      }
      if count == 3 {
        return true
      }
    }
    return false
  }
  
  /// これまでの打ち手による盤面の状況から、次の着手を探し出す
  ///
  /// - Throws: 着手探索例外（打ち手が見つかったら例外が発生する
  private func findSurroundingElements() throws {
    watching = true
    defer {
      watching = false
    }
    
    // 単純なセル、ノードのエッジの状態のチェック
    while true {
      if currentStep.changedEdges.count > 0 {
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
      else if currentStep.gateCheckCells.count > 0 {
        let cell = currentStep.gateCheckCells.popFirst()!
        try checkGate(of: cell)
      }
      
      // セル色のチェック
      else if currentStep.colorCheckCells.count > 0 {
        let cell = currentStep.colorCheckCells.popFirst()!
        try checkColor(of: cell)
      }
      
      else {
        break;
      }
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
    try super.changeEdgeStatus(of: edge, to: status)
    if watching && !trying {
      if status == .on || !isEdgeObviouslyOff(edge) {
        throw FinderException(action: SetEdgeStatusAction(edge: edge, status: status))
      }
    }
  }
  
  // 試しに1ステップだけ未設定のEdgeをOnまたはOffに設定して、エラーになればその逆の状態に確定させる.
  override func tryOneStep() throws -> Bool {
    startNewStep(useCache: false)
    minimumAction.reset()
//    minimumExtent = Int.max
//    minimumStep = currentStep.actions
    for edge in board.edges {
      if edge.status == .unset {
        tryOnEdges = [:]
        if try !tryEdge(edge, to: .on) {
          let _ = try tryEdge(edge, to: .off)
        }
      }
    }
    backToPreviousStep()
    if let action = minimumAction.tryEdgeAction {
      solvingContext.relatedElements = minimumAction.steps
      if let failed = minimumAction.failedElement {
        // 失敗に終わった結果の確定
        solvingContext.function = .tryFail
        solvingContext.mainElements = [failed]
        try changeEdgeStatus(of: action.edge, to: action.newStatus)
      } else {
        // 同じ状態に変更されるエッジ
        solvingContext.function = .trySameResult
        solvingContext.mainElements = [action.edge]
        let sameAction = minimumAction.steps.last! as! SetEdgeStatusAction
        try changeEdgeStatus(of: sameAction.edge, to: sameAction.newStatus)
      }
    }
    return false
  }
  
  // 与えられたEdgeを指定の状態に設定して解を求め、エラーになった場合は逆の状態に確定する
  override func tryEdge(_ edge: Edge, to status: EdgeStatus) throws -> Bool {
    
    do {
      startTrying(status: status)
      try changeEdgeStatus(of: edge, to: status)
      try checkSurroundingElements(trying: true)
    } catch {
      let exception = error as! SolveException
      switch exception {
      case .failed(reason: let reason):
        if tryingChainCount < minimumAction.extent {
          minimumAction.extent = tryingChainCount
          minimumAction.tryEdgeAction = SetEdgeStatusAction(edge: edge, status: status.otherStatus())
          minimumAction.steps = currentStep.actions
          minimumAction.failedElement = reason
        }
//        if tryingChainCount < minimumExtent {
//          minimumExtent = tryingChainCount
//          minimumAction = SetEdgeStatusAction(edge: edge, status: status.otherStatus())
//          minimumStep = currentStep.actions
//          minimumFailed = reason
//        }
        currentStep.rewind(addCache: false)
        endTrying()
        return true
      case .sameAction(action: let action):
        // on時の、同じアクションまでのアクションの配列と延長エッジ数を得る
        var actions: [Action] = []
        var onChainCount = 0
        for onAction in onActions {
          actions.append(onAction)
          if let seAction = onAction as? SetEdgeStatusAction {
            if seAction.newStatus == .on {
              onChainCount += 1
            }
            if seAction.edge == action.edge {
              break
            }
          }
        }
        
        // on/offいずれか大きい方の手数で判定
        let chainCount = tryingChainCount + onChainCount
        
        if chainCount < minimumAction.extent {
          minimumAction.extent = chainCount
          minimumAction.tryEdgeAction = SetEdgeStatusAction(edge: edge, status: .on)
          // stepにはOon/off両方のアクションを連続して保存
          minimumAction.steps = []
          minimumAction.steps.append(contentsOf: actions)
          minimumAction.steps.append(contentsOf: currentStep.actions)
          minimumAction.steps.append(action)
          // sameResultの場合、failedをnilに
          minimumAction.failedElement = nil
        }
//        if chainCount < minimumExtent {
//          minimumExtent = chainCount
//          minimumAction = SetEdgeStatusAction(edge: edge, status: .on)
//          // stepにはOon/off両方のアクションを連続して保存
//          minimumStep = []
//          minimumStep.append(contentsOf: actions)
//          minimumStep.append(contentsOf: currentStep.actions)
//          minimumStep.append(action)
//          // sameResultの場合、failedをnilに
//          minimumFailed = nil
//        }
        currentStep.rewind(addCache: false)
        endTrying()
        return true
      default:
        // .finished はここでは無視する
        break
      }
    }
    if status == .on {
      onActions = currentStep.actions
      var chainCount = 0
      for action in currentStep.actions {
        if let setEdgeAction = action as? SetEdgeStatusAction {
          if setEdgeAction.newStatus == .on {
            chainCount += 1
          }
          tryOnEdges[setEdgeAction.edge] = TryChainStatus(
            status: setEdgeAction.newStatus, extentCount: chainCount)
        }
      }
    }
    currentStep.rewind(addCache: false)
    endTrying()
    return false
  }
  
  // 与えられた状態がOnに変化したEdgeの与えられた方向のNodeをチェックする
  override func checkNodeOfOnEdge(edge: Edge, pos: Int) throws {
    solvingContext.function = .checkNode
    solvingContext.mainElements = [edge.nodes[pos]]
    try super.checkNodeOfOnEdge(edge: edge, pos: pos)
  }
  
  // 与えられた状態がOnに変化したEdgeの与えられた方向のCellをチェックする
  override func checkCellOfOnEdge(edge: Edge, pos: Int) throws {
    solvingContext.function = .checkCell
    solvingContext.mainElements = [edge.cells[pos]]
    try super.checkCellOfOnEdge(edge: edge, pos: pos)
  }
  
  // 与えられた状態がOffに変化したEdgeの与えられた方向のNodeをチェックする
  override func checkNodeOfOffEdge(edge: Edge, pos: Int) throws {
    solvingContext.function = .checkNode
    solvingContext.mainElements = [edge.nodes[pos]]
    try super.checkNodeOfOffEdge(edge: edge, pos: pos)
  }
  
  // 与えられた状態がOffに変化したEdgeの与えられた方向のCellをチェックする
  override func checkCellOfOffEdge(edge: Edge, pos: Int) throws {
    solvingContext.function = .checkCell
    solvingContext.mainElements = [edge.cells[pos]]
    try super.checkCellOfOffEdge(edge: edge, pos: pos)
  }
  
  // 状態が変化したエッジに接していたセルの色をチェックする
  override func checkColor(of cell: Cell) throws {
    solvingContext.function = .checkColor
    solvingContext.mainElements = [cell]
    try super.checkColor(of: cell)
  }
  
  // 与えられたCellの四隅の斜めに接するCellとの関係のチェックを行う
  override func checkGate(of cell: Cell) throws {
    solvingContext.function = .checkGate
    switch cell.number {
    case 1:
      for h in [0, 1] {
        for v in [0, 1] {
          let node = cell.hEdges[v].nodes[h]
          solvingContext.mainElements = [cell, node]
          try checkGateC1(cell: cell, h: h, v: v)
        }
      }
      
    case 2:
      for h in [0, 1] {
        for v in [0, 1] {
          let node = cell.hEdges[v].nodes[h]
          solvingContext.mainElements = [cell, node]
          try checkGateC2(cell: cell, h: h, v: v)
        }
      }
      
    case 3:
      for h in [0, 1] {
        for v in [0, 1] {
          let node = cell.hEdges[v].nodes[h]
          solvingContext.mainElements = [cell, node]
          try checkGateC3(cell: cell, h: h, v: v)
        }
      }
      
    default:
      return
    }
  }
  
  // 領域に接するループの末端の数をチェックする
  override func checkArea() throws -> Bool {
    let ac = AreaCheckerAF(finder: self)
    let stat = try ac.check()
    return stat
  }
}

/// 何らかの手が見つかった場合に、FinderExceptionを投げるよう改良した領域チェッククラス
class AreaCheckerAF : AreaChecker {
  /// ファインダを引数にチェッカーを生成する
  ///
  /// - Parameter finder: ファインダ
  init(finder: ActionFinder) {
    super.init(solver: finder)
  }

  // ゲート部の（エッジの）ステータスを変更する
  override func changeGateStatus(of gate: Point, from area: Area, to status: EdgeStatus) throws -> Bool {
    let af = solver as! ActionFinder
    af.solvingContext.function = .checkArea
    af.solvingContext.mainElements = [gate.node]
    var nodes: [Node] = []
    for y in 0 ..< height {
      for x in 0 ..< width {
        let point = points[y][x]
        if point.areas.count > 0 && point.areas[0] == area && (point.type == .space || point.type == .gate) {
          nodes.append(point.node)
        }
      }
    }
    af.solvingContext.relatedElements = nodes
    return try super.changeGateStatus(of: gate, from: area, to: status)
  }
}
