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
/// - xSymmetry: X軸対称
/// - ySymmetry: Y軸対称
/// - xySymmetry: XY軸対称
/// - pointSymmetry: 点対称
/// - hPair: 横2個ずつ（同一列）
/// - hPairShift: 横2個ずつ（階段状）
/// - dPair: 斜め2個ずつ（同一方向）
/// - dPairCross: 斜め2個ずつ（X型）
/// - dPairSymmetry: 斜め2個ずつ（同一方向、X軸対称）
/// - quad: 田型4個ずつ（同一列）
/// - quadShift: 田型4個ずつ（階段状）
enum PruneType: String {
  case free = "F"
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
  case random2Cell = "R2"
  case random4Cell = "R4"
  
  /// 文字列表現
  public var description: String {
    switch self {
    case .free:
      return "制約なし [F]"
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
    case .random2Cell:
      return "2セル（任意）"
    case .random4Cell:
      return "4セル（任意）"
    }
  }
  
  public var realType: PruneType {
    switch self {
    case .random2Cell:
      return [.xSymmetry, .ySymmetry, .pointSymmetry, .hPair, .dPair].randomElement()!
    case .random4Cell:
      return [.xySymmetry, .hPairSymmetry, .dPairSymmetry, .quad].randomElement()!
    default:
      return self
    }
  }
}

class Pruner {
  var pruneType: PruneType
  
  let board: Board
  
//  var originalNumbers: [Int] = []
  
  init(board: Board, pruneType: PruneType) {
    self.board = board
    self.pruneType = pruneType
  }
  
  public func setupPruneOrder() -> [[Int]] {
//    for cell in board.cells {
//      originalNumbers.append(cell.onCount)
//    }
//
    var pruneOrders: [[Int]] = []
    let xc = board.width % 2 == 1 ? board.width / 2 : -1
    let yc = board.height % 2 == 1 ? board.height / 2 : -1
    
    switch pruneType {
    case .free:
      for i in 0 ..< board.cells.count {
        pruneOrders.append([i])
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
    case .hPair, .hPairSymmetry, .dPairCross, .quad:
      var xmax = board.width
      let ymax = board.height
      if pruneType == .hPairSymmetry {
        xmax = (board.width + 1) / 2
      }
      var y = 0
      while y < ymax {
        var x = 0
        while x < xmax {
          let index = y * board.width + x
          var indecies = [index]
          if x == xc {
            if y != yc && (pruneType == .dPairCross || pruneType == .quad) {
              indecies.append(index + board.width)
            }
            pruneOrders.append(indecies)
            x += 1
          } else {
            if pruneType == .hPairSymmetry {
              let xm = board.width - x - 1
              indecies.append(y * board.width + xm)
            }
            if pruneType == .hPair || pruneType == .hPairSymmetry || pruneType == .quad {
              indecies.append(index + 1)
              if pruneType == .hPairSymmetry {
                let xm = board.width - x - 2
                indecies.append(y * board.width + xm)
              }
            }
            if y == yc {
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
        y += ((pruneType == .hPair || pruneType == .hPairSymmetry || y == yc) ? 1 : 2)
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
            if pruneType == .dPairSymmetry {
              let xm1 = board.width - x1 - 1
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
    return pruneOrders
  }
}

