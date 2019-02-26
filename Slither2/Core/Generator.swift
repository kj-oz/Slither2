//
//  Generator.swift
//  Slither
//
//  Created by KO on 2018/11/14.
//  Copyright © 2018年 KO. All rights reserved.
//

import Foundation

/// ループの生成中にこれ以上の延長ができなくなった際にスローする例外
struct GenerateException: Error {
  /// 例外の理由
  ///
  /// - failed: 何らかの矛盾が発生した
  /// - finished: ループが完成した
  /// - lengthTooShort: ループが完成したが長さが足りない
  /// - tooManyBlank: ループが完成したが空白地帯が大きい
  enum Reason {
    case failed
    case finished
    case lengthTooShort
    case tooManyBlank
  }
  let reason: GenerateException.Reason
}


/// 盤面の数値の除去パターン
///
/// - free: パターンなし
/// - xSymmetry: X軸対称
/// - ySymmetry: Y軸対称
/// - xySymmetry: XY軸対称
/// - pointSymmetry: 点対称
/// - hPair: 横2個ずつ（同一列）
/// - hPairShift: 横2個ずつ（階段状）
/// - dPair: 斜め2個ずつ（同一方向）
/// - dPairCross: 斜め2個ずつ（X型）
/// - dPairSymmetry: 斜め2個ずつ（同一方向、X軸対称）
/// - quad: 田型4個ずつ（同一列）
/// - quadShift: 田型4個ずつ（階段状）
enum PruneType: String {
  case free = "F"
  case xSymmetry = "X"
  case ySymmetry = "Y"
  case xySymmetry = "B"
  case pointSymmetry = "P"
  case hPair = "H"
  case hPairShift = "HS"
  case hPairSymmetry = "HX"
  case dPair = "D"
  case dPairCross = "DC"
  case dPairSymmetry = "DX"
  case quad = "Q"
  case quadShift = "QS"
  case random2Cell = "R2"
  case random4Cell = "R4"
  
  /// 文字列表現
  public var description: String {
    switch self {
    case .free:
      return "制約なし [F]"
    case .xSymmetry:
      return "X対象 [X]"
    case .ySymmetry:
      return "Y対象 [Y]"
    case .xySymmetry:
      return "XY対象 [B]"
    case .pointSymmetry:
      return "点対称 [P]"
    case .hPair:
      return "横2連 [H]"
    case .hPairShift:
      return "横2連ずれ [HS]"
    case .hPairSymmetry:
      return "横2連X対象 [HX]"
    case .dPair:
      return "斜2連 [D]"
    case .dPairCross:
      return "斜2連クロス [DC]"
    case .dPairSymmetry:
      return "斜2連X対象 [DX]"
    case .quad:
      return "田型4連 [Q]"
    case .quadShift:
      return "田型4連ずれ [QS]"
    case .random2Cell:
      return "2セル（任意）"
    case .random4Cell:
      return "4セル（任意）"
    }
  }
  
  public var realType: PruneType {
    switch self {
    case .random2Cell:
      return [.xSymmetry, .ySymmetry, .pointSymmetry, .hPair, .dPair].randomElement()!
    case .random4Cell:
      return [.xySymmetry, .hPairSymmetry, .dPairSymmetry, .quad].randomElement()!
    default:
      return self
    }
  }
}


/// ループ生成オプション
struct GenerateOption {
  /// ループの延長の全Edge数に対する割合
  var loopLengthFraction = 0.25
  /// ループに全く接していないEdge数の割合
  var blankEdgeFraction = 0.05
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
  
  /// 処理に要した時間
  var elapsedGL = 0.0
  
  /// ブランチの再帰呼び出し時の最大レベル
  var maxLevel = 0
  
  /// 全セルの数値
  var originalNumbers: [Int] = []
  
  /// セルの数値の間引き順序（いくつかのセルを同時に間引くため配列の配列になっている）
  var pruneOrders: [[Int]] = []
  
