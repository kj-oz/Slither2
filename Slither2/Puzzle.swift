//
//  Puzzle.swift
//  Slither
//
//  Created by KO on 2019/01/06.
//  Copyright © 2019 KO. All rights reserved.
//

import Foundation
import CoreGraphics

/// 問題の状態
///
/// - editing:　編集中
/// - notStarted: 未着手
/// - solving: 未了
/// - solved: 完了
enum PuzzleStatus : String {
  case editing
  case notStarted
  case solving
  case solved
}


/// 問題とそれを解いている過程の情報を保持するクラス
class Puzzle : Hashable {
  /// (Hashable)
  var hashValue: Int {
    return path.hashValue
  }
  
  /// (Hashable)
  static func == (lhs: Puzzle, rhs: Puzzle) -> Bool {
    return lhs === rhs
  }
  
  /// ファイル保存時の拡張子
  static let extention = "slp"
  
  /// ファイル名
  var path = ""
  
  /// 一覧に表示する名称
  var title = ""
  
  ///　盤面
  var board: Board
  
  /// 盤面生成時のパラメータ
  var genParams = ""
  
  /// 盤面生成時の記録（ループ生成時間,間引き回数,間引き前半時間、間引き後半時間)
  var genStats = ""
  
  /// 問題の状態
  var status = PuzzleStatus.editing
  
  /// 解くのにかかった秒数
  var elapsedSecond: Int = 0
  
  /// 解くまでにリセットした回数
  var resetCount: Int = 0
  
  /// 解くまでに固定した回数
  var fixCount: Int = 0
  
  ///　操作の配列
  var actions: [SetEdgeStatusAction] = []
  
  ///　最後の操作
  var lastAction: SetEdgeStatusAction?
  
  ///　最後の操作を実行した時刻
  var lastActionTime = Date()
  
  ///　（UndoBuffer上の）現在のインデックス
  var currentIndex = -1
  
  ///　最後に固定を実行したインデックス
  var fixedIndex = -1
  
  ///　拡大表示時の拡大領域の中心位置
  var zoomedPoint = CGPoint.zero
  
  /// （拡張子を除いた）ファイル名
  var id: String {
    return ((self.path as NSString).lastPathComponent as NSString).deletingPathExtension
  }
  
  /// アンドゥを実行する
  var canUndo: Bool {
    return currentIndex > fixedIndex && status == .solving
  }
  
  /// アンドゥを取り消す
  var canRedo: Bool {
    return actions.count > 0 && currentIndex < actions.count && status == .solving
  }

  //MARK: - 初期化
  
  /// 各種パラメータを指定して新規作成
  ///
  /// - Parameters:
  ///   - folder: 問題を配置するフォルダ
  ///   - width: 巾
  ///   - height: 高さ
  ///   - genParams: 生成時のパラメータ
  ///   - data: セルの数字の配列
  init(folder: Folder, width: Int, height: Int, genParams: String, genStats: String, data: [Int]) {
    board = Board(width: width, height: height, numbers: data)
    self.genParams = genParams
    self.genStats = genStats
    status = genParams.count > 0 ? .notStarted : .editing
    
    let am = AppManager.sharedInstance
    let id = am.nextPuzzleId
    self.title = id
    self.path = (folder.path as NSString).appendingPathComponent("\(id).\(Puzzle.extention)" )
    save()
    folder.puzzles.append(self)
  }
  
  /// 空のパズルの新規作成
  ///
  /// - Parameters:
  ///   - folder: 問題を配置するフォルダ
  ///   - width: 巾
  ///   - height: 高さ
  convenience init(folder: Folder, width: Int, height: Int) {
    let data = Array<Int>(repeating: -1, count: width * height)
    self.init(folder: folder, width: width, height: height, genParams: "", genStats: "", data: data)
  }
  
