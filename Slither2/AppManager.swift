//
//  AppManager.swift
//  Slither2
//
//  Created by KO on 2019/01/24.
//  Copyright © 2019 KO. All rights reserved.
//

import Foundation
import UIKit

/// 表示しているビューの種類
///
/// - list: パズル一覧
/// - play: パスルの実行
/// - edit: パスルの編集
enum ViewType: String {
  case list
  case play
  case edit
}

/// パズルを保存するフォルダを表すクラス
class Folder {
  /// 含んでいるパズル
  private var _puzzles: [Puzzle]!
  var puzzles: [Puzzle] {
    get {
      if _puzzles == nil {
        _puzzles = []
        let fm = FileManager.default
        let files = try! fm.contentsOfDirectory(atPath: path)
        for file in files {
          self.puzzles.append(Puzzle(folder: self, filename: file))
        }
      }
      return _puzzles
    }
    set {
      _puzzles = newValue
    }
  }
  
  /// フォルダへのパス
  var path: String
  
  /// フォルダ名
  var name: String {
    return (path as NSString).lastPathComponent
  }
  
  /// 指定のパスのフォルダを表すインスタンスを得る
  ///
  /// - Parameter path: パス
  init(path: String) {
    self.path = path
  }
  
  /// 指定のパズルを除去する
  ///
  /// - Parameter puzzles: パズル
  func remove(_ puzzles: [Puzzle]) {
    for puzzle in puzzles {
      self.puzzles.remove(at: _puzzles.firstIndex(of: puzzle)!)
    }
  }
  
  /// 指定のパズルを追加する
  ///
  /// - Parameter puzzles: パズル
  func add(_ puzzles: [Puzzle]) {
    for puzzle in puzzles {
      puzzle.folder = self
    }
    self.puzzles.append(contentsOf: puzzles)
  }
  
  /// パズルの並び順をidの昇順に並び替える
  func reorder() {
    self.puzzles.sort(by: {$0.id < $1.id})
  }
}

/// アプリケーションのフォルダ等を管理するマネージャ
class AppManager {
  /// シングルトンオブジェクト
  static var sharedInstance: AppManager {
    if _sharedInstance == nil {
      _sharedInstance = AppManager()
    }
    return _sharedInstance!
  }
  private static var _sharedInstance: AppManager?
  
  /// iPad Air2 での計測用パズルの処理時間
  let baseSolveTime = 130
  
  /// フォルダの親フォルダのパス
  let rootDir: String
  
  /// パズルのファイル名に採用する日時の書式
  let dateFormatter: DateFormatter
  
  /// フォルダのリスト
  var folders: [Folder] = []
  
  /// 現在選択されているフォルダ
  var currentFolder: Folder
  
  /// 現在選択されているパズル
  var currentPuzzle: Puzzle?
  
  /// ストレージ上のデータの復元中かどうか
  var restoring = false

  /// その時点で表示しているビューの種類
  var currentView = ViewType.list
  
  /// 既存のパズルのIDの初期値
  var lastId = 190101001
  
  /// 最新の5回の計測用パズルを解いた時間
  var solveTimes: [Int] = []
  
  /// 最新5回のうち中間値3回分の平均値と基準値の比（速いマシンほど小さい値）
  var timeFactor = 1.0
  
  // MARK: - 設定の読み込み、保存
  
