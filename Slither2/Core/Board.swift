//
//  Board.swift
//  Slither
//
//  Created by KO on 2018/09/22.
//  Copyright © 2018年 KO. All rights reserved.
//

import Foundation
import UIKit

/// Boardを表すクラス
class Board {
  /// 幅（水平方向のCellの数）
  let width: Int
  
  /// 高さ（鉛直方向のCellの数）
  let height: Int
  
  /// Cellの配列
  var cells: [Cell] = []
  
  /// Nodeの配列
  var nodes: [Node] = []
  
  /// 水平方向Edgeの配列
  var hEdges: [Edge] = []
  
  /// 鉛直方向Edgeの配列
  var vEdges: [Edge] = []
  
  /// 両方向Edgeの配列
  var edges: [Edge] = []
  
  /// 数字のみの配列
  var numbers: [Int] {
    return cells.map({ $0.number })
  }
  
  /// onEdgeの数
  var onEdgeCount: Int {
    var onCount = 0
    for edge in edges {
      if edge.status == .on {
        onCount += 1
      }
    }
    return onCount
  }
  
  /// 出来上がったループ
  var loop: [Edge] {
    var route: [Edge] = []
    var edge = findOnEdge()!
    let root = edge.nodes[0]
    var node = edge.nodes[1]
    route.append(edge)
    while node !== root {
      edge = node.onEdge(connectTo: edge)!
      route.append(edge)
      
      node = edge.anotherNode(of: node)
    }
    return route
  }

  /// 与えられた問題で盤面を初期化する
  ///
  /// - Parameters:
  ///   - width: 幅
  ///   - height: 高さ
  ///   - numbers: セルの数字の配列
  init(width: Int, height: Int, numbers: [Int]) {
    self.width = width
    self.height = height
    
    createElemnts(numbers: numbers)
  }
  
  /// 与えられた問題で盤面を初期化する
  ///
  /// - Parameter lines: 問題の文字列
  init(lines: [String]) {
    let lineCount = lines.count
    let sizes = lines[0].components(separatedBy: .whitespaces)
    self.width = Int(sizes[0])!
    self.height = Int(sizes[1])!
    var numbers: [Int] = []
    for i in 1 ..< lineCount {
      let line = lines[i]
      for char in line {
        numbers.append(char == " " ? -1 : Int(String(char))!);
      }
    }
    
    createElemnts(numbers: numbers)
  }
  
  /// 指定の位置のCellを返す
  ///
  /// - Parameters:
  ///   - x: X座標
  ///   - y: Y座標
  /// - Returns: 指定の位置のCell
  func cellAt(x: Int, y: Int) -> Cell {
    return cells[y * width + x]
  }
  
  /// 指定の位置のNodeを返す
  ///
  /// - Parameters:
  ///   - x: X座標
  ///   - y: Y座標
  /// - Returns: 指定の位置のNode
  func nodeAt(x: Int, y: Int) -> Node {
    return nodes[y * (width + 1) + x]
  }
  
  /// 指定の位置の水平方向のEdgeを返す
  ///
  /// - Parameters:
  ///   - x: X座標
  ///   - y: Y座標
  /// - Returns: 指定の位置の水平方向のEdge
  func hEdgeAt(x: Int, y: Int) -> Edge {
    return hEdges[y * width + x]
  }
  
  /// 指定の位置の鉛直方向のEdgeを返す
  ///
  /// - Parameters:
  ///   - x: X座標
  ///   - y: Y座標
  /// - Returns: 指定の位置の鉛直方向のEdge
  func vEdgeAt(x: Int, y: Int) -> Edge {
    return vEdges[y * (width + 1) + x]
  }
  
  /// 開いた（onCountが1の）Nodeを返す
  ///
  /// - Returns: 最初に見つかった開いたNode
  func findOpenNode() -> Node? {
    for node in nodes {
      if node.onCount == 1 {
        return node
      }
    }
    return nil
  }
  
  /// 分岐用の（onCountが番号-1の）Cellを返す
  ///
  /// - Returns: 最初に見つかった分岐用のCell
  func findCellForBranch() -> Cell? {
    for n in [3, 2, 1] {
      for cell in cells {
        if cell.number == n && cell.onCount == n - 1 {
          return cell
        }
      }
    }
    return nil
  }
  
  /// 開いた（onCountが番号より小さい）Cellを返す
  ///
  /// - Returns: 最初に見つかった開いたCell
  func findOpenCell() -> Cell? {
    for cell in cells {
      if cell.number > 0 && cell.number != cell.onCount {
        return cell
      }
    }
    return nil
  }
  
  /// 状態がOnのEdgeを返す
  ///
  /// - Returns: 最初に見つかったOnのEdge
  func findOnEdge() -> Edge? {
    for edge in edges {
      if edge.status == .on {
        return edge
      }
    }
    return nil
  }
  
