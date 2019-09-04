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
  static let adviseColor = UIColor.green
  static let relatedColor = UIColor.orange
  
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
    
    init(color: UIColor, showGate: Bool = false, enlargeNode: Bool = true, showCellColor: Bool = false) {
      self.color = color
      self.showGate = showGate
      self.enlargeNode = enlargeNode
      self.showCellColor = showCellColor
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
    } else if reasonElements.contains(element) {
      return Style(color: AdviseInfo.mainColor, showGate: showGate, showCellColor: showCellColor)
    }
    return nil
  }

  override func fix(to puzzle: Puzzle) {
    puzzle.addAction(action)
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

class TryFailAdviseInfo : AdviseInfo {
  var steps: [Step]
  var action: SetEdgeStatusAction
  var followingElements: [Element] = []
  var edgeElement: Element?
  var reasonElement: Element?
  
  init(result: FindResult) {
    steps = []
    if let actions = result.context.relatedElements as? [Action] {
      var currStep = Step()
      for action in actions {
        currStep.add(action: action)
        if action is SetEdgeStatusAction {
          steps.append(currStep)
          currStep = Step()
        }
      }
      if currStep.actions.count > 0 {
        steps.append(currStep)
      }
    }
    action = result.action
    reasonElement = result.context.mainElements[0]
    super.init()
    self.board = result.context.board
    message = "仮置の結果、確定します。"
    reasonLabel = "仮置のステップ実行"
    fixLabel = "確定"
  }

  override func showReason() {
    stepForward()
  }
  
  override func style(of element: Element) -> Style? {
    if reasonIndex < 0 {
      if let edge = element as? Edge, edge == action.edge {
        return Style(color: AdviseInfo.adviseColor)
      }
    } else {
      if element == edgeElement || (reasonIndex == steps.count - 1 && element == reasonElement) {
        return Style(color: AdviseInfo.mainColor)
      } else if followingElements.contains(element) {
        return Style(color: AdviseInfo.relatedColor, showGate: true, showCellColor: true)
      }
    }
    return nil
  }
  
  override func fix(to puzzle: Puzzle) {
    while reasonIndex >= 0 {
      steps[reasonIndex].rewind()
      reasonIndex -= 1
    }
    steps = []
    puzzle.addAction(action)
  }

  func stepForward() {
    reasonIndex += 1
    let currStep = steps[reasonIndex]
    for action in currStep.actions {
      action.redo()
    }
    appendElements(of: currStep)
    if reasonIndex < steps.count - 1 {
      edgeElement = followingElements.removeLast()
    } else {
      edgeElement = nil
    }
  }
  
  func stepBack() {
    steps[reasonIndex].rewind()
    reasonIndex -= 1
    followingElements = []
    for i in 0 ... reasonIndex {
      appendElements(of: steps[i])
    }
    edgeElement = followingElements.removeLast()
  }
  
  private func appendElements(of step: Step) {
    for action in step.actions {
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
