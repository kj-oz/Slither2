//
//  AreaChecker.swift
//  Slither
//
//  Created by KO on 2018/10/08.
//  Copyright © 2018年 KO. All rights reserved.
//

import Foundation

/// 点（盤の各ノード）の状態を表すクラス
class Point: Equatable {
  
  /// 点の状態
  ///
  /// - wall: 壁、ループの中間点、またはoffCountが4のノード
  /// - gate: 門、その後の操作次第で、terminalにもwallにもなりうるノード、ループの末端の場合もある
  /// - terminal: ループの末端（gateにならないもの）
  /// - space: 空白、いずれかの領域の一部
  enum PointType {
    case wall
    case gate
    case terminal
    case space
  }
  
  /// (Equatable)
  static func == (lhs: Point, rhs: Point) -> Bool {
    return lhs === rhs
  }

  /// 点の状態
  var type: PointType = .space
  
  /// 元のノード
  var node: Node
  
  /// 属するエリア、重複なし（gateの場合には２つの場合がある）
  var areas: [Area] = []
  
  /// 隣接するポイント（上、左、下、右の順）との接続が可能かどうか
  var conns: [Bool] = []
  
  /// 隣接するポイント（上、左、下、右の順）
  /// 間のエッジがunsetでない場合（connns[index] == false）はnil
  var nextPoints: [Point?] = []
  
  /// 隣接するポイント間が、自分を介さずに接続が可能かどうか
  /// index=0には、nextPoints[0]とnextPoints[1]の間の接続が可能かを保持
  /// どちら向きにも他のポイントとouterでつながっていないポイントが存在するとゲートになる
  var outerConns: [Bool] = []

  /// 与えられたNodeに対するPointを生成する
  ///
  /// - Parameter node: ノード
  init(node: Node) {
    self.node = node
    type = getPointType(of: node)
  }
  
  /// 点の状態を得る
  ///
  /// - Parameter node: ノード
  /// - Returns: 点の状態
  private func getPointType(of node: Node) -> Point.PointType {
    // 外側の4つのノードへの接続状態
    conns = [node.vEdges[0].status == .unset, node.hEdges[0].status == .unset,
                node.vEdges[1].status == .unset, node.hEdges[1].status == .unset]
    
    if node.onCount == 2 || node.offCount > 2 {
      return .wall
    }
    
    // 外側の4つのノード間をつなぐエッジ群
    let outerEdges: [Edge] = [
      node.vEdges[0].nodes[0].hEdges[0], node.hEdges[0].nodes[0].vEdges[0],
      node.hEdges[0].nodes[0].vEdges[1], node.vEdges[1].nodes[1].hEdges[0],
      node.vEdges[1].nodes[1].hEdges[1], node.hEdges[1].nodes[1].vEdges[1],
      node.hEdges[1].nodes[1].vEdges[0], node.vEdges[0].nodes[0].hEdges[1]
    ]
    
    // 外側の4つのノード間がunsetでつながっているかどうか
    for i in [0, 2, 4, 6] {
      outerConns.append(outerEdges[i].status == .unset && outerEdges[i + 1].status == .unset)
    }
    
    // 外側の4つのノードのうち、枝分かれしている数
    var branchCount = 0
    for i in 0 ..< 4 {
      // outerConnがfalse && connsがtrue ＝ 一続きのエリアの終わり ＝ 1ブランチ
      if conns[i] && !outerConns[i] {
        branchCount += 1
      }
    }
    // 枝が3以上の場合、エリア以外の枝の先には必ずもう一つのゲートがあるのでエリアとして扱う
    if branchCount == 2 {
      return .gate
    } else {
      return node.onCount > 0 ? .terminal : .space
    }
  }
  
