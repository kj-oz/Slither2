//
//  Generator.swift
//  Slither
//
//  Created by KO on 2018/11/14.
//  Copyright © 2018年 KO. All rights reserved.
//

import Foundation

/// ループの生成中にこれ以上の延長ができなくなった際にスローする例外
///
/// - failed: 何らかの矛盾が発生した
/// - finished: ループが完成した
/// - lengthTooShort: ループが完成したが長さが足りない
/// - tooManyBlank: ループが完成したが空白地帯が大きい
enum GenerateException: Error {
  case failed
  case finished
  case lengthTooShort
  case tooManyBlank
}


/// ループ生成オプション
struct GenerateOption {
  /// ループの延長の全Edge数に対する割合
  var loopLengthFraction = 0.25
  /// ループに全く接していないEdge数の割合
  var blankEdgeFraction = 0.05
}

/// ループ生成時の統計情報
struct GenerateStatistics {
  /// 各計測時の所要秒数の配列（ループ生成、除去Q1、Q2、Q3、Q4）
  var elapsed: [Int] = []
  /// 除去した数
  var pruneCount = 0
  /// 除去した数の中で領域チェックが有効だった数
  var areaCheckUsed = 0
  /// 前回計測時の時刻
  var prev = Date()
  
  /// 統計情報の開始
  mutating func start() {
    prev = Date()
  }
  
  /// 前回計測時からの時間を測定し保存する
  mutating func measure() {
    let now = Date()
    elapsed.append(Int(now.timeIntervalSince(prev) * 1000.0))
    prev = now
  }
  
  /// 統計情報の文字列
  var description: String {
    return String(format: "%d,%d,%d,%d,%d,%d,%d", pruneCount, elapsed[0], elapsed[1], elapsed[2],
                  elapsed[3], elapsed[4], areaCheckUsed)
  }
}

/// 問題を生成するクラス
class Generator {
  /// 盤面データ
  let board: Board
  
  /// ループ生成の再帰呼び出し時の全ステップを保持している配列
  var steps: [Step] = []
  
  /// 現在のステップ
  var currentStep = Step()
  
  /// OnのEdgeの最低数
  var minOnEdgeCount = 0
  
  /// 長さが不足のループができた場合に、最後のEdgeをOffにしてループの延長にトライする最大回数
  /// （それ以上続く場合には、袋小路に入ってしまっている可能性が高い）
  let maxLengthCheckCount = 10
  
  ///　長さが不足のループができてループの延長にトライしている回数
  var lengthCheckCount = 0
  
  /// ブランク（ループに全く接していない）Edgeの最大数
  var maxBlankEdgeCount = 0
  
  /// 全Edgeのブランク領域番号
  var blankMap: [Int] = []
  
  ///　前回のブランクEdge数
  var prevBlankEdgeCount = Int.max
  
  ///　領域番号未確定の場合の番号
  let unknownAreaNo = Int.max
  
  ///　ブランクではない場合（いずれかの端点はループ上）の領域番号
  let noAreaNo = -1
  
  /// 各空白領域の面積（属するEdge数）
  var areas: [Int:Int] = [:]

  /// 最初からの再試行の回数
  var retryCount = 0
  
  ///　ループ生成のオプション
  var option: GenerateOption = GenerateOption()

  /// デバッグ出力をおこなうかどうか
  var debug = true

  /// ブランチの再帰呼び出し時の最大レベル
  var maxLevel = 0
  
  /// 生成時の統計情報
  var stats: GenerateStatistics = GenerateStatistics()
  
  /// コンストラクタ
  ///
  /// - Parameters:
  ///   - width: 幅
  ///   - height: 高さ
  init(width: Int, height: Int) {
    self.board = Board(width: width, height: height,
                      numbers: Array<Int>(repeating: -1, count: width * height))
  }
  
