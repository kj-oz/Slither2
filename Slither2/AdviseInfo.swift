//
//  AdviseInfo.swift
//  Slither2
//
//  Created by KO on 2019/08/28.
//  Copyright © 2019 KO. All rights reserved.
//

import Foundation
import UIKit

class AdviseInfo {
  static let mainColor = UIColor.red
  static let adviseColor = UIColor(red: 0.2, green: 1.0, blue: 0.0, alpha: 1.0)
  static let relatedColor = UIColor.orange
  static let innerColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.1)
  static let outerColor = UIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.1)

  var message = ""
  var reasonIndex = -1
  var reasonLabel = ""
  var fixLabel = ""
  var board: Board?
  
  struct Style {
    let color: UIColor
    let showGate: Bool
    let enlargeNode: Bool
    let showCellColor: Bool
    let showEmptyElement: Bool
    let emptyEdgeStatus: EdgeStatus
    
    init(color: UIColor, showGate: Bool = false, enlargeNode: Bool = true,
         showCellColor: Bool = false, showEmptyElement: Bool = false, emptyEdgeStatus: EdgeStatus = .unset) {
      self.color = color
      self.showGate = showGate
      self.enlargeNode = enlargeNode
      self.showCellColor = showCellColor
      self.showEmptyElement = showEmptyElement
      self.emptyEdgeStatus = emptyEdgeStatus
    }
  }
  
  func style(of element: Element) -> Style? {
    return nil
  }
  
  func showReason() {
    self.reasonIndex = 0
  }
  
  func fix(to puzzle: Puzzle) {
  }
}

/// ループが閉じたタイミングで行う回答チェックの結果を表示
class CheckResultAdviseInfo : AdviseInfo {
  var checked: Set<Element> = []
  
  init(_ checked: [Element]) {
    self.checked = Set<Element>(checked)
  }
  
  override func style(of element: Element) -> Style? {
    if checked.contains(element) {
      return Style(color: AdviseInfo.mainColor)
    }
    return nil
  }
}

/// ユーザーの実施手順に誤りがあったことを通知
class MistakeAdviseInfo : AdviseInfo {
  var mistakeEdge: Edge
  var followingEdges: Set<Edge>
  var safeIndex: Int
  
  init(puzzle: Puzzle, index: Int) {
    safeIndex = index - 1
    mistakeEdge = puzzle.actions[index].edge
    followingEdges = Set<Edge>()
    for i in index + 1 ..< puzzle.actions.count {
      let action = puzzle.actions[i]
      if action.newStatus == .unset {
        followingEdges.remove(action.edge)
      } else {
        followingEdges.insert(action.edge)
      }
    }
    super.init()
    message = "赤のエッジが間違っています。オレンジの部分は赤の後で入力しました。"
    fixLabel = "間違う前に戻す"
    reasonIndex = 0
  }
  
  override func style(of element: Element) -> Style? {
    if let edge = element as? Edge {
      if edge == mistakeEdge {
        return Style(color: AdviseInfo.mainColor)
      } else if followingEdges.contains(edge) {
        return Style(color: AdviseInfo.relatedColor)
      }
    }
    return nil
  }
  
  override func fix(to puzzle: Puzzle) {
    if puzzle.fixedIndex > safeIndex {
      puzzle.fixedIndex = safeIndex
    }
    while puzzle.currentIndex > safeIndex {
      puzzle.undo()
    }
  }
}

class InitialAdviseInfo : AdviseInfo {
  var action: SetEdgeStatusAction
  
  init(puzzle: Puzzle, action: SetEdgeStatusAction) {
    let node = action.edge.nodes[0]
    let edge = action.edge.horizontal ?
      puzzle.board.hEdgeAt(x: node.x, y: node.y) :
      puzzle.board.vEdgeAt(x: node.x, y: node.y)
    self.action = SetEdgeStatusAction(edge: edge, status: action.newStatus)
    super.init()
    fixLabel = "確定"
    message = "初期配置からの手の見落としです。"
  }
  
  override func style(of element: Element) -> Style? {
    if let edge = element as? Edge, edge == action.edge {
      return Style(color: AdviseInfo.adviseColor, showEmptyElement: true,  emptyEdgeStatus: action.newStatus)
    }
    return nil
  }
  