  /// プライベートなコンストラクタ
  /// 各種設定を読み込む
  private init() {
    let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
    rootDir = URL(fileURLWithPath: paths[0]).absoluteURL.path
    debugPrint("** Application start")
    debugPrint(String(format: " document directory:%@", rootDir))
    

    let fm = FileManager.default
    var dirs: [String] = []
    let files = try! fm.contentsOfDirectory(atPath: rootDir)
    for file in files {
      var isDir: ObjCBool = false
      let path = (rootDir as NSString).appendingPathComponent(file)
      fm.fileExists(atPath: path, isDirectory: &isDir)
      if isDir.boolValue {
        dirs.append(file)
      }
    }
    if dirs.count == 0 {
      // アプリにバンドルされたサンプル問題集の展開
      let sampleDir = (rootDir as NSString).appendingPathComponent("サンプル")
      try? fm.createDirectory(atPath: sampleDir, withIntermediateDirectories: false, attributes: nil)
      let bundle = Bundle.main
      let samples = bundle.paths(forResourcesOfType: "slp", inDirectory: "sample")
      for sample in samples {
        let filename = (rootDir as NSString).lastPathComponent
        do {
          try fm.moveItem(atPath: sample,
                        toPath: (sampleDir as NSString).appendingPathComponent(filename))
        } catch {}
      }
      dirs = ["サンプル"]
    }
    
    // 存在するフォルダ群をもとにデータを構築する
    for dir in dirs {
      let path = (rootDir as NSString).appendingPathComponent(dir)
      folders.append(Folder(path: path))
    }    
    currentFolder = folders[0]
    
    // 日付フォーマットオブジェクトの生成
    dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyMMdd"
    
    // 前回起動時の状態を得る
    // 画面
    if let lastViewStr = UserDefaults.standard.string(forKey: "lastView") {
      currentView = ViewType(rawValue: lastViewStr) ?? .list
    }
    
    // 前回開いていたフォルダ
    currentFolder = folders[0]
    if let lastFolderStr = UserDefaults.standard.string(forKey: "lastFolder") {
      for folder in folders {
        if folder.name == lastFolderStr {
          currentFolder = folder
          break
        }
      }
    }
    
    /// 最後に実行していたパズル
    if let lastPuzzleStr = UserDefaults.standard.string(forKey: "lastPuzzle") {
      for puzzle in currentFolder.puzzles {
        if puzzle.id == lastPuzzleStr {
          currentPuzzle = puzzle
          break
        }
      }
    }
    
    /// 最後に新規パズルのファイル名に利用した（パズルの）ID
    if let lastIdStr = UserDefaults.standard.string(forKey: "lastId") {
      lastId = Int(lastIdStr) ?? 190101001
    }
    
    /// パズルを解く時間を計測し、自動生成時の制限時間の係数を求める
    if let solveTimesStr = UserDefaults.standard.string(forKey: "solveTimes") {
      solveTimes = solveTimesStr.components(separatedBy: ",").map({Int($0) ?? 100})
    }
    /// 毎回計測し、最新の5回分のみ保持する
    solveTimes.append(measureSolveTime())
    if solveTimes.count > 5 {
      solveTimes.remove(at: 0)
    }
    
    timeFactor = calcTimeFactor(solveTimes: solveTimes)
  }
  
  /// ステータスを保存する
  func saveStatus() {
    if let currentPuzzle = currentPuzzle {
      UserDefaults.standard.setValue(currentPuzzle.id, forKey: "lastPuzzle")
      currentPuzzle.save()
    } else {
      UserDefaults.standard.removeObject(forKey: "lastPuzzle")
    }
    
    UserDefaults.standard.setValue(currentFolder.name, forKey: "lastFolder")
    UserDefaults.standard.setValue(currentView.rawValue, forKey: "lastView")
    UserDefaults.standard.setValue(String(lastId), forKey: "lastId")
    let solveTimeStr = solveTimes.map({String($0)}).joined(separator: ",")
    UserDefaults.standard.setValue(String(solveTimeStr), forKey: "solveTimes")
  }

  // MARK: - フォルダ、パズルの操作
  
  /// パスルをカレントのフォルダから指定のフォルダに移動する。
  ///
  /// - Parameters:
  ///   - puzzles: 対象のパズル
  ///   - to: 移動先フォルダ
  /// - Returns: 移動に成功したかどうか
  func movePuzzles(_ puzzles: [Puzzle], to: Folder) -> Bool {
    let fm = FileManager.default
    let toDir = to.path
    
    for puzzle in puzzles {
      let fromFile = puzzle.path
      let puzzleName = (puzzle.path as NSString).lastPathComponent
      let toFile = (toDir as NSString).appendingPathComponent(puzzleName)
      do {
        try fm.moveItem(atPath: fromFile, toPath: toFile)
      } catch {
        return false
      }
    }
    currentFolder.remove(puzzles)
    to.add(puzzles)
    to.reorder()
    return true
  }
  