  /// ループの生成から数字の除去までの一連の処理を行い、パズルを生成する
  ///
  /// - Parameters:
  ///   - genOp: ループ生成に関するいオプション
  ///   - pruneType: 数字除去のタイプ
  ///   - solveOp: パズル解明に対するオプション
  ///   - progressHandler: 生成の進捗時に呼び出される処理
  ///        引数は、count: 進度、total: 総数
  ///        ループ生成のリトライ時には、totalが0、countが失敗の回数で呼び出される
  ///        数字除去時には、totalが総除去回数、countが済んだ回数で呼び出される
  /// - Returns: 盤面の状態
  public func generate(genOp: GenerateOption, pruneType: PruneType, solveOp: SolveOption,
                       progressHandler: ((_ count: Int, _ total: Int) -> ())?) -> [Int] {
    stats = GenerateStatistics()
    stats.start()
    let _ = generateLoop(option: genOp, retryHandler: { (count) in
      progressHandler?(count, 0)
    })
    
    let pruner = Pruner(board: board, pruneType: pruneType)
    pruner.setupPruneOrder()
    stats.pruneCount = pruner.pruneOrders.count
    
    stats.measure()
    
    let numbers = pruner.pruneNumbers(solveOption: solveOp, stepHandler: { (count, result) in
      if result.solved && result.useAreaCheckResult {
        self.stats.areaCheckUsed += 1
      }
      switch count {
      case self.stats.pruneCount / 4, self.stats.pruneCount / 2,
            self.stats.pruneCount * 3 / 4, self.stats.pruneCount:
        self.stats.measure()
      default:
        break
      }
      progressHandler?(count, self.stats.pruneCount)
    })
    return numbers
  }
  
  /// ループを生成する
  ///
  /// - Parameters:
  ///   - option: ループ生成オプション
  ///   - retryHandler: リトライ時に呼び出されるハンドラ、引数はリトライ回数
  /// - Returns: ループ（Edgeの配列）
  func generateLoop(option: GenerateOption, retryHandler: ((Int) -> ())?) -> [Edge] {
    self.option = option
    minOnEdgeCount = Int(Double(board.edges.count) * option.loopLengthFraction)
    maxBlankEdgeCount = Int(Double(board.edges.count) * option.blankEdgeFraction)

    // 満足のできる問題ができるまで試行を続ける
    retryCount = 0
    loop: while true {
      retryCount += 1
      let root = board.nodes.randomElement()!
      let branches = createBranches(from: root)

      do {
        try tryBranches(branches)
      } catch {
        let exception = error as! GenerateException
        switch exception {
        case .finished:
          // 完成
          break loop
        case .lengthTooShort:
          // ある回数試みても長さが不足 -> 袋小路にはまり込んでいる可能性が高いので、最初からやり直し
          break
        case .tooManyBlank:
          // ループを延ばしても空白地帯が減らない ->
          // 空白地帯に接したエッジを始終点として再度延長を試みる
          if reduceBlank() {
            break loop
          }
          // 空白地帯を埋めきれなかったら、最初からやり直し
        case .failed:
          break
        }
      }
      board.clear()
      retryHandler?(retryCount)
    }
    dump(title: "☆ Loop Generated:")
    
    return board.loop
  }
  
  /// 空白地帯を削減する
  ///
  /// - Returns: 空白地帯を既定値以下に削減できたか
  func reduceBlank() -> Bool {
    // dump(title: "reduceBlank 0")
    var retryCount = 0
    while true {
      retryCount += 1
      let loop = board.loop
      if let cell = findExpendableCell() {
        // dump(title: "reduceBlank \(retryCount)")
        do {
          let branch = try setupLoop(original: loop, cutter: cell)
          try tryBranches(branch)
        } catch {
          let exception = error as! GenerateException
          switch exception {
          case .finished:
            return true
          case .lengthTooShort:
            return false
          default:
            break
          }
        }
      }
      return false
    }
  }
  
  /// 空白地帯を削減するために拡張可能なエッジを含むセルを探し出す
  ///
  /// - Returns: 空白地帯を削減するために拡張可能なエッジを含むセル
  func findExpendableCell() -> Cell? {
    let areas = findBlankAreas()
    for area in areas {
      let cells = findCellsNearBlank(area: area)
      if cells.count > 0 {
        return cells.randomElement()
      }
    }
    return nil
  }
  
