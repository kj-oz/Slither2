//
//  FolderListViewControllerTableViewController.swift
//  Slither
//
//  Created by KO on 2019/01/21.
//  Copyright © 2019 KO. All rights reserved.
//

import UIKit

/// 文字列が編集可能なセル
class EditableBasicCell: UITableViewCell {
  @IBOutlet weak var textField: UITextField!
}

/// フォルダの一覧を取り扱うビュー
class FoldersViewController: UITableViewController, UITextFieldDelegate {
  
  /// 新規フォルダ追加中フラグ（名称入力待ち）
  var adding = false
  
  /// 既存フォルダの名称変更中フラグ（名称入力待ち）
  var renaming = false
  
  /// 削除対象の行
  var deletingRow = 0
  
  /// 追加ボタン
  @IBOutlet var addButton: UIBarButtonItem!
  
  /// 編集終了ボタン
  @IBOutlet var endButton: UIBarButtonItem!
  
  /// この画面で選択されたフォルダ
  var selectedFolder = AppManager.sharedInstance.currentFolder
  
  /// ビューのロード時
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  /// ビューの表示直前
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // テーブルの行の数とフォルダの数を比較する
    if tableView.numberOfRows(inSection: 0) != AppManager.sharedInstance.folders.count {
      // データの再読み込みを行う
      tableView.reloadData()
    } else {
      // セルの表示更新を行う
      for cell: UITableViewCell in tableView.visibleCells {
        update(cell, at: tableView.indexPath(for: cell)!)
      }
    }
    