  override func fix(to puzzle: Puzzle) {
    puzzle.addAction(action)
  }
}

class MissAdviseInfo : AdviseInfo {
  var function: SolvingContext.Function
  var action: SetEdgeStatusAction
  var reasonElements: [Element]
  
  var showGate = false
  var showCellColor = false
  
  init(result: FindResult) {
    function = result.context.function
    action = result.action
    reasonElements = result.context.mainElements
    super.init()
    self.board = result.context.board
    reasonLabel = "理由表示"
    fixLabel = "確定"
    switch function {
    case .initialize:
      message = "初期配置からの手の見落としです。"
      reasonLabel = ""
    case .smallLoop:
      message = "小ループ防止の手の見落としです。"
    case .checkNode:
      message = "ノードから確定するエッジの見落としです。"
    case .checkCell:
      message = "セルから確定するエッジの見落としです。"
    case .checkGate:
      message = "ゲートから確定するエッジの見落としです。"
      showGate = true
    case .checkColor:
      message = "セル色から確定するエッジの見落としです。"
      showCellColor = true
    default:
      break
    }
  }
  
  override func style(of element: Element) -> Style? {
    if let edge = element as? Edge, edge == action.edge {
      return Style(color: AdviseInfo.adviseColor)
    } else if reasonIndex >= 0 && reasonElements.contains(element) {
      var color = AdviseInfo.mainColor
      if showCellColor {
        if let cell = element as? Cell {
          color = (cell.color == CellColor.inner) ? AdviseInfo.innerColor : AdviseInfo.outerColor
        }
      }
      return Style(color: color, showGate: showGate, showCellColor: showCellColor)
    }
    return nil
  }

  override func fix(to puzzle: Puzzle) {
    let node = action.edge.nodes[0]
    let edge = action.edge.horizontal ?
      puzzle.board.hEdgeAt(x: node.x, y: node.y) :
      puzzle.board.vEdgeAt(x: node.x, y: node.y)
    puzzle.addAction(SetEdgeStatusAction(edge: edge, status: action.newStatus))
  }
}

class AreaCheckAdviseInfo : MissAdviseInfo {
  var areaNodes: [Node]
  
  override init(result: FindResult) {
    // TODO
    areaNodes = []
    super.init(result: result)
    reasonElements = []
    message = "領域出入りから確定します。"
  }

  override func style(of element: Element) -> Style? {
    if let style = super.style(of: element) {
      return style
    }
    if let node = element as? Node, areaNodes.contains(node) {
      return Style(color: AdviseInfo.relatedColor)
    }
    return nil
  }
}

class TryAdviseInfo : AdviseInfo {
  var steps: [[Action]]
  var action: SetEdgeStatusAction
  var followingElements: [Element] = []
  var edgeElement: Element?
  var reasonElement: Element?
  
  init(result: FindResult) {
    steps = []
    action = result.action
    reasonElement = result.context.mainElements[0]
    super.init()
    self.board = result.context.board
    fixLabel = "確定"
  }
  
  override func showReason() {
    stepForward()
  }
  
  override func fix(to puzzle: Puzzle) {
    let node = action.edge.nodes[0]
    let edge = action.edge.horizontal ?
      puzzle.board.hEdgeAt(x: node.x, y: node.y) :
      puzzle.board.vEdgeAt(x: node.x, y: node.y)
    puzzle.addAction(SetEdgeStatusAction(edge: edge, status: action.newStatus))
  }
  
  func stepForward() {
    reasonIndex += 1
    let currStep = steps[reasonIndex]
    for action in currStep {
      action.redo()
    }
    appendElements(of: currStep)
  }
  
  func stepBack() {
    for action in steps[reasonIndex].reversed() {
      action.undo()
    }
    reasonIndex -= 1
  }
  
  var canStepBack: Bool {
    return reasonIndex > 0
  }
  
  var canStepForward: Bool {
    return reasonIndex < steps.count - 1
  }
  