  /// 指定した斜め方向に任意の数の2のCellを挟んで3のCellが続いている場合にその3のCellを返す
  ///
  /// - Parameters:
  ///   - from: 現在検討中のCell
  ///   - h: 水平方向（0:左、1:右）
  ///   - v: 鉛直方向（0:上、1:下）
  /// - Returns: 任意の数の2のCellの向こうに3のCellが見つかった場合にその3のCell、見つからなければnil
  func getC3AcrossC2(from: Cell, h: Int, v: Int) -> Cell? {
    var cell = from
    while true {
      cell = cell.vEdges[h].straightEdges[v].cells[h]
      if cell.number != 2 {
        return cell.number == 3 ? cell : nil
      }
    }
  }
  
  /// 与えれた2つのNodeを結ぶEdgeが存在すればそれを返す
  ///
  /// - Parameters:
  ///   - node1: Node1
  ///   - node2: Node2
  /// - Returns: 2つのNodeを結ぶEdge、存在しなければnil
  func getJointEdge(of node1: Node, and node2: Node) -> Edge? {
    let x1 = node1.x
    let y1 = node1.y
    let x2 = node2.x
    let y2 = node2.y
    if x1 == x2 && abs(y1 - y2) == 1 {
      return vEdgeAt(x: x1, y: min(y1, y2))
    } else if y1 == y2 && abs(x1 - x2) == 1 {
      return hEdgeAt(x: min(x1, x2), y: y1)
    }
    return nil
  }
  
  /// 与えられたNodeからEdge方向に発する連続線の末端のNodeを見つける
  ///
  /// - Parameters:
  ///   - node: 探索元のNode
  ///   - edge: 最初の方向のEdge
  /// - Returns: 連続線のedgeから見てnodeと逆側の末端のNode、連続線が閉じている場合にはnil
  func getLoopEnd(from node: Node, and edge: Edge) -> (Node?, [Edge]) {
    var loop : [Edge] = [edge]
    var nd = edge.anotherNode(of: node)
    var ed = edge
    while nd.onCount == 2 {
      ed = nd.onEdge(connectTo: ed)!
      loop.append(ed)
      nd = ed.anotherNode(of: nd)
      
      if nd === node {
        return (nil, loop)
      }
      if loop.count == edges.count {
        // 無限ループ防止
        return (nil, loop)
      }
    }
    return (nd, loop)
  }
  
  /// 文字で盤面を出力する
  ///
  /// - Returns: 盤面を表現する文字列の配列
  func dump() -> [String] {
    var result: [String] = []
    var line = ""
    for y in 0 ..< height {
      line = ""
      for x in 0 ..< width {
        line += "+ " + hEdgeChar(of: hEdgeAt(x: x, y: y))
      }
      line += "+"
      result.append(line)
      
      line = ""
      for x in 0 ..< width {
        line += vEdgeChar(of: vEdgeAt(x: x, y: y))
        let cell = cellAt(x: x, y: y)
        line += " " + (cell.number >= 0 ? String(cell.number) : " ")
      }
      line += vEdgeChar(of: vEdgeAt(x: width, y: y))
      result.append(line)
    }
    
    line = ""
    for x in 0 ..< width {
      line += "+ " + hEdgeChar(of: hEdgeAt(x: x, y: height))
    }
    line += "+"
    result.append(line)
    return result
  }
  
  /// 与えられた大きさの画像として出力する
  ///
  /// - Parameters:
  ///   - width: 画像の幅
  ///   - height: 画像の高さ
  /// - Returns: 盤面を表現する画像
  func createImage(width: Int, height: Int) -> UIImage {
    //TODO
    return UIImage(contentsOfFile: "")!
  }
  
