//
//  Solver.swift
//  Slither
//
//  Created by KO on 2018/09/22.
//  Copyright © 2018年 KO. All rights reserved.
//

import Foundation

/// 解の探索を行うクラス
class Solver {
  /// 正解のループ
  var loop: [Edge]?
  
  /// 盤面データ
  let board: Board
  
  /// ブランチの再帰呼び出し時の全ステップを保持している配列
  var steps: [Step] = []
  
  /// 現在のステップ
  var currentStep = Step()
  
//  /// 得られたルートの配列
//  var loops: [[Edge]] = []
  
  /// 解を求める際の設定
  var option: SolveOption = SolveOption()
  
  /// 解を求める際の締切
  var timelimit = Date().addingTimeInterval(3600.0)
  
  /// 処理に要した時間
  var elapsed = 0.0
  
  /// ブランチの再帰呼び出し時の最大レベル
  var maxLevel = 0
  
  /// エリアチェックで有効な手が見つかったかどうか
  var useAreaCheckResult = false
  
  /// 1ステップトライ時の次のエッジのインデックス
  private var nextTryEdgeIndex = 0
  
  /// 与えられた盤面で初期化する
  ///
  /// - Parameter board: 盤面
  init(board: Board) {
    self.board = board
  }
  
  /// 与えられた文字列の状態で初期化する
  ///
  /// - Parameter lines: 問題とエッジの状態の文字列
  init(lines: [String]) throws {
    let lineCount = lines.count
    let sizes = lines[0].components(separatedBy: .whitespaces)
    let width = Int(sizes[0])!
    let height = Int(sizes[1])!
    var numbers: [Int] = []
    
    for i in 1 ..< lineCount {
      if !lines[i].starts(with: "+") {
        let line = lines[i]
        var edge = true
        for char in line {
          if !edge {
            numbers.append(char == " " ? -1 : Int(String(char))!)
          }
          edge = !edge
        }
      }
    }
    
    board = Board(width: width, height: height, numbers: numbers)
    var y = 0
    for i in 1 ..< lineCount {
      let line = lines[i]
      if line.starts(with: "+") {
        var x = 0
        var edge = false
        for char in line {
          if edge {
            let status = board.hEdgeStatus(of: char)
            if status != .unset {
              try changeEdgeStatus(of: board.hEdgeAt(x: x, y: y), to: status)
            }
            x += 1
          }
          edge = !edge
        }
      } else {
        var x = 0
        var edge = true
        for char in line {
          if edge {
            let status = board.vEdgeStatus(of: char)
            if status != .unset {
              try changeEdgeStatus(of: board.vEdgeAt(x: x, y: y), to: status)
            }
            x += 1
          }
          edge = !edge
        }
        y += 1
      }
    }
  }
  
  /// 問題の解を探索する
  ///
  /// - Parameter option: 解探索のオプション
  /// - Returns: 問題が正常に解けたかどうか
  func solve(option: SolveOption) -> Bool {
    let startTime = Date()
    useAreaCheckResult = false
    timelimit = startTime.addingTimeInterval(option.elapsedSec)
    self.option = option
    do {
      try initCorner()
      try initC0()
      try initC3()
      try initBorder()
      try checkSurroundingElements(trying: false)
    } catch {
      //dump(title: "★ catch with init")
      elapsed = Date().timeIntervalSince(startTime)
      let exception = error as! SolveException
      if exception.reason == .finished {
        return true
      }
      return false
    }
    //dump(title: "★ after init")
    if option.maxGuessLevel == 0 {
      elapsed = Date().timeIntervalSince(startTime)
      return false
    }
    
    // ロジカルには解けず、深さ優先で枝を探索
    var branches = BranchBuffer()
    let root = board.findOpenNode()
    if let root = root {
      branches = createBranches(from: root)
    } else {
      if let cell = board.findCellForBranch() {
        branches = createBranches(from: cell)
      }
    }
    
    if branches.count > 0 {
      tryBranches(branches)
    }
    elapsed = Date().timeIntervalSince(startTime)
    return true
  }
  
