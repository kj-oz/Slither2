//
//  FolderListViewControllerTableViewController.swift
//  Slither
//
//  Created by KO on 2019/01/21.
//  Copyright © 2019 KO. All rights reserved.
//

import UIKit

/// フォルダの選択及び名称の変更を監視するデリゲート
protocol FoldersViewDelegate : class {
  /// フォルダが選択された直後
  ///
  /// - Parameter folder: 選択されたフォルダ
  func folderDidSelect(_ folder: Folder)
  
  /// フォルダの名称が変更された直後
  ///
  /// - Parameter folder: 名称変更されたフォルダ
  func folderDidRename(_ folder: Folder)
}

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
  
  /// 追加ボタン
  @IBOutlet var addButton: UIBarButtonItem!
  
  /// 文字列入力終了ボタン
  @IBOutlet var inputEndButton: UIBarButtonItem!
  
  /// フォルダの選択及び名称の変更を監視するデリゲート
  weak var delegate: FoldersViewDelegate?
  
  // MARK: - UIViewController
  
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
        updateCell(cell, at: tableView.indexPath(for: cell)!)
      }
    }
    
    // ナビゲーションバーのボタンの更新を行う
    updateNavigationItems(animated: animated)
  }
  
  /// ビューのアンロード時
  deinit {
    // 表示を消すことがあるため、強参照している
    addButton = nil
    inputEndButton = nil
  }
  
  /// 編集モード
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
    updateNavigationItems(animated: animated)
  }
  
  // MARK: - UITableViewDataSource/Delegate
  
  // 行数
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return AppManager.sharedInstance.folders.count + (adding ? 1 : 0)
  }
  
  // セル
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "FolderCell", for: indexPath)
    
    updateCell(cell, at: indexPath)
    return cell
  }
  
  // セルが選択された直後
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let am = AppManager.sharedInstance
    let folder = am.folders[indexPath.row]
    delegate?.folderDidSelect(folder)
  }

  // セルが編集可能かどうか
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    let am = AppManager.sharedInstance
    let current = am.folders.firstIndex(where: { $0 === am.currentFolder })
    return indexPath.row != current
  }
  
  // セルが移動可能かどうか
  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    return false
  }
  
  // セルの編集が確定した直後
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    let folder = AppManager.sharedInstance.folders[indexPath.row]
    if editingStyle == .delete {
      if folder.puzzles.count > 0 {
        // 削除操作の場合
        // アラートを表示する
        let msg = "含まれている全ての問題も同時に削除されます。\n\(folder.name)を削除してもよろしいですか？"
        confirm(viewController: self, message: msg, handler: {
          if $0 {
            self.removeSelectedFolder(deletingRow: indexPath.row)
          }
        })
      } else {
        removeSelectedFolder(deletingRow: indexPath.row)
      }
    }
  }
  
  // MARK: - UITextFieldDelegate
  
  // 編集開始直後
  func textFieldDidBeginEditing(_ textField: UITextField) {
    if !adding {
      renaming = true
    }
    updateNavigationItems(animated: true)
  }
  
  // 編集終了直後
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
          delegate?.folderDidRename(folder)
        }
      } else {
        textField.text = folder.name
      }
    }
    // ボタンの更新
    updateNavigationItems(animated: true)
  }
  
  // 編集が確定する直前
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
  
  // MARK: - ボタンのアクション
  
  // 追加ボタンタップ時
  @IBAction func addButtonTapped() {
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
  
  // 文字列編集完了ボタンタップ時
  @IBAction func inputEndButtonTapped() {
    if let cell = findEditingCell() {
      cell.textField.resignFirstResponder()
    }
  }
  
  // MARK: - ヘルパメソッド
  
  /// ナビゲーションバー上のボタンを状況に応じて更新する.
  ///
  /// - Parameter animated: アニメーションの有無
  private func updateNavigationItems(animated: Bool) {
    if adding || renaming {
      navigationItem.setLeftBarButton(inputEndButton, animated: animated)
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
  private func updateCell(_ cell: UITableViewCell, at indexPath: IndexPath) {
    var text = ""
    let am = AppManager.sharedInstance
    let folders = am.folders
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
    
    if folder === am.currentFolder {
      cell.accessoryType = .checkmark
    } else {
      cell.accessoryType = .none
    }
  }
  
  /// 指定のテキストフィールドが含まれるセルを見つけて返す.
  ///
  /// - Parameter textField: テキストフィールド
  /// - Returns: テキストフィールドが含まれるセル
  func findCell(for textField: UITextField?) -> EditableBasicCell? {
    let cell: UITableViewCell? = tableView.cellForRow(at: IndexPath(row: textField?.tag ?? 0, section: 0))
    return cell as? EditableBasicCell
  }
  
  /// 編集中のテキストフィールドを含むセルを得る.
  ///
  /// - Returns: テキストフィールドが含まれるセル
  func findEditingCell() -> EditableBasicCell? {
    let nRows = tableView.numberOfRows(inSection: 0)
    for row in 0 ..< nRows {
      let cell = tableView.cellForRow(at: IndexPath(row: row, section: 0))
      if let tf = (cell as? EditableBasicCell)?.textField, tf.isFirstResponder {
        return cell as? EditableBasicCell
      }
    }
    return nil
  }
  
  /// 指定の行番号のフォルダを削除する.
  ///
  /// - Parameter deletingRow: 削除対象の行番号
  func removeSelectedFolder(deletingRow: Int) {
    // フォルダを削除する
    if AppManager.sharedInstance.removeFolder(at: deletingRow) {
      // テーブルの行を削除する
      tableView.beginUpdates()
      tableView.deleteRows(at: [IndexPath(row: deletingRow, section: 0)], with: .right)
      tableView.endUpdates()
    }
  }
}