  /// 盤面を構成する各要素を構築する
  ///
  /// - Parameter numbers: Cellの数字の定義
  private func createElemnts(numbers: [Int]) {
    let dummyNode = Node(x: -1, y: -1)
    let dummyEdge = Edge(horizontal: false, x: -1, y: -1)
    let dummyCell = Cell(number: -1, x: -1, y: -1)
    dummyEdge._status = .off
    dummyCell.color = .outer

    var index = 0
    for y in 0 ..< height {
      for x in 0 ..< width {
        let cell = Cell(number: numbers[index], x: x, y: y)
        cell.vEdges = [dummyEdge, dummyEdge]
        cell.hEdges = [dummyEdge, dummyEdge]
        cell.index = index
        cells.append(cell)
        index += 1
      }
    }
    
    index = 0
    for y in 0 ... height {
      for x in 0 ... width {
        let node = Node(x: x, y: y)
        node.vEdges = [dummyEdge, dummyEdge]
        node.hEdges = [dummyEdge, dummyEdge]
        node.index = index
        nodes.append(node)
        index += 1
      }
    }

    index = 0
    for y in 0 ... height {
      for x in 0 ..< width {
        let edge = Edge(horizontal: true, x: x, y: y)
        edge.cells = [dummyCell, dummyCell]
        edge.nodes = [dummyNode, dummyNode]
        edge.straightEdges = [dummyEdge, dummyEdge]
        edge.index = index
        hEdges.append(edge)
        index += 1
      }
    }

    for y in 0 ..< height {
      for x in 0 ... width {
        let edge = Edge(horizontal: false, x: x, y: y)
        edge.cells = [dummyCell, dummyCell]
        edge.nodes = [dummyNode, dummyNode]
        edge.straightEdges = [dummyEdge, dummyEdge]
        edge.index = index
        vEdges.append(edge)
        index += 1
      }
    }
    
    edges = hEdges + vEdges

    connectElements()
    
    // connectの中で何らかの実要素が設定された場合でも大丈夫なようにダミー同士の接続は後から設定
    dummyCell.vEdges = [dummyEdge, dummyEdge]
    dummyCell.hEdges = [dummyEdge, dummyEdge]
    dummyEdge.cells = [dummyCell, dummyCell]
    dummyEdge.nodes = [dummyNode, dummyNode]
    dummyEdge.straightEdges = [dummyEdge, dummyEdge]
    dummyNode.vEdges = [dummyEdge, dummyEdge]
    dummyNode.hEdges = [dummyEdge, dummyEdge]
  }
  
  /// 盤面の各要素を接続する
  private func connectElements() {
    
    for y in 0 ..< height {
      for x in 0 ..< width {
        let cell = cells[y * width + x]
        let topEdge = hEdges[y * width + x]
        let bottomEdge = hEdges[(y + 1) *  width + x]
        let leftEdge = vEdges[y * (width + 1) + x]
        let rightEdge = vEdges[y * (width + 1) + x + 1]
        
        cell.hEdges[0] = topEdge
        topEdge.cells[1] = cell
        
        cell.hEdges[1] = bottomEdge
        bottomEdge.cells[0] = cell
        
        cell.vEdges[0] = leftEdge
        leftEdge.cells[1] = cell
        
        cell.vEdges[1] = rightEdge
        rightEdge.cells[0] = cell
        
        cell.edges = [topEdge, leftEdge, bottomEdge, rightEdge]
      }
    }
    
    for y in 0 ... height {
      for x in 0 ... width {
        let node = nodes[y * (width + 1) + x]
        
        if x == 0 {
          node.offCount += 1
        } else {
          let edge = hEdges[y * width + x - 1]
          node.hEdges[0] = edge
          edge.nodes[1] = node
        }
        
        if x ==  width {
           node.offCount += 1
        } else {
          let edge = hEdges[y * width + x]
          node.hEdges[1] = edge
          edge.nodes[0] = node
        }
        
        if y == 0 {
          node.offCount += 1
        } else {
          let edge =  vEdges[(y - 1) * (width + 1) + x]
          node.vEdges[0] = edge
          edge.nodes[1] = node
        }
        
        if y ==  height {
          node.offCount += 1
        } else {
          let edge = vEdges[y * (width + 1) + x]
          node.vEdges[1] = edge
          edge.nodes[0] = node
        }
        
        node.edges = [node.vEdges[0], node.hEdges[0],
                      node.vEdges[1], node.hEdges[1]]
      }
    }
    
    for y in 0 ... height {
      for x in 0 ..< width {
        let edge = hEdges[y * width + x]
        edge.straightEdges[0] = edge.nodes[0].hEdges[0]
        edge.straightEdges[1] = edge.nodes[1].hEdges[1]
      }
    }
    
    for y in 0 ..< height {
      for x in 0 ... width {
        let edge = vEdges[y * (width + 1) + x]
        edge.straightEdges[0] = edge.nodes[0].vEdges[0]
        edge.straightEdges[1] = edge.nodes[1].vEdges[1]
      }
    }
  }
  
  ///　盤面の状態を初期化する
  func clear() {
    for node in nodes {
      node.clear()
    }
    
    for cell in cells {
      cell.clear()
    }
    
    for edge in edges {
      edge.clear()
    }
  }
  
  ///　全ての状態設定済みのEdgeの状態を固定する
  func fixStatus() {
    for edge in edges {
      if edge.status != .unset {
        edge.fixed = true
      }
    }
  }