  /// 仮：「スリザー」用の同じオプションによる複数の問題からなる問題集を生成する
  ///
  /// - Parameters:
  ///   - path: ファイルのパス
  ///   - numProblem: 生成する問題数
  ///   - width: 巾
  ///   - height: 高さ
  ///   - solveOption: 問題生成時に使用するソルバーのオプション
  ///   - pruneType: 盤面のパターン
  static func createWorkbook(path: String, numProblem: Int,
                             width: Int, height: Int, solveOption: SolveOption,
                             pruneType: PruneType = .free) {
    
    let formatter = DateFormatter()
    formatter.dateFormat = "yyMMddHHmm"
    let dateStr = formatter.string(from: Date())
    let bookTitle = "\(pruneType.description)-\(dateStr)\(solveOption.description)"
    let puzzleTitle = "\(pruneType.description)-\(solveOption.description)"

    let filePath = path + "/\(bookTitle).workbook"
    
    var workbook: [String:Any] = ["title" : bookTitle]
    var problems: [[String:Any]] = []
    for i in 0 ..< numProblem {
      let generator = Generator(width: width, height: height)
      
      var genOption = GenerateOption()
      genOption.blankEdgeFraction = 0.05
      genOption.loopLengthFraction = 0.25
      
      let _ = generator.generateLoop(option: genOption)
      print(String(format: "GenerateLoop:Elapsed: %.0f ms",
                   generator.elapsedGL * 1000))
      generator.setupPruneOrder(pruneType: pruneType)
      let numbers = generator.pruneNumbers(solveOption: solveOption)
      
      var problem: [String:Any] = ["title" : "\(puzzleTitle)-\(i)"]
      problem["status"] = 1
      problem["difficulty"] = solveOption.maxGuessLevel
      problem["width"] = width
      problem["height"] = height
      problem["data"] = numbers
      problem["elapsedSecond"] = 0
      problem["resetCount"] = 0
      problem["fixCount"] = 0
      problems.append(problem)
    }
    workbook["problems"] = problems
    do {
      let jsonData = try JSONSerialization.data(withJSONObject: workbook, options: [])
      let jsonStr = String(bytes: jsonData, encoding: .utf8)!
      try jsonStr.write(toFile: filePath, atomically: true, encoding: .utf8)
      print(jsonStr)  // 生成されたJSON文字列 => {"Name":"Taro"}
    } catch let error {
      print(error)
    }
  }
  
  /// 仮：「スリザー」用の同ループに対し異なるオプションで生成した複数の問題からなる問題集を生成する
  ///
  /// - Parameters:
  ///   - path: ファイルのパス
  ///   - width: 巾
  ///   - height: 高さ
  ///   - solveOptions: ソルバのオプションの配列
  static func createWorkbook(path: String, width: Int, height: Int,
                             solveOptions: [SolveOption]) {
    
    let formatter = DateFormatter()
    formatter.dateFormat = "yyMMddHHmm"
    let dateStr = formatter.string(from: Date())
    
    let filePath = path + "/\(dateStr).workbook"
    
    var workbook: [String:Any] = ["title" : dateStr]
    var problems: [[String:Any]] = []
    let generator = Generator(width: width, height: height)
    
    var genOption = GenerateOption()
    genOption.blankEdgeFraction = 0.05
    genOption.loopLengthFraction = 0.25
    
    let _ = generator.generateLoop(option: genOption)
    print(String(format: "GenerateLoop:Elapsed: %.0f ms",
                 generator.elapsedGL * 1000))
    
    for solveOption in solveOptions {
      let numbers = generator.pruneNumbers(solveOption: solveOption)
      
      var problem: [String:Any] = ["title" : "\(solveOption.description)"]
      problem["status"] = 1
      problem["difficulty"] = solveOption.maxGuessLevel
      problem["width"] = width
      problem["height"] = height
      problem["data"] = numbers
      problem["elapsedSecond"] = 0
      problem["resetCount"] = 0
      problem["fixCount"] = 0
      problems.append(problem)
    }
    workbook["problems"] = problems
    do {
      let jsonData = try JSONSerialization.data(withJSONObject: workbook, options: [])
      let jsonStr = String(bytes: jsonData, encoding: .utf8)!
      try jsonStr.write(toFile: filePath, atomically: true, encoding: .utf8)
      print(jsonStr)  // 生成されたJSON文字列 => {"Name":"Taro"}
    } catch let error {
      print(error)
    }
  }
  