  /// nextPointsをセットする
  ///
  /// - Parameter points: 全ポイントの配列
  func connect(points: [[Point]]) {
    let x = node.x
    let y = node.y
    nextPoints = [
      conns[0] ? points[y - 1][x] : nil,
      conns[1] ? points[y][x - 1] : nil,
      conns[2] ? points[y + 1][x] : nil,
      conns[3] ? points[y][x + 1] : nil
    ]
  }
}

/// エリア（未確定のエッジでつながっている一連の点）を表すクラス
/// 一つのエリアに接するループの末端の数は偶数である必要がある
class Area : Hashable {
  /// 次のエリアのID
  static var nextId = 1
  
  /// エリアのID（1からの連番）
  let id: Int
  
  /// (Hashable)
  var hashValue: Int {
    return id
  }
  
  /// (Hashable)
  static func == (lhs: Area, rhs: Area) -> Bool {
    return lhs.id == rhs.id
  }
  
  /// 当該エリアに接するゲート（重複なし）
  var gates: [Point] = []
  
  /// 当該エリアに接するループ末端（重複なし）
  var terminals: [Point] = []
  
  /// terminalによって接続している他のエリア（重複なし）
  var connectedAreas: [Area] = []
  
  /// terminalによって接続しているゲート（重複なし）
  /// gateは自分とつながる可能性もある（が、カウントには支障がない）
  var connectedGates: [Point] = []
  
  /// エリアに組み入れられ、まだチェックが済んでいない点（terminal、gate含む）
  var notChecked: [Point] = []
  
  /// 与えられた始点からつながる一連のエリアを構築する
  ///
  /// - Parameters:
  ///   - seed: 始点
  ///   - points: 元々の点群
  init(seed: Point, points: [[Point]]) {
    id = Area.nextId
    Area.nextId += 1
    seed.areas.append(self)
    if seed.type == .terminal {
      terminals.append(seed)
    }
    notChecked.append(seed)
    
    while notChecked.count > 0 {
      let point = notChecked.removeFirst()
      if point.type != .gate {
        // ゲート以外は4方向の点をチェック
        for nextPoint in point.nextPoints {
          if let nextPoint = nextPoint {
            judgePoint(nextPoint)
          }
        }
      } else {
        // ゲートの場合は、自エリアと外部で綱っがっているポイントのみチェック
        var fromPoint = -1
        for i in 0 ..< 4 {
          if let nextPoint = point.nextPoints[i] {
            if nextPoint.areas.contains(self) {
              fromPoint = i
              break
            }
          }
        }
        for i in fromPoint ..< fromPoint + 3 {
          if let nextPoint = point.nextPoints[(i + 1) % 4] {
            if !point.outerConns[i % 4] {
              break
            }
            judgePoint(nextPoint)
          }
        }
        for i in (fromPoint + 1 ..< fromPoint + 4).reversed() {
          let index = i % 4
          if let nextPoint = point.nextPoints[index] {
            if !point.outerConns[index] {
              break
            }
            judgePoint(nextPoint)
          }
        }
      }
    }
  }
  
  /// 点の状態を判定し、必要な処置を講じる
  ///
  /// - Parameter point: 点
  private func judgePoint(_ point: Point) {
    switch point.type {
    case .space:
      if point.areas.count == 0 {
        point.areas.append(self)
        notChecked.append(point)
      }
    case .gate:
      if !gates.contains(point) {
        point.areas.append(self)
        notChecked.append(point)
        gates.append(point)
      }
    case .terminal:
      if point.areas.count == 0 {
        point.areas.append(self)
        notChecked.append(point)
        terminals.append(point)
      }
    case .wall:
      break
    }
    return
  }
}

/// 全てのエリアがループの末端を偶数個持つのかどうかを検証する
class AreaChecker {
  /// 点の2次元配列（[y][x]）
  var points: [[Point]] = []
  
  /// 全エリアの配列
  var areas: [Area] = []
  
  /// ソルバオブジェクト
  let solver: Solver
  
  /// 点列の高さ（盤の高さ+1）
  let height: Int
  