  /// 試しに1ステップだけ未設定のEdgeをOnまたはOffに設定して、エラーになればその逆の状態に確定させる.
  ///
  /// - Returns: 新たな辺が確定したか
  /// - Throws: 解の探索時例外
  private func tryOneStep() throws -> Bool {
    startNewStep(useCache: option.useCache)
    // shuffleとの比較の結果はほぼ同等
    // 同じ順番よりは、特に長い時間がかかる場合に有利
    let startIndex = nextTryEdgeIndex
    repeat {
      let edge = board.edges[nextTryEdgeIndex]
      nextTryEdgeIndex += 1
      if nextTryEdgeIndex == board.edges.count {
        nextTryEdgeIndex = 0
      }
      if edge.status == .unset {
        if try tryEdge(edge, to: .on) || tryEdge(edge, to: .off) {
          //print("★ Try One Step: true")
          return true
        }
      }
    } while nextTryEdgeIndex != startIndex
    backToPreviousStep()
    //print("★ Try One Step: false")
    return false
  }
  
  /// 与えられたEdgeを指定の状態に設定して解を求め、エラーになった場合は逆の状態に確定する
  ///
  /// - Parameters:
  ///   - edge: 対象のEdge
  ///   - status: 状態
  /// - Returns: 指定のEdgeの状態が確定したかどうか
  /// - Throws: 解の探索時例外
  private func tryEdge(_ edge: Edge, to status: EdgeStatus) throws -> Bool {

    do {
      try changeEdgeStatus(of: edge, to: status)
      try checkSurroundingElements(trying: true)
    } catch {
      let exception = error as! SolveException
      if exception.reason == .finished || exception.reason == .cacheHit {
        // ここでは無視する
      } else if exception.reason == .failed {
        backToPreviousStep()
        try changeEdgeStatus(of: edge, to: status.otherStatus())
        return true
      }
    }
    currentStep.rewind(addCache: true)
    return false
  }
  
  /// 与えられたNodeから発生する分岐の配列を得る
  ///
  /// - Parameter node: 分岐の起点
  /// - Returns: 分岐の枝の配列
  private func createBranches(from node: Node) -> BranchBuffer {
    let branches = BranchBuffer()
    if node.vEdges[0].status == .unset {
      branches.add(Branch(root: node, edge: node.vEdges[0]))
    }
    if node.hEdges[0].status == .unset {
      branches.add(Branch(root: node, edge: node.hEdges[0]))
    }
    if node.vEdges[1].status == .unset {
      branches.add(Branch(root: node, edge: node.vEdges[1]))
    }
    if node.hEdges[1].status == .unset {
      branches.add(Branch(root: node, edge: node.hEdges[1]))
    }
    return branches;
  }

  /// 与えられたCellの周囲から発生する分岐の配列を得る
  ///
  /// - Parameter cell: 与えられたCeeの周囲から発生する分岐の配列を得る
  /// - Returns: 分岐の配列
  private func createBranches(from cell: Cell) -> BranchBuffer {
    let branches = BranchBuffer()
    if cell.hEdges[0].status == .unset {
      branches.add(Branch(root: cell.hEdges[0].nodes[0], edge: cell.hEdges[0]))
    }
    if cell.vEdges[0].status == .unset {
      branches.add(Branch(root: cell.vEdges[0].nodes[0], edge: cell.vEdges[0]))
    }
    if cell.hEdges[1].status == .unset {
      branches.add(Branch(root: cell.hEdges[1].nodes[0], edge: cell.hEdges[1]))
    }
    if cell.vEdges[1].status == .unset {
      branches.add(Branch(root: cell.vEdges[1].nodes[0], edge: cell.vEdges[1]))
    }
    return branches;
  }
  