  /// パズルをカレントフォルダ内でコピーする
  ///
  /// - Parameter puzzles: コピー元のパズル
  func copyPuzzles(_ puzzles: [Puzzle]) {
    for puzzle in puzzles {
      let id = nextPuzzleId()
      let title = copiedTitleOf(folder: currentFolder, original: puzzle.title)
      let _ = Puzzle(folder: currentFolder, id: id, title: title, original: puzzle)
    }
  }
  
  /// カレントフォルダからパズルを削除する
  ///
  /// - Parameter puzzles: 対象のパズル
  func removePuzzles(_ puzzles: [Puzzle]) -> Bool {
    let fm = FileManager.default

    for puzzle in puzzles {
      do {
        try fm.removeItem(atPath: puzzle.path)
      } catch {
        return false
      }
    }
    currentFolder.remove(puzzles)
    return true
  }

  /// 新規の空のフォルダを追加する
  ///
  /// - Parameter name: 追加するフォルダーの名称
  /// - Returns: 無事追加できれば true、エラーが発生すれば false
  func addFolder(name: String) -> Bool {
    if !folderExists(name: name) {
      let path = (rootDir as NSString).appendingPathComponent(name)
      let fm = FileManager.default
      do {
        try fm.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
        folders.append(Folder(path: path))
        return true
      } catch {}
    }
    return false
  }
  
  /// 既存のi番目のフォルダーを削除する
  ///
  /// - Parameter index: 削除するフォルダの番号
  /// - Returns: 無事削除できれば true、エラーが発生すれば false
  func removeFolder(at index: Int)  -> Bool {
    let folder = folders[index]
    let fm = FileManager.default
    do {
      try fm.removeItem(atPath: folder.path)
      folders.remove(at: index)
      return true
    } catch {}
    return false
  }
  
  /// フォルダーの名称を変更する
  ///
  /// - Parameters:
  ///   - folder: フォルダ
  ///   - newName: 新しい名称
  /// - Returns: 名称変更に成功したかどうか
  func renameFolder(_ folder: Folder, to newName: String) -> Bool {
    if !folderExists(name: newName) {
      let fm = FileManager.default
      let fromDir = folder.path
      let toDir = (rootDir as NSString).appendingPathComponent(newName)
      do {
        try fm.moveItem(atPath: fromDir, toPath: toDir)
        folder.path = toDir
        return true
      } catch {}
    }
    return false
  }
  
  // MARK: - 自動生成時の制限時間の算出
  
  /// 計測用パズルを解く時間（ms）を求める
  ///
  /// - Returns: パズルを解く時間（ms）
  func measureSolveTime() -> Int {
    let case1 = [
      "14 24",
      " 3  3  2011   ",
      " 3  23   2  01",
      " 3 23        2",
      " 2    13  32 2",
      " 2   13   0  1",
      "     2   22   ",
      " 331        3 ",
      " 1 32 32302 1 ",
      "            23",
      "213  1 1     2",
      "2 2  202 2 3  ",
      "0        231  ",
      "  332        1",
      "  2 3 202  1 3",
      "1     2 3  223",
      "31            ",
      " 3 02133 23 0 ",
      " 1        112 ",
      "   12   0     ",
      "1  3   33   0 ",
      "3 21  20    1 ",
      "1        21 0 ",
      "01  2   10  3 ",
      "   3331  2  2 "
    ]

    let case2 = [
      "14 24",
      "  1 1  10 3 1 ",
      "0 3 0 2 2  12 ",
      "              ",
      " 0101010101031",
      "              ",
      " 3  2  1 20   ",
      "2  3 1 2   122",
      "              ",
      "1301010101010 ",
      "             2",
      "  3 3 1  0 121",
      "22 2  2  1    ",
      "    1  2  2 20",
      "111 2  1 1 3  ",
      "1             ",
      " 0101010101031",
      "              ",
      "120   0 1 1  3",
      "   13 2  2  3 ",
      "              ",
      "1301010101010 ",
      "              ",
      " 11  2 1 0 1 2",
      " 1 1 10  1 1  "
    ]
    
    var ms = measure(case1)
    ms += measure(case2)

    return ms
  }
  
