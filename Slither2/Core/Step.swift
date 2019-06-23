//
//  Step.swift
//  Slither2
//
//  Created by KO on 2018/11/09.
//  Copyright © 2018年 KO. All rights reserved.
//

import Foundation

/// 盤面の状態をキャッシュするためのクラス
class EdgeSet: Hashable {
  
  /// 状態を変更されたエッジのコード値の集合
  let edges: Set<Int>
  
  /// その状態のハッシュ値
  let hash: Int
  
  /// (Hashable)
  func hash(into hasher: inout Hasher) {
    hasher.combine(hash)
  }
  
  /// (Hashable)
  static func == (lhs: EdgeSet, rhs: EdgeSet) -> Bool {
    return lhs.edges == rhs.edges
  }
  
  /// 盤面状態のキャッシュ・オブジェクトの生成
  ///
  /// - Parameters:
  ///   - edges: 状態を変更されたエッジのコード値の集合
  ///   - hash: その状態のハッシュ値
  init(edges: Set<Int>, hash: Int) {
    self.edges = edges
    self.hash = hash
  }
}


/// ある操作と、それにより影響を受ける各種の状態変更を連鎖的に行う一連の処理
class Step {
  /// 操作の配列
  var actions: [Action] = []
  
  /// 状態を変更されて未チェックのEdgeの配列
  var changedEdges: [Edge] = []
  
  /// エッジの状態が変更されたことにより色の状態に影響を受ける未チェックのセルの配列
  var colorCheckCells: Set<Cell> = Set<Cell>()
  
  /// エッジの状態が変更されたことによりコーナーのゲートの状態に影響を受ける未チェックのセルの配列
  var gateCheckCells: Set<Cell> = Set<Cell>()
  
  /// キャッシュを使用するかどうか
  let useCache: Bool
  
  /// 完成または未確定だった状態のキャッシュ
  var cache: Set<EdgeSet> = []
  
  /// その時点での変更されたエッジの集合
  var currentEdges: Set<Int> = []
  
  /// その時点での変更されたエッジの集合のハッシュ値
  var currentHash = 0
  
  /// キャッシュに追加する候補（探索の結果エラーが発生したものはキャッシュしない）
  var cacheEntries: [EdgeSet] = []
  
  /// 新たなステップのコンストラクタ
  ///
  /// - Parameter useCache: キャッシュを使用するかどうか
  init(useCache: Bool = false) {
    self.useCache = useCache
  }
  
  /// アクションを追加する
  ///
  /// - Parameter action: 追加するアクション
  func add(action: Action) {
    action.redo()
    actions.append(action)
  }
  
  /// 保持している全てのアクションを取り消し、引数に応じてキャッシュ候補をキャッシュに追加した上で、
  /// ステップ開始時の状態に戻す
  ///
  /// - Parameter addCache: キャッシュ候補をキャッシュに保存するかどうか
  func rewind(addCache: Bool = false) {
    for action in actions.reversed() {
      action.undo()
    }
    actions = []
    changedEdges = []
    gateCheckCells = []
    colorCheckCells = []

    if addCache {
      for entry in cacheEntries {
        cache.insert(entry)
      }
      cacheEntries = []
      currentHash = 0
      currentEdges = []
    }
  }
  
  /// 与えられたエッジを追加した状態の、エッジ集合がキャッシュにヒットするかどうかを調べる
  /// ヒットしなければ、キャッシュ候補に保存する
  ///
  /// - Parameter edge: 変更されたエッジ
  /// - Returns: キャッシュにヒットした（＝完成、または未確定で終わる）かどうか
  func hasCache(edge: Edge) -> Bool {
    let code = encode(edge: edge)
    currentEdges.insert(code)
    currentHash = currentHash ^ code.hashValue
    let entry = EdgeSet(edges: currentEdges, hash: currentHash)
    if cache.contains(entry) {
      return true
    } else {
      cacheEntries.append(entry)
      return false
    }
  }
  
  /// 与えられたエッジとその状態を整数化する
  ///
  /// - Parameter edge: エッジ
  /// - Returns: エッジとその状態を整数化した値
  private func encode(edge: Edge) -> Int {
    let node = edge.nodes[0]
    var val = node.y << 8 + node.x
    if edge.horizontal {
      val += 1 << 16
    }
    if edge.status == .on {
      val += 1 << 17
    }
    return val
  }
}