  /// 含むエッジの数の多い順にならんだ、空白地帯（の番号）の配列を返す
  ///
  /// - Returns: 空白地帯（の番号）の配列
  func findBlankAreas() -> [Int] {
    areas.removeAll()
    for edge in board.edges {
      if blankMap[edge.index] == unknownAreaNo {
        let count = countArea(seed: edge)
        areas[edge.index] = count
      }
    }
    return areas.keys.sorted { areas[$0]! > areas[$1]! }
  }
  
  /// 与えられたseedにつながる、空白エッジの数を得る
  ///
  /// - Parameter seed: 最初の空白エッジ
  /// - Returns: 一連の空白エッジの数
  func countArea(seed: Edge) -> Int {
    var nodes = seed.nodes
    var count = 1
    let areaNo = seed.index
    blankMap[areaNo] = areaNo
    while nodes.count > 0 {
      let node = nodes.remove(at: 0)
      for edge in node.edges {
        let index = edge.index
        if index >= 0 && blankMap[index] == unknownAreaNo {
          nodes.append(edge.anotherNode(of: node))
          count += 1
          blankMap[index] = areaNo
        }
      }
    }
    return count
  }
  
  /// 与えられた空白地帯に接するセルを求める
  ///
  /// - Parameter area: 空白地帯の番号
  /// - Returns: 与えられた空白地帯に接するセル
  func findCellsNearBlank(area: Int) -> [Cell] {
    var candidates: [Cell] = []
    for cell in board.cells {
      if cell.onCount == 1 && touchArea(area, cell: cell)
          && !hasClosedCorner(cell: cell) {
        candidates.append(cell)
      }
    }
    return candidates.shuffled()
  }
  
  /// 措定のセルが指定の空白地帯に接するかどうかを判定する
  ///
  /// - Parameters:
  ///   - area: 空白地帯の番号
  ///   - cell: 対象のセル
  /// - Returns: 措定のセルが指定の空白地帯に接するかどうか
  func touchArea(_ area: Int, cell: Cell) -> Bool {
    for edge in cell.edges {
      if blankMap[edge.index] == area {
        return true
      }
    }
    return false
  }
  
  /// 頂点がクローズかどうかを判定する
  /// ループ側はクローズはあり得ないので、実質は対角側のチェックになる
  ///
  /// - Parameter cell: 対象のセル
  /// - Returns: 指定のセルにクローズドな頂点が存在するかどうか
  func hasClosedCorner(cell: Cell) -> Bool {
    for h in [0, 1] {
      for v in [0, 1] {
        if cell.hEdges[v].straightEdges[h].status == .on &&
            cell.vEdges[h].straightEdges[v].status == .on {
          return true
        } else if cell.hEdges[v].straightEdges[h].status == .off &&
            cell.vEdges[h].straightEdges[v].status == .off {
          return true
        }
      }
    }
    return false
  }
  
  /// 元のループを、空白地帯に近い部分で切断して、空白地帯側に新たに探索を行う
  ///
  /// - Parameters:
  ///   - original: 元のループ
  ///   - cutter: ループと接し且つ空白地帯とも接するセル
  /// - Returns: 新しく切断したループの探索の始点
  func setupLoop(original: [Edge], cutter: Cell) throws -> BranchBuffer {
    // ループ上の切断位置を求める
    var cutIndex = -1
    var nextIndex = -1
    var cutEdge = cutter.edges[0]
    for i in 0 ..< original.count {
      let edge = original[i]
      if edge.cells[0] === cutter || edge.cells[1] === cutter {
        cutIndex = i
        nextIndex = (i + 1) % original.count
        cutEdge = edge
        break
      }
    }
    
    // 切断位置のエッジの始点側端点を求める
    var pos = 1
    if cutEdge.nodes[0].edges.contains(original[nextIndex]) {
      pos = 0
    }
    
    // 始点側を空白地帯側（セル上）に１エッジ伸ばし、既存のループを繋げる
    var loop: [Edge] = []
    let nodeS = cutEdge.nodes[pos]
    for edge in nodeS.edges {
      if edge.status != .on && cutter.edges.contains(edge) {
        loop.append(edge)
        break
      }
    }
    if nextIndex > 0 {
      loop.append(contentsOf: original[nextIndex ..< original.count])
    }
    loop.append(contentsOf: original[0 ..< cutIndex])

    // 終点側の空白地帯側のブランチを得る
    let branches = BranchBuffer()
    let nodeE = cutEdge.nodes[1 - pos]
    for edge in nodeE.edges {
      if edge.status != .on && cutter.edges.contains(edge) {
        branches.add(Branch(root: nodeE, edge: edge))
        break
      }
    }

    // ボードを新たなループで再構成する
    board.clear()
    for edge in loop {
      try changeEdgeStatus(of: edge, to: .on)
    }
    try checkSurroundingElements(trying: false)
    return branches
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
    branches.branches.shuffle()
    return branches;
  }
  