  func appendElements(of step: [Action]) {
    for action in step {
      switch action {
      case is SetEdgeStatusAction:
        followingElements.append((action as! SetEdgeStatusAction).edge)
      case is SetGateStatusAction:
        followingElements.append((action as! SetGateStatusAction).node)
      case is SetCellColorAction:
        followingElements.append((action as! SetCellColorAction).cell)
      default:
        break
      }
    }
  }
}

class TryFailAdviseInfo : TryAdviseInfo {
  
  override init(result: FindResult) {
    super.init(result: result)
    if let actions = result.context.relatedElements as? [Action] {
      var currStep: [Action] = []
      for action in actions {
        currStep.append(action)
        if action is SetEdgeStatusAction {
          steps.append(currStep)
          currStep = []
        }
      }
      if currStep.count > 0 {
        steps.append(currStep)
      }
    }
    message = "仮置の結果、確定します。"
    reasonLabel = "仮置のステップ実行"
  }

  override func style(of element: Element) -> Style? {
    if reasonIndex < 0 {
      if let edge = element as? Edge, edge == action.edge {
        return Style(color: AdviseInfo.adviseColor)
      }
    } else {
      if element == edgeElement || (reasonIndex == steps.count - 1 && element == reasonElement) {
        return Style(color: AdviseInfo.mainColor, showEmptyElement: true)
      } else if followingElements.contains(element) {
        var color = AdviseInfo.relatedColor
        if let cell = element as? Cell {
          color = (cell.color == CellColor.inner) ? AdviseInfo.innerColor : AdviseInfo.outerColor
        }
        return Style(color: color, showGate: true, showCellColor: true)
      }
    }
    return nil
  }
  
  override func stepForward() {
    super.stepForward()
    if reasonIndex < steps.count - 1 {
      edgeElement = followingElements.last
    } else {
      edgeElement = nil
    }
  }
  
  override func stepBack() {
    super.stepBack()
    followingElements = []
    for i in 0 ... reasonIndex {
      appendElements(of: steps[i])
    }
    edgeElement = followingElements.last
  }
}

class TrySameResultAdviseInfo : TryAdviseInfo {
  var offIndex = 0
  
  override init(result: FindResult) {
    super.init(result: result)
    let edge = result.action.edge
    if let actions = result.context.relatedElements as? [Action] {
      var currStep: [Action] = []
      for action in actions {
        currStep.append(action)
        if let seAction = action as? SetEdgeStatusAction {
          steps.append(currStep)
          currStep = []
          if seAction.edge == edge && offIndex == 0 {
            // 最初の対象エッジの次からoff
            offIndex = steps.count
          }
        }
      }
      if currStep.count > 0 {
        steps.append(currStep)
      }
    }
    message = "どちらの状態の仮置でも同じ状態になり、確定します。"
    reasonLabel = "仮置（ON→OFF）のステップ実行"
  }
  
  override func style(of element: Element) -> Style? {
    if reasonIndex < 1 {
      if let edge = element as? Edge {
        if edge == action.edge {
          return Style(color: AdviseInfo.adviseColor)
        } else if edge == reasonElement {
          return Style(color: AdviseInfo.mainColor, showEmptyElement: true)
        }
      }
    } else {
      if element == edgeElement {
        return Style(color: AdviseInfo.mainColor)
      } else if followingElements.contains(element) {
        var color = AdviseInfo.relatedColor
        if let cell = element as? Cell {
          color = (cell.color == CellColor.inner) ? AdviseInfo.innerColor : AdviseInfo.outerColor
        }
        return Style(color: color, showGate: true, showCellColor: true)
      }
    }
    return nil
  }
  
  override func showReason() {
    action.edge._status = .unset
    super.showReason()
  }
  
  override func stepForward() {
    if reasonIndex + 1 == offIndex {
      for index in (0 ... reasonIndex).reversed() {
        for action in steps[index].reversed() {
          action.undo()
        }
      }
      followingElements = []
    }
    super.stepForward()
    edgeElement = followingElements.last
  }
  
  override func stepBack() {
    super.stepBack()
    followingElements = []
    let startIndex = reasonIndex < offIndex ? 0 : offIndex
    for i in startIndex ... reasonIndex {
      appendElements(of: steps[i])
    }
    edgeElement = followingElements.last
  }
}
