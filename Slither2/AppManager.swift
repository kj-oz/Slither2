//
//  AppManager.swift
//  Slither
//
//  Created by KO on 2019/01/24.
//  Copyright © 2019 KO. All rights reserved.
//

import Foundation
import UIKit

enum ViewType: String {
  case list
  case play
  case edit
}

class Folder {
  var puzzles: [Puzzle] = []
  
  var path: String
  
  var name: String {
    return (path as NSString).lastPathComponent
  }
  
  init(path: String) {
    self.path = path
    
    let fm = FileManager.default
    let files = try! fm.contentsOfDirectory(atPath: path)
    for file in files {
      let puzzlePath = (path as NSString).appendingPathComponent(file)
      puzzles.append(Puzzle(path: puzzlePath))
    }
  }
}


class AppManager {
  /// シングルトンオブジェクト
  static var sharedInstance: AppManager {
    if _sharedInstance == nil {
      _sharedInstance = AppManager()
    }
    return _sharedInstance!
  }
  
  static var _sharedInstance: AppManager?
  
  let rootDir: String
  
  let dateFormatter: DateFormatter
  
  var folders: [Folder] = []
  
  var currentFolder: Folder
  
  var currrentView = "list"
  
  var currentPuzzle: Puzzle?
  
  var restoring = false

  var currentView = ViewType.list
  
  var lastId = 190101001
  
  var nextPuzzleId: String {
    let dateStr = dateFormatter.string(from: Date())
    let dateInt = Int(dateStr)!
    if lastId / 1000 >= dateInt {
      lastId += 1
    } else {
      lastId = dateInt * 1000 + 1
    }
    return String(lastId)
  }
  
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
    
    for dir in dirs {
      let path = (rootDir as NSString).appendingPathComponent(dir)
      folders.append(Folder(path: path))
    }    
    currentFolder = folders[0]
    
    // 日付フォーマットオブジェクトの生成
    dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyMMdd"
    
    // 前回起動時の状態を得る
    if let lastViewStr = UserDefaults.standard.string(forKey: "lastView") {
      currentView = ViewType(rawValue: lastViewStr) ?? .list
    }
    
    currentFolder = folders[0]
    if let lastFolderStr = UserDefaults.standard.string(forKey: "lastFolder") {
      for folder in folders {
        if folder.name == lastFolderStr {
          currentFolder = folder
          break
        }
      }
    }
    
    if let lastPuzzleStr = UserDefaults.standard.string(forKey: "lastPuzzle") {
      for puzzle in currentFolder.puzzles {
        if puzzle.id == lastPuzzleStr {
          currentPuzzle = puzzle
          break
        }
      }
    }
    
    if let lastIdStr = UserDefaults.standard.string(forKey: "lastId") {
      lastId = Int(lastIdStr) ?? 190101001
    }
  }
  
  
  
  
  
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

  func copyPuzzle(_ puzzle: Puzzle) {
    let id = AppManager.sharedInstance.nextPuzzleId
    let _ = Puzzle(folder: currentFolder, id: id, original: puzzle)
  }

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
  
  func movePuzzles(_ puzzles: [Puzzle], to: Folder) -> Bool {
    let fm = FileManager.default
    let toDir = to.path
    
    for puzzle in puzzles {
      let fromFile = puzzle.path
      let puzzleName = (puzzle.path as NSString).lastPathComponent
      let toFile = (toDir as NSString).appendingPathComponent(puzzleName)
      do {
        try fm.moveItem(atPath: fromFile, toPath: toFile)
        puzzle.path = toFile
        currentFolder.puzzles.remove(at: currentFolder.puzzles.firstIndex(of: puzzle)!)
        to.puzzles.append(puzzle)
      } catch {
        return false
      }
    }
    return true
  }
  
  func folderExists(name: String) -> Bool {
    return folders.first(where: { $0.name == name }) != nil
  }
}

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