  /// ファイルからの生成
  ///
  /// - Parameter path: データファイルのパス
  init(path: String) {
    board = Board(width: 1, height: 1, numbers: [0])
    self.path = path
    var lines: [Substring] = []
    if let contents = try? String(contentsOfFile: path) {
      lines = contents.split(separator: "\r\n")
    }
    var width = 0
    var height = 0
    var data: [Int] = []
    var numbersCount = -1
    for line in lines {
      if numbersCount > 0 {
        for char in line {
          if char == " " {
            data.append(-1)
          } else {
            data.append(Int(String(char))!)
          }
        }
        numbersCount -= 1
        if numbersCount == 0 {
          board = Board(width: width, height: height, numbers: data)
        }
      } else {
        let parts = line.split(separator: ":")
        let key = parts[0].trimmingCharacters(in: .whitespaces)
        let value = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
        switch key {
        case "title":
          title = value
        case "size":
          let sizes = value.split(separator: " ")
          width = Int(sizes[0])!
          height = Int(sizes[1])!
        case "genParams":
          genParams = value
        case "genStats":
          genStats = value
        case "numbers":
          numbersCount = height
        case "status":
          status = PuzzleStatus(rawValue: value)!
        case "elapsedSecond":
          elapsedSecond = Int(value)!
        case "resetCount":
          resetCount = Int(value)!
        case "fixCount":
          fixCount = Int(value)!
        case "actions":
          return
        default:
          break
        }
      }
    }
  }
  
  /// 辺の状態の読み込み
  func loadActions() {
    var lines: [Substring] = []
    if let contents = try? String(contentsOfFile: path) {
      lines = contents.split(separator: "\r\n")
    }
    var numbersCount = -1
    var actionCount = -1
    for line in lines {
      if numbersCount >= 0 {
        numbersCount -= 1
      } else if actionCount > 0 {
        var sIndex = line.startIndex
        let dirStr = line[sIndex]
        sIndex = line.index(after: sIndex)
        var eIndex = line.index(sIndex, offsetBy: 2)
        let x = Int(line[sIndex ..< eIndex])!
        sIndex = eIndex
        eIndex = line.index(sIndex, offsetBy: 2)
        let y = Int(line[sIndex ..< eIndex])!
        let edge = dirStr == "H" ? board.hEdgeAt(x: x, y: y) : board.vEdgeAt(x: x, y: y)
        let status = EdgeStatus.fromString(String(line[eIndex ..< line.endIndex]))
        let action = SetEdgeStatusAction(edge: edge, status: status)
        actions.append(action)
        actionCount -= 1
      } else {
        let parts = line.split(separator: ":")
        let key = parts[0].trimmingCharacters(in: .whitespaces)
        let value = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
        switch key {
        case "actions":
          actionCount = Int(value)!
        case "currentIndex":
          currentIndex = Int(value)!
        case "fixedIndex":
          fixedIndex = Int(value)!
        case "zoomedPoint":
          let sizes = value.split(separator: " ")
          zoomedPoint = CGPoint(x: Double(sizes[0])!, y: Double(sizes[1])!)
        default:
          break
        }
      }
    }
    if currentIndex >= 0 {
      for i in 0 ... currentIndex {
        actions[i].redo()
        if i == fixedIndex {
          board.fixStatus()
        }
      }
    }
    lastAction = nil
  }

  /// 他の問題からの生成
  ///
  /// - Parameters:
  ///   - folder: 保存先のフォルダ
  ///   - original: コピー元のパズル
  init(folder: Folder, original: Puzzle) {
    let am = AppManager.sharedInstance
    let id = am.nextPuzzleId
    self.path = (folder.path as NSString).appendingPathComponent("\(id).\(Puzzle.extention)" )
    status = original.status == .editing ? .editing : .notStarted
    genParams = original.genParams
    let orgBoard = original.board
    board = Board(width: orgBoard.width, height: orgBoard.height, numbers: orgBoard.numbers)
    elapsedSecond = 0
    resetCount = 0
    fixCount = 0
    actions = []
    title = copiedTitleOf(folder: folder, original: original.title)
    save()
    folder.puzzles.append(self)
  }
  
  /// コピー先のタイトルを得る
  ///
  /// - Parameters:
  ///   - folder: 保存先のふフォルダ
  ///   - original: コピー元の問題
  /// - Returns: コピー先のタイトル（コピー元のタイトル(n)）
  private func copiedTitleOf(folder: Folder, original: String) -> String {
    var seed = original
    var number = 2
    let range = original.range(of: "\\(\\d+\\)")
    if let range = range {
      seed = String(original[original.startIndex ..< range.lowerBound])
      number = Int(original[original.index(after: range.lowerBound)
        ..< original.index(before: range.upperBound)])!
    }
    
    var newTitle = ""
    while true {
      newTitle = String(format: "%@(%d)", seed, number)
      if !folder.puzzles.contains(where: {$0.title == newTitle}) {
        return newTitle
      }
      number += 1
    }
  }
  
