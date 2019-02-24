//
//  Action.swift
//  Slither
//
//  Created by KO on 2018/09/28.
//  Copyright © 2018年 KO. All rights reserved.
//

import Foundation

/// undo可能な操作
protocol Action {
  /// 操作を行う
  func redo()
  /// 操作を取り消す
  func undo()
}

/// エッジの状態の変更
struct SetEdgeStatusAction : Action {
  
  /// 対象のエッジ
  let edge: Edge
  
  /// 変更前の状態
  let oldStatus: EdgeStatus
  
  /// 変更後の状態
  var newStatus: EdgeStatus
  
  /// 指定のエッジの状態を指定の状態に変更する
  init(edge: Edge, status: EdgeStatus) {
    self.edge = edge
    self.newStatus = status
    self.oldStatus = edge.status
  }
  
  /// 取り消した操作を再度実行する
  func redo() {
    edge.status = newStatus
    //debug(" - \(edge.id) -> \(status)")
  }
  
  /// 操作を取り消す
  func undo() {
    edge.status = oldStatus
    //debug(" - \(edge.id) -> unset")
  }
}

/// ループの逆端のノードを設定する
struct SetOppositeNodeAction : Action {
  
  /// 対象のノード
  let node: Node
  
  /// 変更前の逆端ノード
  let oldOppNode: Node?
  
  /// 変更後の逆端ノード
  var newOppNode: Node?
  
  /// 指定のノードの逆端ノードを指定の値に変更する
  ///
  /// - Parameters:
  ///   - node: 対象のノード
  ///   - oppositeNode: 変更後の逆端ノード
  init(node: Node, oppositeNode: Node?) {
    self.node = node
    self.newOppNode = oppositeNode
    self.oldOppNode = node.oppositeNode
  }
  
  /// 取り消した操作を再度実行する
  func redo() {
    node.oppositeNode = newOppNode
  }
  
  /// 操作を取り消す
  func undo() {
    node.oppositeNode = oldOppNode
  }
}

/// セルのコーナーのゲートの状態の変更
struct SetGateStatusAction : Action {
  
  /// 対象のノード
  let node: Node
  
  /// 方向（左上がり：0、右上がり：1）
  let dir: Int
  
  /// 変更前の状態
  let oldStatus: GateStatus
  
  /// 変更後の状態
  var newStatus: GateStatus
  
  /// 指定のノードの指定の方向のゲートの状態を指定の状態に変更する
  ///
  /// - Parameters:
  ///   - node: ノード
  ///   - dir: 方向
  ///   - status: 変更後の状態
  init(node: Node, dir: Int, status: GateStatus) {
    self.node = node
    self.dir = dir
    self.newStatus = status
    self.oldStatus = node.gateStatus[dir]
  }
  
  /// 取り消した操作を再度実行する
  func redo() {
    node.gateStatus[dir] = newStatus
  }
  
  /// 操作を取り消す
  func undo() {
    node.gateStatus[dir] = oldStatus
  }
}

/// セルの色（ループの内部、外部）の変更
struct SetCellColorAction : Action {
  
  /// 対象のセル
  let cell: Cell
  
  let oldColor: CellColor
  
  /// 変更後のセルの色
  var newColor: CellColor
  
  /// 指定のセルの色を指定の値に変更する
  ///
  /// - Parameters:
  ///   - cell: 対象のセル
  ///   - color: 変更後のセルの色
  init(cell: Cell, color: CellColor) {
    self.cell = cell
    self.newColor = color
    self.oldColor = cell.color
  }
  
  /// 取り消した操作を再度実行する
  func redo() {
    cell.color = newColor
  }
  
  /// 操作を取り消す
  func undo() {
    cell.color = .unset
  }
}

/// セルの数字の変更
struct SetCellNumberAction : Action {
  
  /// 対象のセル
  let cell: Cell
  
  let oldNumber: Int
  
  /// 変更後のセルの数字
  var newNumber: Int
  
  /// 指定のセルの数字を指定の値に変更する
  ///
  /// - Parameters:
  ///   - cell: 対象のセル
  ///   - number: 変更後のセルの数字
  init(cell: Cell, number: Int) {
    self.cell = cell
    self.newNumber = number
    oldNumber = cell.number
  }
  
  /// 取り消した操作を再度実行する
  func redo() {
    cell.number = newNumber
  }
  
  /// 操作を取り消す
  func undo() {
    cell.number = oldNumber
  }
}