  /// 与えられたパズルを解き、かかった時間を通知する
  ///
  /// - Parameter lines: パズルの定義
  /// - Returns: かかった時間（ms)
  private func measure(_ lines: [String]) -> Int {
    var option = SolveOption()
    option.doAreaCheck = false
    option.doTryOneStep = true
    option.useCache = true
    option.doColorCheck = true
    option.doGateCheck = true
    option.maxGuessLevel = 12
    option.elapsedSec = 3600.0
    
    let solver = Solver(board: Board(lines: lines))
    let result = solver.solve(option: option)
    
    return Int(result.elapsed * 1000)
  }
  
  // MARK: - ヘルパメソッド
  
  /// 最新の5回の計測用パズルを解いた時間から、（iPad Air2が1.0としたときの）マシンの性能比を求める
  ///
  /// - Parameter solveTimes: 最新5回の処理時間
  /// - Returns: 性能比
  func calcTimeFactor(solveTimes: [Int]) -> Double {
    var values = solveTimes
    if solveTimes.count > 3 {
      values = Array(solveTimes.sorted()[1 ..< solveTimes.count - 1])
    }
    let average = values.reduce(0, {$0 + $1}) / values.count
    return Double(average) / Double(baseSolveTime)
  }
  
  /// 次に生成するパズルのIDを得る
  ///
  /// - Returns: 次に生成するパズルのID
  func nextPuzzleId(readonly: Bool = false) -> String {
    let dateStr = dateFormatter.string(from: Date())
    let dateInt = Int(dateStr)!
    let nextId: Int
    if lastId / 1000 >= dateInt {
      nextId = lastId + 1
    } else {
      nextId = dateInt * 1000 + 1
    }
    if !readonly {
      lastId = nextId
    }
    return String(nextId)
  }

  /// コピー先のタイトルを得る
  ///
  /// - Parameters:
  ///   - folder: 保存先のフォルダ
  ///   - original: コピー元の問題
  /// - Returns: コピー先のタイトル（コピー元のタイトル(n)）
  private func copiedTitleOf(folder: Folder, original: String) -> String {
    var seed = original
    var number = 2
    let range = original.range(of: "\\(\\d+\\)$", options: [.regularExpression, .backwards])
    if let range = range {
      seed = String(original[original.startIndex ..< range.lowerBound])
      number = Int(original[original.index(after: range.lowerBound)
        ..< original.index(before: range.upperBound)])!
      number += 1
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
  
  /// 指定の名勝のフォルダがすでに存在するか調べる
  ///
  /// - Parameter name: 名称
  /// - Returns: すでに存在するかどうか
  func folderExists(name: String) -> Bool {
    return folders.first(where: { $0.name == name }) != nil
  }
}

// MARK: - メッセージ画面表示

/// メッセージ上部に表示されるアプリケーション名
let appTitle = "スリザー2"

/// OKボタン一つの確認画面を表示する
///
/// - Parameters:
///   - viewController: 表示中のビューコントローラ
///   - title: タイトル
///   - message: メッセージ文字列
///   - handler: ボタンの押下後に実行されるハンドラ
func alert(viewController: UIViewController, title: String = appTitle,
           message: String, handler: (()->Void)? = nil) {
  let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
  let ok = UIAlertAction(title: "OK", style: UIAlertAction.Style.default) { _ in
    handler?()
  }
  alert.addAction(ok)
  alert.popoverPresentationController?.sourceView = viewController.view
  alert.popoverPresentationController?.sourceRect = viewController.view.frame
  viewController.present(alert, animated: true, completion: nil)
}

/// OKボタン、キャンセルボタンの確認画面を表示する
///
/// - Parameters:
///   - viewController: 表示中のビューコントローラ
///   - title: タイトル
///   - message: メッセージ文字列
///   - handler: いずれかのボタンの押下後に実行されるハンドラ
///     引数は、OKだったかどうか
func confirm(viewController: UIViewController, title: String = appTitle,
             message: String, handler: ((Bool)->Void)? = nil) {
  let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
  let ok = UIAlertAction(title: "OK", style: UIAlertAction.Style.default) { _ in
    handler?(true)
  }
  alert.addAction(ok)
  let cancel = UIAlertAction(title: "キャンセル", style: UIAlertAction.Style.cancel) { _ in
    handler?(false)
  }
  alert.addAction(cancel)
  
  alert.popoverPresentationController?.sourceView = viewController.view
  alert.popoverPresentationController?.sourceRect = viewController.view.frame
  viewController.present(alert, animated: true, completion: nil)
}