  // 点列の幅（盤の幅+1）
  let width: Int
  
  // デバッグ用出力のON/OFF
  let debug = false
  
  /// ソルバを引数にチェッカーを生成する
  ///
  /// - Parameter solver: ソルバ
  init(solver: Solver) {
    self.solver = solver
    Area.nextId = 1
    let board = solver.board
    height = board.height + 1
    width = board.width + 1
    for y in 0 ..< height {
      var row: [Point] = []
      for x in 0 ..< width {
        row.append(Point(node: board.nodeAt(x: x, y: y)))
      }
      points.append(row)
    }
    
    for y in 0 ..< height {
      for x in 0 ..< width {
        points[y][x].connect(points: points)
      }
    }
  }
  
  /// チェックを実行する
  ///
  /// - Returns: エッジのステータスの変更を行った場合true
  /// - Throws: 解の探索時例外
  func check() throws -> Bool {
    dump(title: "after init")

    // 各点をエリアに割り当てる
    for y in 0 ..< height {
      for x in 0 ..< width {
        let point = points[y][x]
        if (point.type == .space || point.type == .terminal)
            && point.areas.count == 0 {
          areas.append(Area(seed: point, points: points))
        }
      }
    }
    dump(title: "after area")
    
    // エリアの正規化
    var areaChanged = true
    areaChangedLoop: while areaChanged {
      
      // 逆端の接するエリアが同じ端点が複数ある場合には、その2つのエリアを統合する
      areaChanged = false
      mergeCheckLoop: for area in areas {
        area.connectedAreas = []
        area.connectedGates = []
        for terminal in area.terminals {
          if let oppArea = checkTerminal(terminal, area: area) {
            mergeAreas(to: area, from: oppArea)
            areaChanged = true
            debug("> merge areas: \(oppArea.id) -> \(area.id)")
            continue areaChangedLoop
          }
        }
      } // mergeCheckLoop
      if areas.count == 1 {
        // エリアが1つの場合は、エッジの変更の余地なし
        return false
      }
      
      // 接するエリアが全て同じゲートはエリアに変換
      var gateChanged = true
      gateCheckLoop: while gateChanged {
        gateChanged = false
        for y in 0 ..< height {
          for x in 0 ..< width {
            let point = points[y][x]
            if point.type == .gate {
              if point.areas.count == 1 {
                let gotNewTerminal = changeGateToArea(point: point)
                debug("> gate change: (\(x)/\(y)) -> \(point.type)")
                if gotNewTerminal {
                  // 新たな端点がつながった場合、統合のチェックからやり直し
                  areaChanged = true
                }
                gateChanged = true
              }
            }
          }
        }
        if areaChanged {
          continue areaChangedLoop
        }
      } // gateCheckLoop
      dump(title: "after remove gates")
      
    } // areaChangedLoop

    // エリアに接する端点とゲートの数で判定する
    for area in areas {
      let connectedCount = area.connectedAreas.count + area.connectedGates.count
      switch area.gates.count {
      case 0:
        if connectedCount % 2 == 1 {
          // エリアに接する外向け端点が奇数の場合エラー
          throw SolveException(reason: .failed)
        } else if connectedCount == 0 && area.terminals.count > 0 {
          // エリアに接する外向け端点が0で内部端点が存在する場合エラー
          throw SolveException(reason: .failed)
        }
      case 1:
        if connectedCount == 0 && area.terminals.count > 0 {
          // エリアに接する外向け端点が0で内部端点が存在する場合エラー
          throw SolveException(reason: .failed)
        }
        let gate = area.gates[0]
        var changed = false
        // 外向け端点の数に応じてゲート（につながるエッジ）のステータスが確定
        if connectedCount % 2 == 1 {
          changed = try changeGateStatus(of: gate, from: area, to: .on)
        } else {
          changed = try changeGateStatus(of: gate, from: area, to: .off)
        }
        if changed {
          dump(title: "after change gates")
          return true
        }
      default:
        break
      }
    }
    
    // TODO: 各ゲートをON、OFFに切り替えて見てエラーが起きないか？
    return false
  }
  