  /// 与えられたEdgeが含まれているループの状態を得る
  ///
  /// - Parameter edge: Edge
  /// - Returns: ループの状態
  func getLoopStatus(including edge: Edge) -> LoopStatus {
    if let cell = findOpenCell() {
      return .cellError(errorElements: [cell])
    }

    let root = edge.nodes[0]
    var node = edge.nodes[1]
    var ed: Edge? = edge
    var conCount = 1
    while node !== root {
      ed = node.onEdge(connectTo: ed!)
      if ed == nil {
        return .notClosed
      }
      conCount += 1
      if conCount > onEdgeCount {
        return .multiLoop(errorElements: [])
      }
      node = ed!.anotherNode(of: node)
    }
    
    return conCount == onEdgeCount ? .finished : .multiLoop(errorElements: [])
  }
  
  /// ループの状態に不正な状態がないかどうかを調べる
  ///
  /// - Parameter finished: ループが完成した（つもり）かどうか
  /// - Returns: ループの状態
  func check(finished: Bool) -> LoopStatus {
    if let errors = checkNodes(finished: finished) {
      return .nodeError(errorElements: errors)
    }
    
    if let errors = checkCells(finished: finished) {
      return .cellError(errorElements: errors)
    }
    
    if finished {
      // ループのチェックはノードの状態が正しいことが前提
      if let errors = checkEdges() {
        return .multiLoop(errorElements: errors)
      }
    }
    return .finished
  }
  
  /// すべてのノードの状態が正しい（onCountが０か２）かどうかを調べる
  ///
  /// - Parameter finished: ループが完成した（つもり）かどうか
  /// - Returns: 正しくない要素
  private func checkNodes(finished: Bool) -> [Element]? {
    var result: [Element] = []
    for node in nodes {
      if ((finished || node.offCount == 3) && node.onCount == 1) || node.onCount == 3 {
        result.append(node)
        for edge in node.edges {
          if edge.status == .on {
            result.append(edge)
          }
        }
      }
    }
    return result.count > 0 ? result : nil
  }
  
  /// すべてのセルの状態が正しい（onCountが中の数字と一致している）かどうかを調べる
  ///
  /// - Parameter finished: ループが完成した（つもり）かどうか
  /// - Returns: 正しくない要素
  private func checkCells(finished: Bool) -> [Element]? {
    var result: [Element] = []
    for cell in cells {
      if cell.number >= 0 &&
          ((finished && cell.onCount < cell.number) || cell.onCount > cell.number
            || cell.offCount > 4 - cell.number) {
        result.append(cell)
        for edge in cell.edges {
          if edge.status == .on {
            result.append(edge)
          }
        }
      }
    }
    return result.count > 0 ? result : nil
  }
  
  /// ループが1つの閉じたループだけになっているかをチェックする
  ///
  /// - Returns: 何かしらの瑕疵が見つかったかどうか
  private func checkEdges() -> [Element]? {
    var loops: [[Edge]] = []
    var result: [Element] = []

    edge_loop: for edge in edges {
      if edge.status == .on {
        for loop in loops {
          if loop.contains(edge) {
            continue edge_loop
          }
        }
        
        var newLoop: [Edge] = [edge]
        let root = edge.nodes[0]
        var node = edge.nodes[1]
        var ed: Edge? = edge
        while node !== root {
          ed = node.onEdge(connectTo: ed!)
          if ed == nil {
            break
          }
          if newLoop.contains(ed!) {
            break
          }
          newLoop.append(ed!)
          node = ed!.anotherNode(of: node)
        }
        loops.append(newLoop)
      }
    }
    
    if loops.count > 1 {
      loops.sort(by: { a, b in  a.count > b.count })
      loops.remove(at: 0)
      for loop in loops {
        result.append(contentsOf: loop)
      }
      return result
    }
    return nil
  }
  
  /// 水平方向のEdgeを表す状態に応じた文字を得る
  ///
  /// - Parameter edge: Edge
  /// - Returns: 状態に応じた文字
  func hEdgeChar(of edge: Edge) -> String {
    switch edge.status {
    case .unset: return " "
    case .on: return "-"
    case .off: return "x"
    }
  }
  
  /// 垂直方向のEdgeを表す状態に応じた文字を得る
  ///
  /// - Parameter edge: Edge
  /// - Returns: 状態に応じた文字
  func vEdgeChar(of edge: Edge) -> String {
    switch edge.status {
    case .unset: return " "
    case .on: return "|"
    case .off: return "x"
    }
  }

  /// 水平方向のEdgeを表す状態に応じた文字を得る
  ///
  /// - Parameter char: 文字
  /// - Returns: 状態
  func hEdgeStatus(of char: Character) -> EdgeStatus {
    switch char {
    case "-": return .on
    case "x", "X": return .off
    default: return .unset
    }
  }
  
  /// 垂直方向のEdgeを表す状態に応じた文字を得る
  ///
  /// - Parameter edge: Edge
  /// - Returns: 状態に応じた文字
  func vEdgeStatus(of char: Character) -> EdgeStatus {
    switch char {
    case "|": return .on
    case "x", "X": return .off
    default: return .unset
    }
  }
}


