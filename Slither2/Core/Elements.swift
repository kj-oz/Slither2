//
//  Elements.swift
//  Slither
//
//  Created by KO on 2018/09/20.
//  Copyright © 2018年 KO. All rights reserved.
//

import Foundation

/// Edgeの状態
///
/// - unset: 未設定
/// - off: 線無し
/// - on: 線有り
enum EdgeStatus: Int {
  case unset
  case off
  case on
  
  /// 逆の状態を返す
  ///
  /// - Returns: 自分自身と逆の状態（OnならOff、OffならOn）
  func otherStatus() -> EdgeStatus {
    switch self {
    case .on:
      return .off
    case .off:
      return .on
    default:
      return .unset
    }
  }
  
  /// 保存用の文字列を返す
  ///
  /// - Returns: 保存用の文字列を
  func toString() -> String {
    switch self {
    case .on:
      return "ON"
    case .off:
      return "OFF"
    default:
      return "CLR"
    }
  }
  
  
  /// 文字列から状態を得る
  ///
  /// - Parameter str: 文字列
  /// - Returns: Edgeの状態
  static func fromString(_ str: String) -> EdgeStatus {
    switch str {
    case "ON":
      return .on
    case "OFF":
      return .off
    default:
      return .unset
    }
  }
}


/// Cellの色（中か外か）
///
/// - unset: 未設定
/// - inner: 中
/// - outer: 外
enum CellColor: Int {
  case unset
  case inner
  case outer
  
  /// 逆の色を返す
  ///
  /// - Returns: 自分自身と逆の色（中なら外、外なら中）
  func otherColor() -> CellColor {
    switch self {
    case .inner:
      return .outer
    case .outer:
      return .inner
    default:
      return .unset
    }
  }
}


/// NodeのGate（斜め方向のOnEdgeの通過状態）の状態
///
/// - unset: 未設定
/// - close: 不通過
/// - open: 通過
enum GateStatus: Int {
  case unset
  case close
  case open
}


/// Loop（一繋がりのEdge）の状態
///
/// - NotClosed: 1本のループになっていない
/// - CellError: 1本のループだがセルの数値と合致しない
/// - NodeError: 1本のループだがノードのON数が0か2ではない
/// - MultiLoop: 全てのセルの数値を満たしているが複数のループがある
/// - Finished: 1本のループでなおかつ全てのセルの数値を満たしている
enum LoopStatus {
  case notClosed
  case cellError(errorElements: [Element])
  case nodeError(errorElements: [Element])
  case multiLoop(errorElements: [Element])
  case finished
}

/// 要素の種別（ハッシュを求める際に使用）
///
/// - none: 未定
/// - node: ノード
/// - cell: セル
/// - hEdge: 水平のエッジ
/// - vEdge: 垂直のエッジ
enum ElementType: Int {
  case none
  case node
  case cell
  case hEdge
  case vEdge
}

/// 全要素の親クラス
class Element : Hashable {
  var elementType = ElementType.none
  
  /// 文字列表現
  var id = ""
  
  /// (Hashable)
  func hash(into hasher: inout Hasher) {
    let node = hashNode
    let val = elementType.rawValue << 16 + node.x << 8 + node.y
    val.hash(into: &hasher)
  }
  
  /// (Hashable)
  static func == (lhs: Element, rhs: Element) -> Bool {
    return lhs === rhs
  }
  
  /// ハッシュを求めるためののノード（左上のノード）
  var hashNode: Node {
    return Node(x: 0, y: 0)
  }
}


/// Cellの状態を表すクラス
class Cell : Element {
  
  override var hashNode: Node {
    return vEdges[0].nodes[0]
  }
    
  /// 中の数値、空の場合は-1
  var number: Int
  
  /// 四周Edgeの中のOnのEdgeの数
  var onCount = 0
  
  /// 四周Edgeの中のOffのEdgeの数
  var offCount = 0
  
  /// 色（中か外か）
  var color: CellColor = .unset
  
  /// 水平方向のEdgeの配列
  var hEdges: [Edge] = []
  
  /// 垂直方向のEdgeの配列
  var vEdges: [Edge] = []
  
  /// 四周Edgeの配列
  var edges: [Edge] = []
  
  /// BoardのCell配列内のインデックス
  var index = -1

  /// 指定の数値でCellを初期化する
  ///
  /// - Parameters:
  ///   - number: 中の数値
  ///   - x: X方向位置
  ///   - y: Y方向位置
  init(number: Int, x: Int, y: Int) {
    self.number = number
    super.init()
    elementType = .cell
    id = String(format: "C%02d%02d", x, y)
  }
  
  /// 与えられたEdgeの対辺のEdgeを得る
  ///
  /// - Parameter edge: Edge
  /// - Returns: 対辺のEdge
  func oppsiteEdge(of edge: Edge) -> Edge? {
    if edge === hEdges[0] {
      return hEdges[1]
    } else if edge === vEdges[0] {
      return vEdges[1]
    } else if edge === hEdges[1] {
      return hEdges[0]
    } else if edge === vEdges[1] {
      return vEdges[0]
    }
    return nil
  }
  