  ///　問題を回転させる
  func rotate() {
    var data = Array<Int>(repeating: -1, count: board.cells.count)
    for y in 0 ..< board.height {
      for x in 0 ..< board.width {
        let val = board.cellAt(x: x, y: y).number
        let i = (board.width - 1 - x) * board.height + y
        data[i] = val
      }
    }
    board = Board(width: board.height, height: board.width, numbers: data)
  }

  ///　ファイルに問題の内容を保存する
  func save() {
    var lines: [String] = []
    lines.append("title: \(title)")
    lines.append("size: \(board.width) \(board.height)")
    lines.append("genParams: \(genParams)")
    lines.append("genStats: \(genStats)")
    lines.append("numbers:")
    for y in 0 ..< board.height {
      var line = ""
      for x in 0 ..< board.width {
        let val = board.cellAt(x: x, y: y).number
        line += val >= 0 ? "\(val)" : " "
      }
      lines.append(line)
    }
    lines.append("status: \(status.rawValue)")
    lines.append("elapsedSecond: \(elapsedSecond)")
    lines.append("resetCount: \(resetCount)")
    lines.append("fixCount: \(fixCount)")
    lines.append("actions: \(actions.count)")
    for action in actions {
      let edge = action.edge
      let status = action.newStatus
      lines.append(edge.id + status.toString())
    }
    lines.append("currentIndex: \(currentIndex)")
    lines.append("fixedIndex: \(fixedIndex)")
    lines.append("zoomedPoint: \(zoomedPoint.x) \(zoomedPoint.y)")
    try! lines.joined(separator: "\r\n").write(toFile: path, atomically: true, encoding: .utf8)
  }

  /// サイズ文字列
  var sizeString: String {
    return String(format: "%dX%d", board.width, board.height)
  }
  
  /// 状態文字列
  var statusString: String {
    switch status {
    case .editing:
      return "作成中"
    case .notStarted:
      return "未着手"
    case .solving:
      return solvingStatusString
    case .solved:
      return "完了（\(solvingStatusString)）"
    }
  }
  
  /// 解くのに掛かった時間（と固定回数、初期化回数）の文字列（H:mm:ss 固定:f 初期化:i）
  var solvingStatusString: String {
    if elapsedSecond > 0 {
      if resetCount > 0 || fixCount > 0 {
        return String(format: "%@ 固定%d 初期化%d", elapsedTimeString, fixCount, resetCount)
      } else {
        return elapsedTimeString
      }
    } else {
      return ""
    }
  }

  /// 解くのに掛かった時間（と固定回数、初期化回数）の文字列（H:mm:ss 固定:f 初期化:i）
  var elapsedTimeString: String {
    return String(format: "%d:%02d:%02d", elapsedSecond / 3600,
                       (elapsedSecond % 3600) / 60, elapsedSecond % 60)
  }

  /// Edgeのステータス変更のActionを追加する
  ///
  /// - Parameter action: アクション
  func addAction(_ action: SetEdgeStatusAction) {
    action.redo()
    if var lastAction = lastAction {
      //　直前のアクションが同じEdgeに対するもので、実行から１秒以内ならアクションをまとめる
      if lastAction.edge == action.edge && Date().timeIntervalSince(lastActionTime) < 1.0 {
        lastAction.newStatus = action.newStatus
        actions[actions.count - 1] = lastAction
        self.lastAction = lastAction
        lastActionTime = Date()
        return
      }
    }
    while currentIndex < actions.count - 1 {
      actions.removeLast()
    }
    actions.append(action)
    currentIndex += 1
    lastAction = action
    lastActionTime = Date()
  }
  
  /// パズルを初期化する
  func clear() {
    currentIndex = -1
    fixedIndex = -1
    actions.removeAll()
    lastAction = nil
    board.clear()
  }
  
  /// パズルを前回固定した箇所まで戻す
  func erase() {
    currentIndex = fixedIndex
    while currentIndex < actions.count - 1 {
      let action = actions.removeLast()
      action.undo()
    }
    lastAction = nil
  }
  
  /// パズルを固定する
  func fix() {
    fixedIndex = currentIndex
    board.fixStatus()
    lastAction = nil
  }
  
  
  /// アンドゥを実行する
  func undo() {
    if currentIndex > fixedIndex {
      actions[currentIndex].undo()
      currentIndex -= 1
      lastAction = nil
    }
  }
  
  /// アンドゥを取り消す
  func redo() {
    if currentIndex < actions.count {
      currentIndex += 1
      actions[currentIndex].redo()
      lastAction = nil
    }
  }
}