  /// 端点のチェックを行う
  ///
  /// - Parameters:
  ///   - terminal: 端点
  ///   - area: 端点の属するエリア
  /// - Returns: 端点の逆端が、他の端点の逆端と同じエリアになった場合のそのエリア
  private func checkTerminal(_ terminal: Point, area: Area) -> Area? {
    let oppNode = terminal.node.oppositeNode!
    let oppPoint = points[oppNode.y][oppNode.x]
    if oppPoint.type == .gate {
      if !area.connectedGates.contains(oppPoint) {
        area.connectedGates.append(oppPoint)
      }
    } else if oppPoint.areas.count == 1 {
      let oppArea = oppPoint.areas[0]
      if oppArea != area {
        if area.connectedAreas.contains(oppArea) {
          return oppArea
        } else {
          area.connectedAreas.append(oppArea)
        }
      }
    }
    return nil
  }
  
  /// ゲートをエリアに変換する
  ///
  /// - Parameter point: 対象のポイント
  /// - Returns: 新たな端点が発生した場合にtrue
  private func changeGateToArea(point: Point) -> Bool {
    var gotNewTerminal = false
    let area = point.areas[0]
    point.type = point.node.onCount == 0 ? .space : .terminal
    point.areas = [area]
    if point.type == .terminal {
      area.terminals.append(point)
      gotNewTerminal = true
    }
    if let index = area.gates.index(of: point) {
      area.gates.remove(at: index)
    }
    for nextPoint in point.nextPoints {
      if let nextPoint = nextPoint {
        switch nextPoint.type {
        case .gate:
          if !nextPoint.areas.contains(area) {
            nextPoint.areas.append(area)
            area.gates.append(nextPoint)
          }
        case .terminal:
          if !nextPoint.areas.contains(area) {
            nextPoint.areas.append(area)
            area.terminals.append(nextPoint)
            gotNewTerminal = true
          }
        default:
          break;
        }
      }
    }
    return gotNewTerminal
  }

  /// ゲート部の（エッジの）ステータスを変更する
  ///
  /// - Parameters:
  ///   - gate: ゲート
  ///   - area: エリア
  ///   - status: ステータス
  /// - Throws: 解の探索時例外
  private func changeGateStatus(of gate: Point, from area: Area, to status: EdgeStatus) throws -> Bool {
    var numAreas: [Int] = []
    var numOppAreas: [Int] = []
    for i in 0 ..< 4 {
      let point = gate.nextPoints[i]
      if let point = point {
        if point.areas.contains(area) {
          numAreas.append(i)
        } else {
          numOppAreas.append(i)
        }
      }
    }
    
    let node = gate.node
    if numAreas.count == 1 {
      // 1箇所でのみ接している場合そのエッジを指定のステータスに
      let edge: Edge
      switch numAreas[0] {
      case 0:
        edge = node.vEdges[0]
      case 1:
        edge = node.hEdges[0]
      case 2:
        edge = node.vEdges[1]
      default:
        edge = node.hEdges[1]
      }
      try solver.changeEdgeStatus(of: edge, to: status)
      print("> edge change: \(edge.id) -> \(status)")
      return true
    } else if numOppAreas.count == 1 {
      // 逆側が1箇所で接していれば、逆側のステータスを設定
      // nodeがterminalの場合、逆側の1本のstatusを目標statusと逆のstatusにすることで
      // 望みの状態が得られる
      let edge: Edge
      switch numOppAreas[0] {
      case 0:
        edge = node.vEdges[0]
      case 1:
        edge = node.hEdges[0]
      case 2:
        edge = node.vEdges[1]
      default:
        edge = node.hEdges[1]
      }
      let oppStatus = node.onCount > 0 ? status.otherStatus() : status
      try solver.changeEdgeStatus(of: edge, to: oppStatus)
      print("> edge change: \(edge.id) -> \(oppStatus)")
      return true
    } else {
      // 上記以外＝4エッジとも未定で、２つのエリアに2箇所ずつ接している
//      // そのノードのコーナーゲートを指定のステータスに応じた状態に
//      let h = gate.nextPoints[1]?.areas[0] === area ? 0 : 1
//      let v = gate.nextPoints[0]?.areas[0] === area ? 0 : 1
//      let dir = h == v ? 0 : 1
//      let gateStatus: GateStatus = status == .on ? .open : .close
//      if try solver.setGateStatus(of: node, dir: dir, to: gateStatus) {
//        print("> corner gate change: \(node.id)-\(dir) -> \(gateStatus)")
//        solver.currentStep.gateCheckCells.insert(node.hEdges[h].cells[v])
//        solver.currentStep.gateCheckCells.insert(node.hEdges[1-h].cells[1-v])
//        return true
//      }
//       4エッジとも未定なのでエッジのfillは行わない
      return false
    }
  }
  