  /// 与えられた分岐のリストを順番にOnにして試す
  /// 分岐の枝の状態を変えてもルートが確定しなかった場合、その先の末端で再起的に処理を行う
  /// 効率化のため実際には再起呼び出しは行わずループで処理する
  ///
  /// - Parameter branches: 分岐の枝の配列
  private func tryBranches(_ branches: BranchBuffer) {
    var branchStack: [BranchBuffer] = [branches]
    var level = 1
    maxLevel = 1
    while level > 0 {
      //print("★ level=\(level) steps=\(steps.count) branchStatck=\(branchStack.count)")
      if steps.count == level - 1 {
        // 新しいステップの開始
        startNewStep()
      } else {
        // 深い部分の探索から戻ってきた状態
        currentStep.rewind()
      }
      let branches = branchStack.last!
      var addDepth = false
      while branches.count > 0 {
        let branch = branches.remove()
        //debug("☆ branch=\(branch.root.id)->\(branch.edge.id)")
        do {
          try changeEdgeStatus(of: branch.edge, to: .on)
          try checkSurroundingElements(trying: false)
        } catch {
          let exception = error as! SolveException
          if exception.reason == .finished {
            if loop != nil {
              return
            }
            loop = board.loop
          } else if exception.reason == .timeover {
            loop = nil
            return
          }
          currentStep.rewind()
          continue;
        }
        if level == option.maxGuessLevel {
          loop = nil
          return
        }
        let newRoot = board.getLoopEnd(from: branch.root, and: branch.edge)
        let newBranches = createBranches(from: newRoot!)
        branchStack.append(newBranches)
        level += 1
        if level > maxLevel {
          maxLevel = level
        }
        addDepth = true
        break
      }
      if !addDepth {
        backToPreviousStep()
        branchStack.removeLast()
        level -= 1
      }
    }
  }
  
  /// 新しいステップを開始する準備を行う
  ///
  /// - Parameter useCache: キャッシュを使用するかどうか
  private func startNewStep(useCache: Bool = false) {
    currentStep = Step(useCache: useCache)
    steps.append(currentStep)
  }
  
  /// 現在のステップを削除し、一つ前のステップをカレントにする
  private func backToPreviousStep() {
    currentStep.rewind()
    steps.removeLast()
    currentStep = steps.last ?? Step()
  }

  /// Edgeの状態を与えられた状態に変更する
  /// 周辺のNodeやCellの状態から、許容されない状態へ変更した場合には例外が発生する
  /// 変更の結果ループが発生した場合には、そのループの状態に応じた例外を発生させる
  /// また自分が所属する連続線の末端同士が隣り合う状態になった場合には、その辺を閉じることで
  /// 出来るループをチェックし、小ループが出来る場合にはその辺の状態をOffに変更する
  ///
  /// - Parameters:
  ///   - edge: 対象のEdge
  ///   - status: 新しい状態
  /// - Throws: 解の探索時例外
  func changeEdgeStatus(of edge: Edge, to status: EdgeStatus) throws {
    if Date().compare(timelimit) == .orderedDescending {
      throw SolveException(reason: .timeover)
    }
    if edge.status == status {
      return
    }
    
    if edge.status != .unset {
      //debug(">>> cannot set to \(status): \(edge.id) is \(edge.status)")
      throw SolveException(reason: .failed)
    }
    
    currentStep.add(action: SetEdgeStatusAction(edge: edge, status: status))
    currentStep.changedEdges.append(edge)
    if currentStep.useCache && currentStep.hasCache(edge: edge) {
//      print("☆ Cache Hit!")
      throw SolveException(reason: .cacheHit)
    }
    
    if status == .on {
      // 連続線の端部の更新
      let head = edge.nodes[0].oppositeNode ?? edge.nodes[0]
      let tail = edge.nodes[1].oppositeNode ?? edge.nodes[1]
      
      if head === edge.nodes[1] {
        // 既に1つ手前でチェック済みのため board.getLoopStatus は行わない
        throw SolveException(reason: .finished)
      } else {
        currentStep.add(action: SetOppositeNodeAction(node: head, oppositeNode: tail))
        currentStep.add(action: SetOppositeNodeAction(node: tail, oppositeNode: head))
      
        let jointEdge = board.getJointEdge(of: head, and: tail)
        if let jointEdge = jointEdge, jointEdge.status == .unset {
          // headとtailが隣り合っている場合
          jointEdge.status = .on
          let status = board.getLoopStatus(including: edge)
          jointEdge.status = .unset
          if status == .finished {
            // このノードでの分岐の処理が行われなくなってしまうため、正式な手続きで完成するまで待つ
          } else {
            try changeEdgeStatus(of: jointEdge, to: .off)
          }
        }
      }
    }
  }
  