  /// 初期状態に戻す
  func clear() {
    onCount = 0
    offCount = 0
    color = .unset
  }
}


/// Nodeの状態を表すクラス
class Node : Element {

  override var hashNode: Node {
    return self
  }

  /// X座標
  let x: Int
  
  /// Y座標
  let y: Int
  
  /// 接続する4本のEdgeの中の状態がOnのEdgeの数
  var onCount = 0
  
  /// 接続する4本のEdgeの中の状態がOffのEdgeの数
  var offCount = 0
  
  /// 接続する4本のEdgeの中の状態がUnsetのEdgeの数
  var unsetCount: Int {
    return 4 - onCount - offCount
  }
  
  /// 自身が連続線の端点の場合の逆側の端点のNode
  var oppositeNode: Node?
  
  /// 水平方向のEdgeの配列
  var hEdges: [Edge] = []
  
  /// 垂直方向のEdgeの配列
  var vEdges: [Edge] = []
  
  ///　接続する4本のEdgの配列
  var edges: [Edge] = []

  /// BoardのNode配列内のインデックス
  var index = -1

  /// 斜め方向の2つのCellの接するNodeにおけるEdgeの通過状態
  var gateStatus: [GateStatus] = [.unset, .unset]
  
  /// 指定の位置で初期化したNodeを生成する
  ///
  /// - Parameters:
  ///   - x: X座標
  ///   - y: Y座標
  init(x: Int, y: Int) {
    self.x = x
    self.y = y
    super.init()
    elementType = .node
    id = String(format: "N%02d%02d", x, y)
  }

  /// 与えられたOnのEdgeに接続するもう1本のOnのEdgeを返す
  ///
  /// - Parameter edge: 与えられたOnのEdge
  /// - Returns: 接続するOnのEdge
  func onEdge(connectTo edge: Edge) -> Edge? {
    if vEdges[0].status == .on && vEdges[0] !== edge {
      return vEdges[0]
    } else if hEdges[0].status == .on && hEdges[0] !== edge {
      return hEdges[0]
    } else if vEdges[1].status == .on && vEdges[1] !== edge {
      return vEdges[1]
    } else if hEdges[1].status == .on && hEdges[1] !== edge {
      return hEdges[1]
    }
    return nil
  }
  
  /// 初期状態に戻す
  func clear() {
    onCount = 0
    offCount = 0
    oppositeNode = nil
    gateStatus = [.unset, .unset]
  }
}


/// Edgeを表すクラス
class Edge : Element {
  
  override var hashNode: Node {
    return nodes[0]
  }
  
  /// 状態
  var _status: EdgeStatus = .unset
  var status: EdgeStatus {
    get {
      return _status
    }
    set {
      if _status == newValue {
        return
      }
      
      // print("\(id) ⇒ \(newValue):")
      if _status == .on {
        nodes[0].onCount -= 1
        nodes[1].onCount -= 1
        cells[0].onCount -= 1
        cells[1].onCount -= 1
      } else if _status == .off {
        nodes[0].offCount -= 1
        nodes[1].offCount -= 1
        cells[0].offCount -= 1
        cells[1].offCount -= 1
      }
      
      if newValue == .on {
        nodes[0].onCount += 1
        nodes[1].onCount += 1
        cells[0].onCount += 1
        cells[1].onCount += 1
      } else if newValue == .off {
        nodes[0].offCount += 1
        nodes[1].offCount += 1
        cells[0].offCount += 1
        cells[1].offCount += 1
      }
      _status = newValue
    }
  }
  
  /// 水平なEdgeかどうか
  var horizontal: Bool
  
  /// 左右のCell
  var cells: [Cell] = []
  
  /// 前後のNode
  var nodes: [Node] = []
  
  /// 前後の延長上のEdge
  var straightEdges: [Edge] = []

  ///　BoardのEdge配列内のインデックス
  var index = -1

  ///　固定されているかどうか（Play時のみ使用）
  var fixed = false
  
  /// 水平かどうかを指定してEdgeを生成する
  ///
  /// - Parameters:
  ///   - horizontal: 水平かどうか
  ///   - x: 始点のX座標
  ///   - y: 始点のY座標
  init(horizontal: Bool, x: Int, y: Int) {
    self.horizontal = horizontal
    let dir = horizontal ? "H" : "V"
    super.init()
    elementType = horizontal ? .hEdge : .vEdge
    id = String(format: "%@%02d%02d", dir, x, y)
  }
  
  /// 与えられたNodeの逆端のNodeを返す
  ///
  /// - Parameter node: 端部のNode
  /// - Returns: 逆端のNode
  func anotherNode(of node: Node) -> Node {
    return (nodes[0] === node) ? nodes[1] : nodes[0]
  }
  
  /// 与えられたCellの逆側のCellを返す
  ///
  /// - Parameter cell: 片側のセル
  /// - Returns: 逆側のセル
  func oppositeCell(of cell: Cell) -> Cell {
    return (cells[0] === cell) ? cells[1] : cells[0]
  }

  /// 初期状態に戻す
  func clear() {
    _status = .unset
    fixed = false
  }
}
