//
//  Pruner.swift
//  Slither2
//
//  Created by KO on 2019/03/09.
//  Copyright © 2019 KO. All rights reserved.
//

import Foundation

/// 盤面の数値の除去パターン
///
/// - free: パターンなし
/// - vWideBorder: 縦方向の太縦縞優先
/// - vThinBorder: 縦方向の細縦縞優先
/// - hWideBorder: 横方向の太縦縞優先
/// - hThinBorder: 横方向の細縦縞優先
/// - dWideBorder: 斜め方向の太縦縞優先
/// - dThinBorder: 斜め方向の細縦縞優先
/// - check: 2マス幅チェック優先
/// - xSymmetry: X軸対称
/// - ySymmetry: Y軸対称
/// - xySymmetry: XY軸対称
/// - pointSymmetry: 点対称
/// - hPair: 横2個ずつ（同一列）
/// - hPairShift: 横2個ずつ（階段状）
/// - hPairSymmetry: 横2個ずつ（同一列、X軸対称）
/// - dPair: 斜め2個ずつ（同一方向）
/// - dPairCross: 斜め2個ずつ（X型）
/// - dPairSymmetry: 斜め2個ずつ（同一方向、X軸対称）
/// - quad: 田型4個ずつ（同一列）
/// - quadShift: 田型4個ずつ（階段状）
/// - randomSCell: ランダムに難問パターン（縦横の縞優先）を選択
/// - random1Cell: ランダムに1セル単位のパターンを選択
/// - random2Cell: ランダムに2セル単位のパターンを選択
/// - random4Cell: ランダムに4セル単位のパターンを選択
enum PruneType: String {
  case free = "F"
  case vWideBorder = "WV"
  case vThinBorder = "TV"
  case hWideBorder = "WH"
  case hThinBorder = "TH"
  case dWideBorder = "WD"
  case dThinBorder = "TD"
  case check = "C"
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
  case randomSCell = "RS"
  case random1Cell = "R1"
  case random2Cell = "R2"
  case random4Cell = "R4"
  
  /// 文字列表現
  public var description: String {
    switch self {
    case .free:
      return "制約なし [F]"
    case .vWideBorder:
      return "太縦縞優先 [WV]"
    case .vThinBorder:
      return "細縦縞優先 [TV]"
    case .hWideBorder:
      return "太横縞優先 [WH]"
    case .hThinBorder:
      return "細横縞優先 [TH]"
    case .dWideBorder:
      return "太斜縞優先 [WD]"
    case .dThinBorder:
      return "細斜縞優先 [TD]"
    case .check:
      return "チェック優先 [C]"
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
    case .randomSCell:
      return "難問（任意）"
    case .random1Cell:
      return "1セル（任意）"
    case .random2Cell:
      return "2セル（任意）"
    case .random4Cell:
      return "4セル（任意）"
    }
  }
  
  /// ランダムセル別のグループ定義
  private static var groups: [PruneType: PruneTypeGroup] = [
    .random4Cell: PruneTypeGroup(.xySymmetry, .hPairSymmetry, .dPairSymmetry, .quad),
    .random2Cell: PruneTypeGroup(.xSymmetry, .ySymmetry, .pointSymmetry, .hPair, .dPair),
    .random1Cell: PruneTypeGroup(.free, .dWideBorder, .dThinBorder, .check),
    .randomSCell: PruneTypeGroup(.vWideBorder, .vThinBorder, .hWideBorder, .hThinBorder)
  ]
  
  /// 実際に割り当てる除去パターン（ランダム系のパターンに実際のパターンを割り当て）
  /// 同じ変数に対して2回呼ぶと、異なる値が返るため、取得した値は別な変数にほ保持しておくこと
  public var realType: PruneType {
    return PruneType.groups[self]?.realType ?? self
  }
}

/// 除去パターンのグループ定義
class PruneTypeGroup {
  /// グループに属する実際の除去パターン
  let realTypes: [PruneType]
  
  /// 次の除去パターンを選択する選択肢（同じパターンが続けて選ばれないための装置）
  var selectables: [PruneType] = []
  
  /// 実際の除去パターン
  var realType: PruneType {
    if selectables.count == 0 {
      selectables = realTypes.shuffled()
    }
    return selectables.removeLast()
  }
  
  /// コンストラクタ
  ///
  /// - Parameter realTypes: 属する実際の除去パターン
  init(_ realTypes: PruneType...) {
    self.realTypes = realTypes
  }
}

/// 盤面の数値の除去をおこなうクラス
class Pruner {
  /// 盤面除去のタイプ
  var pruneType: PruneType
  
  /// 盤面（ループが確定した状態）
  let board: Board
  
  /// セルの数値の間引き順序（いくつかのセルを同時に間引くため配列の配列になっている）
  var pruneOrders: [[Int]] = []
  
  /// 与えられた盤面と数値除去タイプの剪定人を得る
  ///
  /// - Parameters:
  ///   - board: 盤面
  ///   - pruneType: 数値除去の対応
  init(board: Board, pruneType: PruneType) {
    self.board = board
    self.pruneType = pruneType
  }
  
