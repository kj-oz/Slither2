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
  var puzzles: [Puzzle] = []
  
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
    
    let fm = FileManager.default
    let files = try! fm.contentsOfDirectory(atPath: path)
    for file in files {
      puzzles.append(Puzzle(folder: self, filename: file))
    }
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
  
  /// 既存のパズルのIDのす初期値
  var lastId = 190101001
  
  // MARK: - 設定の読み込み、保存
  
  /// プライベートなコンストラクタ
  /// 各種設定を読み込む
  private init() {
    let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
    rootDir = URL(fileURLWithPath: paths[0]).absoluteURL.path
    debugPrint("** Application start")
    debugPrint(String(format: " document directory:%s", rootDir))
    
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
      try? fm.createDirectory(atPath: (rootDir as NSString).appendingPathComponent("Folder1"),
                              withIntermediateDirectories: false, attributes: nil)
      dirs = ["Folder1"]
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
    
    // 前回起動時のフォルダ
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
    
    /// 最後に新規パズルのファイル名に利用した（パズルのID）
    if let lastIdStr = UserDefaults.standard.string(forKey: "lastId") {
      lastId = Int(lastIdStr) ?? 190101001
    }
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
        currentFolder.puzzles.remove(at: currentFolder.puzzles.firstIndex(of: puzzle)!)
        to.puzzles.append(puzzle)
        puzzle.folder = to
      } catch {
        return false
      }
    }
    to.puzzles.sort(by: {$0.id < $1.id})
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
        currentFolder.puzzles.remove(at: currentFolder.puzzles.firstIndex(of: puzzle)!)
      } catch {
        return false
      }
    }
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
  
  // MARK: - ヘルパメソッド
  
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
/// - parameter viewConroller 表示中のビューコントローラ
/// - parameter message メッセージ文字列
/// - parameter handler ボタンの押下後に実行されるハンドラ
func alert(viewController: UIViewController, title: String = appTitle,
           message: String, handler: (()->Void)? = nil) {
  let alert = UIAlertController(title:appTitle, message: message, preferredStyle: UIAlertController.Style.alert)
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
/// - parameter viewConroller 表示中のビューコントローラ
/// - parameter message メッセージ文字列
/// - parameter handler いずれかのボタンの押下後に実行されるハンドラ
/// 引数は、OKだったかどうか
func confirm(viewController: UIViewController, title: String = appTitle,
             message: String, handler: ((Bool)->Void)? = nil) {
  let alert = UIAlertController(title:appTitle, message: message, preferredStyle: UIAlertController.Style.alert)
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