  /// 2つのエリアを1つに統合する
  ///
  /// - Parameters:
  ///   - to: 統合後に残るエリア
  ///   - from: 統合により消えるエリア
  private func mergeAreas(to: Area, from: Area) {
    for y in 0 ..< height {
      for x in 0 ..< width {
        let point = points[y][x]
        for i in 0 ..< point.areas.count {
          if point.areas[i] === from {
            point.areas[i] = to
          }
        }
      }
    }
    to.gates.append(contentsOf: from.gates)
    to.terminals.append(contentsOf: from.terminals)
    areas.remove(at: areas.index(of: from)!)
  }
  
  /// エリアチェックの状況を出力する
  ///
  /// - Parameter title: タイトル文字列
  public func dump(title: String) {
    if !debug {
      return
    }
    print(title)
    let board = solver.board
    var line = ""
    for y in 0 ..< height - 1 {
      line = ""
      for x in 0 ..< width - 1 {
        let point = points[y][x]
        line += pointChar(of: point) + board.hEdgeChar(of: point.node.hEdges[1])
      }
      line += pointChar(of: points[y][width - 1])
      print(line)
      
      line = " "
      for x in 0 ..< width - 1 {
        let point = points[y][x]
        line += board.vEdgeChar(of: point.node.vEdges[1]) + "  "
      }
      line += board.vEdgeChar(of: points[y][width - 1].node.vEdges[1])
      print(line)
    }
    
    line = ""
    for x in 0 ..< width - 1 {
      let point = points[height - 1][x]
      line += pointChar(of: point) + board.hEdgeChar(of: point.node.hEdges[1])
    }
    line += pointChar(of: points[height - 1][width - 1])
    print(line)
    
    for area in areas {
      print("area\(area.id)")
      var terminals = ""
      for terminal in area.terminals {
        terminals += "(\(terminal.node.x)/\(terminal.node.y)),"
      }
      print(" terminal:\(terminals)")
      
      var gates = ""
      for gate in area.gates {
        gates += "(\(gate.node.x)/\(gate.node.y)),"
      }
      print(" gate:\(gates)")
    }
    print()
  }
  
  /// ポイントの状態を表す文字列を返す
  ///
  /// - Parameter point: 対象のポイント
  /// - Returns: 2文字の文字列
  func pointChar(of point: Point) -> String {
    switch point.type {
    case .space, .terminal:
      return point.areas.count > 0 ? String(format: "%2d", point.areas[0].id) : " +"
    case .wall:
      return " W"
    case .gate:
      return " G"
    }
  }
  
  /// デバッグ時のみ出力する
  ///
  /// - Parameter obj: 出力内容
  public func debug(_ obj: Any) {
    if debug {
      print(obj)
    }
  }
}