  /// 数値除去の順番を決める
  public func setupPruneOrder() {
    let xc = board.width % 2 == 1 ? board.width / 2 : -1
    let yc = board.height % 2 == 1 ? board.height / 2 : -1
    
    switch pruneType {
    case .free:
      for i in 0 ..< board.cells.count {
        pruneOrders.append([i])
      }
    case .vWideBorder:
      return prioritizedPruneOrder() { (x: Int, y: Int) in
        let rx = board.width - x - 1
        return ((rx < x ? rx : x) / 2) % 2 == 1
      }
    case .vThinBorder:
      return prioritizedPruneOrder() { (x: Int, y: Int) in
        let rx = board.width - x - 1
        return (rx < x ? rx : x) % 2 == 1
      }
    case .hWideBorder:
      return prioritizedPruneOrder() { (x: Int, y: Int) in
        let ry = board.height - y - 1
        return ((ry < y ? ry : y) / 2) % 2 == 1
      }
    case .hThinBorder:
      return prioritizedPruneOrder() { (x: Int, y: Int) in
        let ry = board.height - y - 1
        return (ry < y ? ry : y) % 2 == 1
      }
    case .dWideBorder:
      return prioritizedPruneOrder() { (x: Int, y: Int) in
        let val = x - y
        return (val / 2) % 2 != 0
      }
    case .dThinBorder:
      return prioritizedPruneOrder() { (x: Int, y: Int) in
        let val = x - y
        return val % 2 != 0
      }
    case .check:
      return prioritizedPruneOrder() { (x: Int, y: Int) in
        let rx = board.width - x - 1
        let ry = board.height - y - 1
        return ((rx < x ? rx : x) / 2 + (ry < y ? ry : y) / 2) % 2 == 1
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
    case .hPair, .dPairCross, .quad:
      let xmax = board.width
      let ymax = board.height
      var y = 0
      while y < ymax {
        var x = 0
        while x < xmax {
          let index = y * board.width + x
          var indecies = [index]
          if x == xmax - 1 {
            if y != ymax - 1 && (pruneType == .dPairCross || pruneType == .quad) {
              indecies.append(index + board.width)
            }
            pruneOrders.append(indecies)
            x += 1
          } else {
            if pruneType == .hPair || pruneType == .quad {
              indecies.append(index + 1)
            }
            if y == ymax - 1 {
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
        y += ((pruneType == .hPair || y == yc) ? 1 : 2)
      }
    case .hPairSymmetry:
      let xmax = (board.width + 1) / 2
      let ymax = board.height
      var y = 0
      while y < ymax {
        var x = 0
        while x < xmax {
          let index = y * board.width + x
          var indecies = [index]
          if x == xc {
            pruneOrders.append(indecies)
            x += 1
          } else {
            let xm = board.width - x - 1
            indecies.append(y * board.width + xm)
            indecies.append(index + 1)
            if x != xc - 1 {
              let xm = board.width - x - 2
              indecies.append(y * board.width + xm)
            }
            pruneOrders.append(indecies)
            x += 2
          }
        }
        y += 1
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
            let xm1 = board.width - x1 - 1
            if xm1 != x1 && pruneType == .dPairSymmetry {
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
  /// - Parameters:
  ///   - solveOption: ソルバのオプション
  ///   - stepHandler: 1回間引の可否を確認するたびに呼び出されるハンドラ、引数は回数、成功したかどうか、ソルバ
  /// - Returns: 間引き後の数値の配列（間引かれた箇所は−1）
  public func pruneNumbers(solveOption: SolveOption, stepHandler: ((Int, SolveResult) -> ())?) -> [Int] {
    var originalNumbers: [Int] = []
    for cell in board.cells {
      originalNumbers.append(cell.onCount)
    }
    
    var numbers = originalNumbers
    var pruneCount = 0
    for indecies in pruneOrders {
      pruneCount += 1
      for index in indecies {
        numbers[index] = -1
      }
      let newBoard = Board(width: board.width, height: board.height, numbers: numbers)
      let solver = Solver(board: newBoard)
      
      let result = solver.solve(option: solveOption)
      if !result.solved {
        for index in indecies {
          numbers[index] = originalNumbers[index]
        }
      } else if result.tryingChainCount > 0 {
        print("tryingChain: \(result.tryingChainCount)")
      }
      stepHandler?(pruneCount, result)
    }
    return numbers
  }
  
  /// セルの座標と与えられた関数から、優先かどうかを判断し、優先のものを早めに除去する
  ///
  /// - Parameter predicate: セルの座標を元に優先かどうかを判断する関数
  private func prioritizedPruneOrder(predicate: ((_ x: Int, _ y: Int) -> Bool)) {
    var indecies: [[Int]] = [[], []]
    let xmax = board.width
    let ymax = board.height
    for y in 0 ..< ymax {
      for x in 0 ..< xmax {
        let index = y * board.width + x
        indecies[predicate(x, y) ? 0 : 1].append(index)
      }
    }
    for i in 0 ..< 2 {
      indecies[i].shuffle()
      for index in indecies[i] {
        pruneOrders.append([index])
      }
    }
  }
}