    // ナビゲーションバーのボタンの更新を行う
    updateNavigationItem(animated: animated)
  }
  
  // MARK: - TableViewDataSource
  
  // 行数
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return AppManager.sharedInstance.folders.count + (adding ? 1 : 0)
  }
  
  // セル
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "FolderCell", for: indexPath)
    
    update(cell, at: indexPath)
    return cell
  }
  
  // MARK: - 編集モード
  override func setEditing(_ editing: Bool, animated: Bool) {
    super.setEditing(editing, animated: animated)
    
    // テーブルビューの編集モードを設定する
    tableView.setEditing(editing, animated: animated)
    
    for cell: UITableViewCell in tableView.visibleCells {
      if let tf = (cell as? EditableBasicCell)?.textField {
        if editing {
          tf.isEnabled = true
        } else {
          if tf.isFirstResponder {
            tf.resignFirstResponder()
          }
          tf.isEnabled = false
        }
      }
    }
    
    // ナビゲーションボタンを更新する
    updateNavigationItem(animated: animated)
  }
  
  /// ナビゲーションバー上のボタンを状況に応じて更新する.
  ///
  /// - Parameter animated: アニメーションの有無
  func updateNavigationItem(animated: Bool) {
    if adding || renaming {
      navigationItem.setLeftBarButton(endButton, animated: animated)
      navigationItem.setRightBarButton(nil, animated: animated)
    } else {
      if isEditing {
        navigationItem.setLeftBarButton(nil, animated: animated)
      } else {
        navigationItem.setLeftBarButton(addButton, animated: animated)
      }
      navigationItem.setRightBarButton(editButtonItem, animated: animated)
    }
  }
  
  /// セルの表示を更新する.
  ///
  /// - Parameters:
  ///   - cell: 対象のセル
  ///   - indexPath: セルのインデックス
  func update(_ cell: UITableViewCell, at indexPath: IndexPath) {
    var text = ""
    let folders = AppManager.sharedInstance.folders
    var folder: Folder?
    if indexPath.row < folders.count {
      folder = folders[indexPath.row]
      text = folder!.name
    }
    if let tf = (cell as? EditableBasicCell)?.textField {
      tf.text = text
      tf.returnKeyType = .done
      tf.delegate = self
      tf.tag = indexPath.row
      
      // 新規追加時の最終行および編集モード時は編集可、それ以外は編集不可
      if (adding && indexPath.row == folders.count) || isEditing {
        tf.isEnabled = true
      } else {
        tf.isEnabled = false
      }
    }
    
    if folder === selectedFolder {
      cell.accessoryType = .checkmark
    } else {
      cell.accessoryType = .none
    }
  }
  
  // 追加ボタンタップ時
  @IBAction func addAction() {
    // 末尾に行を追加
    adding = true
    let indexPath = IndexPath(row: tableView.numberOfRows(inSection: 0), section: 0)
    let indexPaths = [indexPath]
    tableView.beginUpdates()
    tableView.insertRows(at: indexPaths, with: .bottom)
    tableView.endUpdates()
    
    // スクロール
    // endUpdateの前に実行すると、エラー
    tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    
    // フォーカスの設定
    let cell = tableView.cellForRow(at: indexPath) as? EditableBasicCell
    cell?.textField.becomeFirstResponder()
  }
  
  // 完了ボタンタップ時
  @IBAction func endAction() {
    if let cell = findRenamingCell() {
      cell.textField.resignFirstResponder()
    }
  }
  
  // セルが編集可能かどうか
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    let am = AppManager.sharedInstance
    let current = am.folders.firstIndex(where: { $0 === am.currentFolder })
    return indexPath.row != current
  }
  
  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    return false
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    let folder = AppManager.sharedInstance.folders[indexPath.row]
    if editingStyle == .delete {
      deletingRow = indexPath.row
      if folder.puzzles.count > 0 {
        // 削除操作の場合
        // アラートを表示する
        let msg = "含まれている全ての問題も同時に削除されます。\n\(folder.name)を削除してもよろしいですか？"
        confirm(viewController: self, message: msg, handler: {
          if $0 {
            self.removeSelectedFolder(deletingRow: self.deletingRow)
          }
        })
      } else {
        removeSelectedFolder(deletingRow: deletingRow)
      }
    }
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "FolderSelected" {
      let indexPath = tableView.indexPathForSelectedRow!
      selectedFolder = AppManager.sharedInstance.folders[indexPath.row]
    }
  }
  
  // MARK: - UITextField デリゲート
  
  func textFieldDidBeginEditing(_ textField: UITextField) {
    if !adding {
      renaming = true
    }
    updateNavigationItem(animated: true)
  }
  
  //  The converted code is limited to 2 KB.
  //  Upgrade your plan to remove this limitation.
  //
  func textFieldDidEndEditing(_ textField: UITextField) {
    textField.resignFirstResponder()
    let text = textField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    
    if adding {
      // 末尾の行が空なら、行を削除、入力されていれば問題集を追加
      adding = false
      if (text?.count ?? 0) == 0 {
        let indexPath = IndexPath(row: tableView.numberOfRows(inSection: 0) - 1, section: 0)
        tableView.beginUpdates()
        tableView.deleteRows(at: [indexPath], with: .bottom)
        tableView.endUpdates()
      } else {
        let am = AppManager.sharedInstance
        if am.folderExists(name: text!) {
          alert(viewController: self, message: "その名称のフォルダが既に存在します。異なる名称を指定して下さい。")
          adding = true
          textField.text = ""
          textField.becomeFirstResponder()
          return
        }
        
        _ = am.addFolder(name: text!)
        textField.isEnabled = false
      }
    } else {
      renaming = false
      var indexPath: IndexPath!
      if let cell = findCell(for: textField) {
        indexPath = tableView.indexPath(for: cell)
      }
      let am = AppManager.sharedInstance
      let folder = am.folders[indexPath!.row]
      
      if (text?.count ?? 0) > 0 {
        if text!.compare(folder.name) != .orderedSame {
          if am.folderExists(name: text!) {
            alert(viewController: self, message: "その名称のフォルダが既に存在します。異なる名称を指定して下さい。")
            renaming = true
            textField.text = ""
            textField.becomeFirstResponder()
            return
          }
          // 本棚の名称を変更する
          _ = am.renameFolder(folder, to: text!)
        }
      } else {
        textField.text = folder.name
      }
      
      // ボタンの更新
      updateNavigationItem(animated: true)
    }
  }
  
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
  
  // MARK: - ヘルパメソッド
  
  /**
   * 指定のテキストフィールドが含まれるセルを見つけて返す.
   * @param textField テキストフィールド
   * @return テキストフィールドが含まれるセル
   */
  func findCell(for textField: UITextField?) -> EditableBasicCell? {
    let cell: UITableViewCell? = tableView.cellForRow(at: IndexPath(row: textField?.tag ?? 0, section: 0))
    return cell as? EditableBasicCell
  }
  
  /**
   * 編集中のテキストフィールドを含むセルを得る.
   * @return テキストフィールドが含まれるセル
   */
  func findRenamingCell() -> EditableBasicCell? {
    let nRows = tableView.numberOfRows(inSection: 0)
    for row in 0 ..< nRows {
      let cell = tableView.cellForRow(at: IndexPath(row: row, section: 0))
      if let tf = (cell as? EditableBasicCell)?.textField, tf.isFirstResponder {
        return cell as? EditableBasicCell
      }
    }
    return nil
  }
  
  /**
   * 選択されている問題集を削除する.
   */
  func removeSelectedFolder(deletingRow: Int) {
    // ドキュメントを削除する
    if AppManager.sharedInstance.removeFolder(at: deletingRow) {
      // テーブルの行を削除する
      tableView.beginUpdates()
      tableView.deleteRows(at: [IndexPath(row: deletingRow, section: 0)], with: .right)
      tableView.endUpdates()
    }
  }
}