  /// 状態を変更されたEdgeに対してその前後のNode、左右のCellに対して直接の影響をチェックする
  /// 更に左右のCellを色チェックの対象として、斜め前方、左右、斜め後方のCellをコーナーチェックの
  /// 対象として登録する
  /// 全Edgeの周辺チェック終了後、まず登録されたCellの色のチェックを行い、何も無ければ
  /// 登録されたCellのコーナーチェックを行う、それでも何もなければ、１ステップだけ験すチェック、
  /// 次にエリアのチェックを行う、その結果いずれかのEdgeやCellの状態が変更されると、
  /// Edge周辺のチェックから繰り返す
  ///
  /// - Throws: 解の探索時例外
  private func checkSurroundingElements(trying: Bool) throws {
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
        
        if option.doColorCheck {
          currentStep.colorCheckCells.insert(edge.cells[0])
          currentStep.colorCheckCells.insert(edge.cells[1])
        }
        
        if option.doGateCheck {
          currentStep.gateCheckCells.insert(edge.cells[0])
          currentStep.gateCheckCells.insert(edge.cells[1])
          currentStep.gateCheckCells.insert(edge.straightEdges[0].cells[0])
          currentStep.gateCheckCells.insert(edge.straightEdges[0].cells[1])
          currentStep.gateCheckCells.insert(edge.straightEdges[1].cells[0])
          currentStep.gateCheckCells.insert(edge.straightEdges[1].cells[1])
        }
      } else if currentStep.colorCheckCells.count > 0 {
        let cell = currentStep.colorCheckCells.popFirst()!
        try checkColor(of: cell)
      } else if currentStep.gateCheckCells.count > 0 {
        let cell = currentStep.gateCheckCells.popFirst()!
        try checkGate(of: cell)
      } else if trying {
        break
      } else {
        if option.doTryOneStep {
          if try tryOneStep() {
            continue
          }
        }
        if option.doAreaCheck {
          if try checkArea() {
            useAreaCheckResult = true
            continue
          }
        }
        break
      }
    }
  }

  /// 与えられた状態がOnに変化したEdgeの与えられた方向のNodeをチェックする
  ///
  /// - Parameters:
  ///   - edge: 状態がOnに変化したEdge
  ///   - pos: 前後(0:indexが小さな側、1:indexが大きな側）
  /// - Throws: 解の探索時例外
  private func checkNodeOfOnEdge(edge: Edge, pos: Int) throws {
    let node = edge.nodes[pos]
    
    // ノードのOnの辺数が2になったら残りはOff
    if node.onCount == 2 {
      if node.vEdges[0].status == .unset {
        try changeEdgeStatus(of: node.vEdges[0], to: .off)
      }
      if node.hEdges[0].status == .unset {
        try changeEdgeStatus(of: node.hEdges[0], to: .off)
      }
      if node.vEdges[1].status == .unset {
        try changeEdgeStatus(of: node.vEdges[1], to: .off)
      }
      if node.hEdges[1].status == .unset {
        try changeEdgeStatus(of: node.hEdges[1], to: .off)
      }
    }
    
    // ノードのOffの辺数が2(Onは1)になったら残りはOn
    else if node.offCount == 2 {
      if node.vEdges[0].status == .unset {
        try changeEdgeStatus(of: node.vEdges[0], to: .on)
      } else if node.hEdges[0].status == .unset {
        try changeEdgeStatus(of: node.hEdges[0], to: .on)
      } else if node.vEdges[1].status == .unset {
        try changeEdgeStatus(of: node.vEdges[1], to: .on)
      } else if node.hEdges[1].status == .unset {
        try changeEdgeStatus(of: node.hEdges[1], to: .on)
      }
    }
  }
  
  /// 与えられた状態がOnに変化したEdgeの与えられた方向のCellをチェックする
  ///
  /// - Parameters:
  ///   - edge: 状態がOnに変化したEdge
  ///   - pos: 左右(0:indexが小さな側、1:indexが大きな側）
  /// - Throws: 解の探索時例外
  private func checkCellOfOnEdge(edge: Edge, pos: Int) throws {
    let cell = edge.cells[pos]
    
    // セルのOnの辺数がナンバーと一致したら残りはOff
    if cell.onCount == cell.number {
      if cell.hEdges[0].status == .unset {
        try changeEdgeStatus(of: cell.hEdges[0], to: .off)
      }
      if cell.vEdges[0].status == .unset {
        try changeEdgeStatus(of: cell.vEdges[0], to: .off)
      }
      if cell.hEdges[1].status == .unset {
        try changeEdgeStatus(of: cell.hEdges[1], to: .off)
      }
      if cell.vEdges[1].status == .unset {
        try changeEdgeStatus(of: cell.vEdges[1], to: .off)
      }
    }
  }
  
  /// 与えられた状態がOffに変化したEdgeの与えられた方向のNodeをチェックする
  ///
  /// - Parameters:
  ///   - edge: 状態がOffに変化したEdge
  ///   - pos: 前後(0:indexが小さな側、1:indexが大きな側）
  /// - Throws: 解の探索時例外
  private func checkNodeOfOffEdge(edge: Edge, pos: Int) throws {
    let node = edge.nodes[pos]
    
    // ノードのOffの辺数が3になったら残りもOff
    if node.offCount == 3 {
      if node.vEdges[0].status != .off {
        try changeEdgeStatus(of: node.vEdges[0], to: .off)
      } else if node.hEdges[0].status != .off {
        try changeEdgeStatus(of: node.hEdges[0], to: .off)
      } else if node.vEdges[1].status != .off {
        try changeEdgeStatus(of: node.vEdges[1], to: .off)
      } else if node.hEdges[1].status != .off {
        try changeEdgeStatus(of: node.hEdges[1], to: .off)
      }
    }
    
    // ノードのOnの辺数が1でOffの辺数が2になったら残りはOn
    else if node.offCount == 2 && node.onCount == 1 {
      if node.vEdges[0].status == .unset {
        try changeEdgeStatus(of: node.vEdges[0], to: .on)
      } else if node.hEdges[0].status == .unset {
        try changeEdgeStatus(of: node.hEdges[0], to: .on)
      } else if node.vEdges[1].status == .unset {
        try changeEdgeStatus(of: node.vEdges[1], to: .on)
      } else if node.hEdges[1].status == .unset {
        try changeEdgeStatus(of: node.hEdges[1], to: .on)
      }
    }
    
    // 斜め前(後)方の２つのセルの組み合せ
    let straight = edge.straightEdges[pos]
    let cell0 = straight.cells[0]
    let cell1 = straight.cells[1]
    var onEdge = edge
    var offEdge = edge
    var offvEdge = edge
    let opos = 1 - pos
    if cell0.number == 1 && cell1.number == 1 {
      // 両方が1なら間のEdgeはOff
        try changeEdgeStatus(of: straight, to: .off)
    } else if cell0.number == 1 && cell1.number == 3 {
      // 1と3の組み合せなら3の底辺がOn、1の対辺がOff
      if edge.horizontal {
        onEdge = cell1.vEdges[opos]
        offEdge = cell0.vEdges[pos]
        offvEdge = cell0.hEdges[0]
      } else {
        onEdge = cell1.hEdges[opos]
        offEdge = cell0.hEdges[pos]
        offvEdge = cell0.vEdges[0]
      }
      try changeEdgeStatus(of: onEdge, to: .on)
      try changeEdgeStatus(of: offEdge, to: .off)
      try changeEdgeStatus(of: offvEdge, to: .off)
    } else if cell0.number == 3 && cell1.number == 1 {
      if edge.horizontal {
        onEdge = cell0.vEdges[opos]
        offEdge = cell1.vEdges[pos]
        offvEdge = cell1.hEdges[1]
      } else {
        onEdge = cell0.hEdges[opos]
        offEdge = cell1.hEdges[pos]
        offvEdge = cell1.vEdges[1]
      }
      try changeEdgeStatus(of: onEdge, to: .on)
      try changeEdgeStatus(of: offEdge, to: .off)
      try changeEdgeStatus(of: offvEdge, to: .off)
    }
  }
  
  /// 与えられた状態がOffに変化したEdgeの与えられた方向のCellをチェックする
  ///
  /// - Parameters:
  ///   - edge: 状態がOffに変化したEdge
  ///   - pos: 左右(0:indexが小さな側、1:indexが大きな側）
  /// - Throws: 解の探索時例外
  private func checkCellOfOffEdge(edge: Edge, pos: Int) throws {
    let cell = edge.cells[pos]
    
    // セルのOffの辺数が(4-ナンバー)と一致したら残りはOn
    if cell.number > 0 && cell.offCount == 4 - cell.number {
      if cell.hEdges[0].status == .unset {
        try changeEdgeStatus(of: cell.hEdges[0], to: .on)
      }
      if cell.vEdges[0].status == .unset {
        try changeEdgeStatus(of: cell.vEdges[0], to: .on)
      }
      if cell.hEdges[1].status == .unset {
        try changeEdgeStatus(of: cell.hEdges[1], to: .on)
      }
      if cell.vEdges[1].status == .unset {
        try changeEdgeStatus(of: cell.vEdges[1], to: .on)
      }
    }
    
    // セルが2でその向こうが3なら3の一番奥の辺はOn
    if cell.number == 2 {
      let oedge = cell.oppsiteEdge(of: edge)
      let aCell = oedge!.cells[pos]
      if aCell.number == 3 {
        try changeEdgeStatus(of: aCell.oppsiteEdge(of: oedge!)!, to: .on)
      }
    }
  }

  /// 状態が変化したエッジに接していたセルの色をチェックする
  ///
  /// - Parameter cell: 対象のセル
  /// - Throws: 解の探索時例外
  private func checkColor(of cell: Cell) throws {
    if cell.color != .unset {
      return
    }
    var color = CellColor.unset
    let edges = [cell.hEdges[0], cell.vEdges[0], cell.hEdges[1], cell.vEdges[1]]
    for edge in edges {
      if edge.status != .unset {
        let aColor = edge.oppositeCell(of: cell).color
        if aColor != .unset {
          let newColor = edge.status == .on ? aColor.otherColor() : aColor
          if color == .unset {
            color = newColor
          } else if color != newColor {
            //debug(">>> conflict to set color: \(cell.id)")
            throw SolveException(reason: .failed)
          }
        }
      }
    }
    if color != .unset {
      currentStep.add(action: SetCellColorAction(cell: cell, color: color))
      for edge in edges {
        let aColor = edge.oppositeCell(of: cell).color
        if edge.status == .unset {
          if aColor != .unset {
            try changeEdgeStatus(of: edge, to: aColor == color ? .off : .on)
          }
        } else {
          if aColor == .unset {
            currentStep.colorCheckCells.insert(edge.oppositeCell(of: cell))
          }
        }
      }
    }
  }

  /// 領域に接するループの末端の数をチェックする
  ///
  /// - Returns: 領域チェックの結果、エッジ、ゲートの状態に変更があったか
  /// - Throws: 解の探索時例外
  private func checkArea() throws -> Bool {
    dump(title: "☆ before checkArea")
    let ac = AreaChecker(solver: self)
    let stat = try ac.check()
    print("★ Area Check: \(stat)")
    return stat
  }
  
  /// 盤面の状態をコンソールに出力する（デバッグ時のみ）
  ///
  /// - Parameter title: 出力時のタイトル
  private func dump(title: String) {
    if option.debug {
      print(title)
      for line in board.dump() {
        print(line)
      }
      print()
    }
  }
  
  /// デバッグ時のみコンソールへ出力する
  ///
  /// - Parameter obj: 出力内容
  public func debug(_ obj: Any) {
    if option.debug {
      print(obj)
    }
  }
}


