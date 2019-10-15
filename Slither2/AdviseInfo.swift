//
//  AdviseInfo.swift
//  Slither2
//
//  Created by KO on 2019/08/28.
//  Copyright © 2019 KO. All rights reserved.
//

import Foundation
import UIKit

/// アドバイス時の内容を保持するクラス
class AdviseInfo {
  /// 主要素の色
  static let mainColor = UIColor.red
  /// 推奨手の色
  static let adviseColor = UIColor(red: 0.2, green: 1.0, blue: 0.0, alpha: 1.0)
  /// 関連要素の色
  static let relatedColor = UIColor.orange
  /// セル色（内部）
  static let innerColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.1)
  /// セル色（外部）
  static let outerColor = UIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.1)

  /// アドバイス時に表示するメッセージの内容
  var message = ""
  /// 理由表示時の表示要素のインデックス（理由表示前は-1、仮置時にはredo/undo時に増減）
  var reasonIndex = -1
  /// アクションリストに表示する理由表示機能のラベル
  var reasonLabel = ""
  /// アクションリストに表示する確定機能のラベル
  var fixLabel = ""
  /// 理由表示の対象のボード（nil時にはプレイ中の盤面に表示）
  var board: Board?
  
  /// アドバイス表示用のスタイル
  struct Style {
    let color: UIColor
    let showGate: Bool
    let enlargeNode: Bool
    let showCellColor: Bool
    let showEmptyElement: Bool
    let emptyEdgeStatus: EdgeStatus
    
    /// スタイルの定義
    ///
    /// - Parameters:
    ///   - color: 色
    ///   - showGate: ノードをゲートとして描画するかどうか
    ///   - enlargeNode: ノードを拡大して描画するかどうか
    ///   - showCellColor: セルの色を表示するかどうか
    ///   - showEmptyElement: 実際の状態が.unsetの場合も描画するかどうか
    ///   - emptyEdgeStatus: 実際の状態が.unsetの場合の描画する状態
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
  
  /// 指定のエレメントに対するアドバイスによるスタイルを返す
  ///
  /// - Parameter element: 対象のエレメント
  /// - Returns: このアドバイスによるスタイル、アドバイスと無関係な場合nil
  func style(of element: Element) -> Style? {
    return nil
  }
  
  /// 盤面上に理由表示を行う（開始する）
  func showReason() {
    self.reasonIndex = 0
  }
  
  /// 与えられたパズルに対してアドバイスの結果を確定する
  ///
  /// - Parameter puzzle: 対象のパズル
  func fix(to puzzle: Puzzle) {
  }
}

/// ループが閉じたタイミングで行う回答チェックの結果
class CheckResultAdviseInfo : AdviseInfo {
  /// エラーの見つかった要素
  var checked: Set<Element> = []
  
  /// 回答チェックの結果情報の構築
  ///
  /// - Parameter checked: エラーの見つかった要素
  init(_ checked: [Element]) {
    self.checked = Set<Element>(checked)
  }
  
  // エラーの見つかった要素　→　赤
  override func style(of element: Element) -> Style? {
    if checked.contains(element) {
      return Style(color: AdviseInfo.mainColor)
    }
    return nil
  }
}

/// ユーザーの実施手順に誤りがあったことの情報
class MistakeAdviseInfo : AdviseInfo {
  /// 誤ったエッジ
  var mistakeEdge: Edge
  /// mistakeEdge以降に入力したエッジ
  var followingEdges: Set<Edge>
  /// 誤る前のアクションのインデックス
  var safeIndex: Int
  
  /// 手順誤り情報の構築
  ///
  /// - Parameters:
  ///   - puzzle: ユーザーが解いているパズル
  ///   - index: 間違った手のインデックス
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
  
  // 間違った手 →　赤
  // そのあとの手 → オレンジ
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
  
  // 間違った手の手前で確定
  override func fix(to puzzle: Puzzle) {
    if puzzle.fixedIndex > safeIndex {
      puzzle.fixedIndex = safeIndex
    }
    while puzzle.currentIndex > safeIndex {
      puzzle.undo()
    }
  }
}

/// 初期探索の見落としの情報
class InitialAdviseInfo : AdviseInfo {
  /// 見落としたアクション
  var action: SetEdgeStatusAction
  
  /// 初期探索の見落としの情報の構築
  ///
  /// - Parameters:
  ///   - puzzle: ユーザーが実施しているパズル
  ///   - action: 見落としたアクション
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
  
  // 見落としたエッジ → 緑
  override func style(of element: Element) -> Style? {
    if let edge = element as? Edge, edge == action.edge {
      return Style(color: AdviseInfo.adviseColor, showEmptyElement: true,  emptyEdgeStatus: action.newStatus)
    }
    return nil
  }
  
  // 見落した手を実施する
  override func fix(to puzzle: Puzzle) {
    puzzle.addAction(action)
  }
}

/// 何らかの解法により見つる手の見落としの情報
class MissAdviseInfo : AdviseInfo {
  /// 解法
  var function: FindingContext.Function
  /// 見落としたアクション
  var action: SetEdgeStatusAction
  /// 解法の起点の要素
  var reasonElements: [Element]
  /// ノードの代わりにゲートを表示うするかどうか
  var showGate = false
  /// セルの色を表示するかどうか
  var showCellColor = false
  