  /// コンストラクタ
  ///
  /// - Parameters:
  ///   - width: 幅
  ///   - height: 高さ
  init(width: Int, height: Int) {
    self.board = Board(width: width, height: height,
                      numbers: Array<Int>(repeating: -1, count: width * height))
  }
  
  /// ループを生成する
  ///
  /// - Parameter option: ループ生成オプション
  /// - Returns: ループ（Edgeの配列）
  func generateLoop(option: GenerateOption) -> [Edge] {
    self.option = option
    minOnEdgeCount = Int(Double(board.edges.count) * option.loopLengthFraction)
    maxBlankEdgeCount = Int(Double(board.edges.count) * option.blankEdgeFraction)

    let startTime = Date()

    // 満足のできる問題ができるまで試行を続ける
    retryCount = 0
    while true {
      retryCount += 1
      let root = board.nodes.randomElement()!
      let branches = createBranches(from: root)

      do {
        try tryBranches(branches)
      } catch {
        let exception = error as! GenerateException
        if exception.reason == .finished {
          // 完成
          break
        } else if exception.reason == .lengthTooShort {
          // ある回数試みても長さが不足 -> 袋小路にはまり込んでいる可能性が高いので、最初からやり直し
        } else if exception.reason == .tooManyBlank {
          // ループを延ばしても空白地帯が減らない ->
          // 空白地帯に接したエッジを始終点として再度延長を試みる
          if reduceBlank() {
            break
          }
          // 空白地帯を埋めきれなかったら、最初からやり直し
        }
      }
      board.clear()
    }
    dump(title: "☆ Loop Generated:")
    
    elapsedGL = Date().timeIntervalSince(startTime)
    
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
          if exception.reason == .finished {
            return true
          } else if exception.reason == .lengthTooShort {
            return false
          } else if exception.reason == .tooManyBlank {
            continue
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
  
  public func setupPruneOrder(pruneType: PruneType) {
    for cell in board.cells {
      originalNumbers.append(cell.onCount)
    }

    pruneOrders = []
    let xc = board.width % 2 == 1 ? board.width / 2 : -1
    let yc = board.height % 2 == 1 ? board.height / 2 : -1
    
    switch pruneType {
    case .free:
      for i in 0 ..< board.cells.count {
        pruneOrders.append([i])
      }
    case .xSymmetry, .ySymmetry, .xySymmetry, .pointSymmetry:
      var xmax = board.width
      var ymax = board.height
      if pruneType == .xSymmetry || pruneType == .xySymmetry || pruneType == .pointSymmetry {
        xmax = (board.width + 1) / 2
      }
      if pruneType == .ySymmetry || pruneType == .xySymmetry {
        ymax = (board.height + 1) / 2
      }
      for y in 0 ..< ymax {
        for x in 0 ..< xmax {
          var indecies = [y * board.width + x]
          let xm = board.width - x - 1
          let ym = board.height - y - 1
          if xm != x && (pruneType == .xSymmetry || pruneType == .xySymmetry) {
            indecies.append(y * board.width + xm)
          }
          if ym != y && (pruneType == .ySymmetry || pruneType == .xySymmetry) {
            indecies.append(ym * board.width + x)
          }
          if xm != x && ym != y && (pruneType == .pointSymmetry || pruneType == .xySymmetry) {
            indecies.append(ym * board.width + xm)
          }
          pruneOrders.append(indecies)
        }
      }
    case .hPair, .hPairSymmetry, .dPairCross, .quad:
      var xmax = board.width
      let ymax = board.height
      if pruneType == .hPairSymmetry {
        xmax = (board.width + 1) / 2
      }
      var y = 0
      while y < ymax {
        var x = 0
        while x < xmax {
          let index = y * board.width + x
          var indecies = [index]
          if x == xc {
            if y != yc && (pruneType == .dPairCross || pruneType == .quad) {
              indecies.append(index + board.width)
            }
            pruneOrders.append(indecies)
            x += 1
          } else {
            if pruneType == .hPairSymmetry {
              let xm = board.width - x - 1
              indecies.append(y * board.width + xm)
            }
            if pruneType == .hPair || pruneType == .hPairSymmetry || pruneType == .quad {
              indecies.append(index + 1)
              if pruneType == .hPairSymmetry {
                let xm = board.width - x - 2
                indecies.append(y * board.width + xm)
              }
            }
            if y == yc {
              if pruneType == .dPairCross {
                indecies.append(index + 1)
              }
              pruneOrders.append(indecies)
            } else {
              if pruneType == .quad {
                indecies.append(index + board.width)
              }
              if pruneType == .dPairCross || pruneType == .quad {
                indecies.append(index + board.width + 1)
              }
              pruneOrders.append(indecies)
              if pruneType == .dPairCross {
                indecies = [index + 1, index + board.width]
                pruneOrders.append(indecies)
              }
            }
            x += 2
          }
        }
        y += ((pruneType == .hPair || pruneType == .hPairSymmetry || y == yc) ? 1 : 2)
      }
    case .hPairShift, .quadShift:
      var y = 0
      var start = 0
      while y < board.height {
        var x = 0
        while x < board.width {
          let index = y * board.width + x
          var indecies = [index]
          if y < board.height - 1 && pruneType == .quadShift {
            indecies.append(index + board.width)
          }
          if x >= start {
            if x < board.width - 1 {
              indecies.append(index + 1)
              if y < board.height - 1 && pruneType == .quadShift {
                indecies.append(index + board.width + 1)
              }
            }
            x += 2
          } else {
            x += 1
          }
          pruneOrders.append(indecies)
        }
        y += (pruneType == .quadShift ? 2 : 1)
        start = 1 - start
      }
    case .dPair, .dPairSymmetry:
      var xmax = board.width
      let ymax = board.height
      if pruneType == .dPairSymmetry {
        xmax = (board.width + 1) / 2
      }
      var y = 0
      while y < ymax {
        for x in 0 ..< xmax {
          let index = y * board.width + x
          var indecies = [index]
          let xm = board.width - x - 1
          if xm != x && pruneType == .dPairSymmetry {
            indecies.append(y * board.width + xm)
          }
          let x1 = x + 1
          let y1 = y + 1
          if y1 < ymax && x1 < xmax {
            indecies.append(y1 * board.width + x1)
            if pruneType == .dPairSymmetry {
              let xm1 = board.width - x1 - 1
              indecies.append(y1 * board.width + xm1)
            }
          }
          pruneOrders.append(indecies)
        }
        y += 1
        if y < ymax {
          var indecies = [y * board.width]
          if pruneType == .dPairSymmetry {
            let xm1 = board.width - 1
            indecies.append(y * board.width + xm1)
          }
          pruneOrders.append(indecies)
        }
        y += 1
      }
    default:
      break
    }
    pruneOrders.shuffle()
  }

  /// 数値を間引く
  ///
  /// - Parameter solveOption: ソルバのオプション
  /// - Returns: 間引き後の数値の配列（間引かれた箇所は−1）
  public func pruneNumbers(solveOption: SolveOption) -> [Int] {
    var numbers = originalNumbers
    var pruneCount = 0
    for indecies in pruneOrders {
      pruneCount += 1
      for index in indecies {
        numbers[index] = -1
      }
      let newBoard = Board(width: board.width, height: board.height, numbers: numbers)
      let solver = Solver(board: newBoard)
      
      let solved = solver.solve(option: solveOption)
      if !solved {
        for index in indecies {
          numbers[index] = originalNumbers[index]
        }
      }
      debug("prune \(pruneCount): \(solved) \(solver.maxLevel) \(Int(solver.elapsed * 1000.0))")
    }
    return numbers
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
          if exception.reason != .failed {
            throw error
          }
          currentStep.rewind()
          continue;
        }
        newRoot = board.getLoopEnd(from: branch.root, and: branch.edge)
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
    throw GenerateException(reason: .lengthTooShort)
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
      throw GenerateException(reason: .failed)
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
          throw GenerateException(reason: .finished)
        } else {
          throw GenerateException(reason: .failed)
        }
      } else {
        if !canReach(from: head, to: tail) {
          throw GenerateException(reason: .failed)
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
          throw GenerateException(reason: .tooManyBlank)
        }
        prevBlankEdgeCount = blankCount
      }
    } else {
      lengthCheckCount += 1
      if lengthCheckCount > maxLengthCheckCount {
        throw GenerateException(reason: .lengthTooShort)
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

