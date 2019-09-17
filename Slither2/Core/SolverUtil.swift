//
//  SolverUtil.swift
//  Slither
//
//  Created by KO on 2018/12/19.
//  Copyright © 2018年 KO. All rights reserved.
//

import Foundation

/// 解の探索中にこれ以上の探索ができなくなった（必要なくなった）際にスローする例外
///
/// - failed: 何らかの矛盾が発生した
/// - finished: 正解が見つかった
/// - cacheHit: キャッシュにヒットした
/// - timeover: 制限時間オーバー
/// - stepover: 1ステップトライ時の延長エッジ数の制限オーバー
/// - sameAction: 1ステップトライ時の.onと.offで同じ状態になった
enum SolveException: Error {
  case failed(reason: Element?)
  case finished
  case cacheHit
  case timeover
  case stepover
  case sameAction(action: SetEdgeStatusAction)
}

/// パズルを解いた結果
struct SolveResult {
  /// 解けなかった理由
  ///
  /// - noloop: 正解が存在しない
  /// - multiloop: 複数の解が存在する
  /// - nological: 理詰めでは解けない
  /// - solved: 解けた
  enum Reason {
    case noloop
    case multiloop
    case nological
    case solved
  }

  /// 問題が解けたかどうか
  var solved = false
  
  /// 解けなかった理由
  var reason: Reason = .solved
  
  /// 処理に要した時間
  var elapsed = 0.0
  
  /// tryOneStepでのtry後の連鎖エッジ数
  var tryingChainCount = 0
  
  /// ブランチの再帰呼び出し時の最大レベル
  var maxLevel = 0
  
  /// エリアチェックで有効な手が見つかったかどうか
  var useAreaCheckResult = false
}

/// ルートが枝分かれ可能な箇所からの個々の分岐
struct Branch {
  /// 分岐先のEdge
  let edge: Edge
  
  /// 分岐位置のNode
  let root: Node
  
  /// 与えられたパラメータの新規の分岐を生成
  ///
  /// - Parameters:
  ///   - root: 分岐位置のNode
  ///   - edge: 分岐先のEdge
  init(root: Node, edge: Edge) {
    self.root = root
    self.edge = edge
  }
}

/// 複数のブランチを扱うクラス
class BranchBuffer {
  /// ブランチの配列
  var branches: [Branch] = []
  
  /// ブランチの数
  var count: Int {
    return branches.count
  }
  
  /// ブランチを追加する
  ///
  /// - Parameter branch: 追加するブランチ
  func add(_ branch: Branch) {
    branches.append(branch)
  }
  
  /// 最初のブランチを取得し、配列からは削除する
  ///
  /// - Returns: 最初のブランチ
  func remove() -> Branch {
    return branches.removeFirst()
  }
}

/// パズルを解く際のオプション
struct SolveOption {
  /// 領域チェックを行うかどうか
  var doAreaCheck = true
  
  /// 1ステップだけの仮置きを行う際の最大伸延すエッジ数
  var tryOneStepMaxExtent = 120
  
  /// セルのコーナーの通過チェックを行うかどうか
  var doGateCheck = true
  
  /// セルの色（内外）のチェックを行うかどうか
  var doColorCheck = true
  
  /// 1ステップだけの仮置きの際、キャッシュを利用するかどうか
  var useCache = true
  
  /// デバッグ出力をおこなうかどうか
  var debug = false
  
  /// 許容処理時間（秒）
  var elapsedSec = 120.0
  
  /// 再帰探索の許容最大レベル（再帰探索無し:0）
  var maxGuessLevel = 120
  
  /// オプションを表現する文字列
  public var description : String {
    var result = ""
    if doGateCheck {
      result += "G"
    }
    if doColorCheck {
      result += "C"
    }
    if tryOneStepMaxExtent > 0 {
      result += useCache ? "T" : "t"
      result += "\(tryOneStepMaxExtent)"
    }
    if doAreaCheck {
      result += "A"
    }
    if maxGuessLevel > 0 {
      result += "L\(maxGuessLevel)"
    }
    if result.count > 0 {
      result += "-"
    }
    result += "\(Int(elapsedSec * 1000.0))"
    return result
  }
}

class SolvingContext {
  enum Function {
    case initialize
    case smallLoop
    case checkCell
    case checkNode
    case checkGate
    case checkColor
    case tryFail
    case trySameResult
    case checkArea
  }
  
  var function = Function.initialize
  
  var mainElements: [Element] = []
  
  var relatedElements: Any = []
  
//  var tryStep: [Action] = []
//
//  var action: Action?
  
  var board: Board?
  
  init(board: Board?) {
    self.board = board
  }
}