  /// 何らかの解法により見つる手の見逃しの情報
  ///
  /// - Parameter result: 探索の結果
  init(result: FindingContext) {
    function = result.function
    action = result.action!
    reasonElements = result.mainElements
    super.init()
    self.board = result.board
    reasonLabel = "理由表示"
    fixLabel = "確定"
    switch function {
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
  
  // 見落とした手 → 緑
  // 理由の手 → 赤、またはセル色
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

  // 見落とした手を実施する
  override func fix(to puzzle: Puzzle) {
    let node = action.edge.nodes[0]
    let edge = action.edge.horizontal ?
      puzzle.board.hEdgeAt(x: node.x, y: node.y) :
      puzzle.board.vEdgeAt(x: node.x, y: node.y)
    puzzle.addAction(SetEdgeStatusAction(edge: edge, status: action.newStatus))
  }
}

/// 領域チェックにより見つる手の見落としの情報
class AreaCheckAdviseInfo : MissAdviseInfo {
  /// 領域のノード
  var areaNodes: [Node]
  
  // 領域のノード情報を関連要素から取得
  override init(result: FindingContext) {
    areaNodes = result.relatedElements as! [Node]
    super.init(result: result)
    reasonElements = []
    message = "領域出入りから確定します。"
  }

  // 見落とした手 → 緑
  // 理由の手 → 赤、またはセル色
  // 領域のノード → オレンジ
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

/// １手仮置により見つる手の見落としの情報
class TryAdviseInfo : AdviseInfo {
  /// 理由表示時に表示するアクション
  var steps: [[Action]]
  /// 仮置のアクション
  var action: SetEdgeStatusAction
  /// 理由表示のステップ実行時の当該アクションまでに変更した要素
  var followingElements: [Element] = []
  /// 理由表示のステップ実行時の当該アクションの対象エッジ
  var edgeElement: Element?
  /// 矛盾が発生した要素
  var reasonElement: Element?
  
  /// １手仮置により見つる手の見逃しの情報の構築
  ///
  /// - Parameter result: 探索の結果
  init(result: FindingContext) {
    steps = []
    action = result.action!
    reasonElement = result.mainElements[0]
    super.init()
    self.board = result.board
    fixLabel = "確定"
  }
  
  // 理由表示の開始
  override func showReason() {
    stepForward()
  }
  
  // 見逃した手の実施
  override func fix(to puzzle: Puzzle) {
    let node = action.edge.nodes[0]
    let edge = action.edge.horizontal ?
      puzzle.board.hEdgeAt(x: node.x, y: node.y) :
      puzzle.board.vEdgeAt(x: node.x, y: node.y)
    puzzle.addAction(SetEdgeStatusAction(edge: edge, status: action.newStatus))
  }
  
  /// 理由表示で１ステップ前に進める
  func stepForward() {
    reasonIndex += 1
    let currStep = steps[reasonIndex]
    for action in currStep {
      action.redo()
    }
    appendElements(of: currStep)
  }
  
  /// 理由表示で１ステップ後ろに戻る
  func stepBack() {
    for action in steps[reasonIndex].reversed() {
      action.undo()
    }
    reasonIndex -= 1
  }
  
  /// 理由表示で１ステップ前に進めるかどうか
  var canStepForward: Bool {
    return reasonIndex < steps.count - 1
  }
  
  /// 理由表示で１ステップ後ろに戻れるかどうか
  var canStepBack: Bool {
    return reasonIndex > 0
  }
  
  /// 与えられたステップの対象要素を、変更済み要素に追加する
  ///
  /// - Parameter step: 追加するアクション群
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

/// １手仮置で、矛盾が発生して確定した手の情報
class TryFailAdviseInfo : TryAdviseInfo {
  
  // 実施したアクションを、エッジの状態変更のアクションごとのステップに分解する
  override init(result: FindingContext) {
    super.init(result: result)
    if let actions = result.relatedElements as? [Action] {
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

  // 見落とした手 → 緑
  // ステップの最後のエッジに対する手、または矛盾の発生した要素 → 赤
  // それまでに変更した要素 → オレンジ、セル色
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
  
  // 前に進める、変更要素を更新する
  override func stepForward() {
    super.stepForward()
    if reasonIndex < steps.count - 1 {
      edgeElement = followingElements.last
    } else {
      edgeElement = nil
    }
  }
  
  // 後ろに戻る、変更要素を更新する
  override func stepBack() {
    super.stepBack()
    followingElements = []
    for i in 0 ... reasonIndex {
      appendElements(of: steps[i])
    }
    edgeElement = followingElements.last
  }
}

/// １手仮置で、ON/OFFで同じ状態になり確定した手の情報
class TrySameResultAdviseInfo : TryAdviseInfo {
  /// stepsにON/OFFの順に両方のステップを保持するため、OFFのステップの始まるインデックス
  var offIndex = 0
  
  // ステップを構築する際、offIndexを設定する
  override init(result: FindingContext) {
    super.init(result: result)
    let edge = result.action!.edge
    if let actions = result.relatedElements as? [Action] {
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
  
  // 見落とした手 → 緑
  // 仮置したエッジ → 赤（丸）
  // ステップの最後のエッジに対する手、または矛盾の発生した要素 → 赤
  // それまでに変更した要素 → オレンジ、セル色
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

  // 理由表示時に、見つかったエッジのステータスはOFFにしておく
  override func showReason() {
    action.edge._status = .unset
    super.showReason()
  }
  
  // 前に進める、offIndex対応
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
  
  // 後ろに戻る、、offIndex対応
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