  /// 与えられた分岐のリストを順番にOnにして試す
  /// 分岐の枝の状態を変えてもルートが確定しなかった場合、その先の末端で再起的に処理を行う
  /// 効率化のため実際には再起呼び出しは行わずループで処理する
  ///
  /// - Parameter branches: 分岐の枝の配列
  private func tryBranches(_ rootBranches: BranchBuffer) throws {
    steps = []
    var branchStack: [BranchBuffer] = [rootBranches]
    var level = 1
    maxLevel = 1
    prevBlankEdgeCount = board.edges.count
    lengthCheckCount = 0
    var newBranches = rootBranches
    var newRoot: Node? = nil
    var addDepth = false
    
    while level > 0 {
      // print("★ retry=\(retryCount) level=\(level) steps=\(steps.count) branchStatck=\(branchStack.count)")
      if steps.count == level - 1 {
        // 新しいステップの開始
        startNewStep()
      } else {
        // 深い部分の探索から戻ってきた状態
        currentStep.rewind()
      }

      let branches = branchStack.last!
      addDepth = false
      while branches.count > 0 {
        let branch = branches.remove()
        //debug("☆ branch=\(branch.root.id)->\(branch.edge.id)")
        do {
          try changeEdgeStatus(of: branch.edge, to: .on)
          try checkSurroundingElements(trying: false)
        } catch {
          let exception = error as! GenerateException
          if case .failed = exception {
          } else {
            throw error
          }
          currentStep.rewind()
          continue;
        }
        (newRoot, _) = board.getLoopEnd(from: branch.root, and: branch.edge)
        if newRoot == nil {
          dump(title: "■■ newRoot is nil (\(branch.root.id) -> \(branch.edge.id))")
        }
        newBranches = createBranches(from: newRoot!)
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
    // 再挑戦
    throw GenerateException.lengthTooShort
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
    if edge.status == status {
      return
    }
    
    if edge.status != .unset {
      //debug(">>> cannot set to \(status): \(edge.id) is \(edge.status)")
      throw GenerateException.failed
    }
    
    currentStep.add(action: SetEdgeStatusAction(edge: edge, status: status))
    currentStep.changedEdges.append(edge)
    
    if status == .on {
      // 連続線の端部の更新
      let head = edge.nodes[0].oppositeNode ?? edge.nodes[0]
      let tail = edge.nodes[1].oppositeNode ?? edge.nodes[1]
      
      if head === edge.nodes[1] {
        // 長さとボアリングレートを満足しているか
        if try checkLoop() {
          throw GenerateException.finished
        } else {
          throw GenerateException.failed
        }
      } else {
        if !canReach(from: head, to: tail) {
          throw GenerateException.failed
        }
        currentStep.add(action: SetOppositeNodeAction(node: head, oppositeNode: tail))
        currentStep.add(action: SetOppositeNodeAction(node: tail, oppositeNode: head))
      }
    }
  }
  
  
  /// ループが条件を満足するかチェックする
  ///
  /// - Returns: ループが条件を満足するか
  /// - Throws: ループ生成時のエラー
  private func checkLoop() throws -> Bool {
    if board.onEdgeCount > minOnEdgeCount {
      lengthCheckCount = 0
      let blankCount = countBlank()
      if blankCount < maxBlankEdgeCount {
        debug("onEdge:\(board.onEdgeCount) blank:\(blankCount)")
        return true
      } else {
        if blankCount >= prevBlankEdgeCount {
          // 拡張を試す
          throw GenerateException.tooManyBlank
        }
        prevBlankEdgeCount = blankCount
      }
    } else {
      lengthCheckCount += 1
      if lengthCheckCount > maxLengthCheckCount {
        throw GenerateException.lengthTooShort
      }
    }
    return false
  }
  
  /// 与えられた２つのNodeを繋げることが可能かを確認する
  ///
  /// - Parameters:
  ///   - from: Node1
  ///   - to: Node2
  /// - Returns: 与えられた２つのNodeを繋げることが可能か
  private func canReach(from: Node, to: Node) -> Bool {
    var reachable: Set<Node> = []
    var reached: [Node] = []
    
    reachable.insert(from)
    reached.append(from)
    var i = 0
    while i < reached.count {
      let node = reached[i]
      i += 1
      for edge in (node.hEdges + node.vEdges) {
        if edge.status == .unset {
          let nextNode = edge.anotherNode(of: node)
          if nextNode === to {
            return true
          }
          if !reachable.contains(nextNode) {
            reachable.insert(nextNode)
            reached.append(nextNode)
          }
        }
      }
    }
    return false
  }
  
  /// ループから離れたEdgeの数を求める。同時にそれらのEdgeのマップも作成する
  ///
  /// - Returns: ループから離れたエッジの数
  private func countBlank() -> Int {
    blankMap = Array.init(repeating: noAreaNo, count: board.edges.count)
    var blankCount = 0
    for edge in board.edges {
      if edge.status == .unset {
        var touchesLoop = false
        nodes_loop: for node in edge.nodes {
          for nEdge in node.edges {
            if nEdge.status == .on {
              touchesLoop = true
              break nodes_loop
            }
          }
        }
        if !touchesLoop {
          blankCount += 1
          blankMap[edge.index] = unknownAreaNo
        }
      }
    }
    debug("blankCheck: \(blankCount)")
    return blankCount
  }
  
  /// 状態を変更されたEdgeに対してその前後のNode、左右のCellに対して直接の影響をチェックする
  /// 更に左右のCellを色チェックの対象として、斜め前方、左右、斜め後方のCellをコーナーチェックの
  /// 対象として登録する
  /// 全Edgeの周辺チェック終了後、まず登録されたCellの色のチェックを行い、何も無ければ
  /// 登録されたCellのコーナーチェックを行う、その結果いずれかのEdgeの状態が変更されると、
  /// Edge周辺のチェックから繰り返す
  ///
  /// - Throws: 解の探索時例外
  private func checkSurroundingElements(trying: Bool) throws {
    while currentStep.changedEdges.count > 0 {
      let edge = currentStep.changedEdges.remove(at: 0)
      
      switch edge.status {
      case .on:
        try checkNodeOfOnEdge(edge: edge, pos: 0)
        try checkNodeOfOnEdge(edge: edge, pos: 1)
      case .off:
        try checkNodeOfOffEdge(edge: edge, pos: 0)
        try checkNodeOfOffEdge(edge: edge, pos: 1)
      default:
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
  func checkNodeOfOnEdge(edge: Edge, pos: Int) throws {
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
    // ノードのOffの辺数が2(Onは1)になったら残りはOn
    } else if node.offCount == 2 {
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
  
  /// 与えられた状態がOffに変化したEdgeの与えられた方向のNodeをチェックする
  ///
  /// - Parameters:
  ///   - edge: 状態がOffに変化したEdge
  ///   - pos: 前後(0:indexが小さな側、1:indexが大きな側）
  /// - Throws: 解の探索時例外
  func checkNodeOfOffEdge(edge: Edge, pos: Int) throws {
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
    // ノードのOnの辺数が1でOffの辺数が2になったら残りはOn
    } else if node.offCount == 2 && node.onCount == 1 {
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
  
  /// 盤面の状態をコンソールに出力する（デバッグ時のみ）
  ///
  /// - Parameter title: 出力時のタイトル
  private func dump(title: String) {
    if debug {
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
    if debug {
      print(obj)
    }
  }
}

