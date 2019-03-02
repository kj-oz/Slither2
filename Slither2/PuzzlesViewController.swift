//
//  PuzzlesViewController.swift
//  Slither
//
//  Created by KO on 2019/01/25.
//  Copyright © 2019 KO. All rights reserved.
//

import UIKit

/// パズル一覧を表示するビュー
class PuzzlesViewController: UITableViewController, UIPopoverPresentationControllerDelegate {
  
  /// 修正ボタン
  @IBOutlet weak var modifyButton: UIBarButtonItem!
  /// 複写ボタン
  @IBOutlet weak var copyButton: UIBarButtonItem!
  /// 移動ボタン
  @IBOutlet weak var moveButton: UIBarButtonItem!
  /// 削除ボタン
  @IBOutlet weak var deleteButton: UIBarButtonItem!
  /// フォルダボタン
  @IBOutlet weak var folderButton: UIBarButtonItem!
  
  /// 自動生成ボタン
  @IBOutlet weak var generateButton: UIBarButtonItem!
  /// 入力ボタン
  @IBOutlet weak var inputButton: UIBarButtonItem!
  
  private var loading = true
  
  // ビューのロード時
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // 編集ボタンの追加
    self.navigationItem.rightBarButtonItems?.append(editButtonItem)
    
    updateNavigationItem(for: self.isEditing)
  }
  
  /// ビューが画面に表示された直後
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    // データを読み込む
    let am = AppManager.sharedInstance
    title = am.currentFolder.name
    navigationItem.title = title
    
    if am.restoring {
      if am.currentView == .play {
        if let currentPuzzle = am.currentPuzzle {
          if let puzzleIndex = am.currentFolder.puzzles.firstIndex(of: currentPuzzle) {
            tableView.selectRow(at: IndexPath(row: puzzleIndex, section: 0), animated: false, scrollPosition: .bottom)
            performSegue(withIdentifier: "PlayPuzzle", sender: self)
          }
        }
      } else if am.currentView == .edit {
        //TODO 編集ビューの状態保存は将来対応予定
        //self.editing = YES;
        //[self performSegueWithIdentifier:@"EditProblem" sender:self];
      }
      am.restoring = false
    } else if am.currentView == .play {
      // Backボタンで戻った場合には、アクションは発生しないためここで処理
      if let currentPuzzle = am.currentPuzzle {
        if let puzzleIndex = am.currentFolder.puzzles.firstIndex(of: currentPuzzle) {
          let indexPath = IndexPath(row: puzzleIndex, section: 0)
          let cell = tableView.cellForRow(at: indexPath) as! PuzzleCell
          cell.setup(currentPuzzle)
        }
      }
      
      am.currentPuzzle = nil
      am.currentView = .list
    }
  }
  
  override func setEditing(_ editing: Bool, animated: Bool) {
//    if loading {
//      navigationItem.leftBarButtonItems?.removeSubrange(1 ..< 5)
//      loading = false
//    } else {
    updateNavigationItem(for: editing)
//    }
    super.setEditing(editing, animated: animated)
  }
  
  /// ナビゲーションバー上のボタンを状況に応じて更新する.
  func updateNavigationItem(for editing: Bool) {
    if editing {
      folderButton.isEnabled = false
      
      inputButton.isEnabled = false
      generateButton.isEnabled = false
//      navigationItem.leftBarButtonItems?.insert(folderButton, at: 0)
//      navigationItem.leftBarButtonItems?.removeSubrange(1 ..< 5)
      
//      navigationItem.rightBarButtonItems?.append(inputButton)
//      navigationItem.rightBarButtonItems?.append(generateButton)
    } else {
      folderButton.isEnabled = true
      moveButton.isEnabled = false
      modifyButton.isEnabled = false
      copyButton.isEnabled = false
      deleteButton.isEnabled = false
      
      inputButton.isEnabled = true
      generateButton.isEnabled = true
//      navigationItem.leftBarButtonItems?.append(moveButton)
//      navigationItem.leftBarButtonItems?.append(modifyButton)
//      navigationItem.leftBarButtonItems?.append(copyButton)
//      navigationItem.leftBarButtonItems?.append(deleteButton)
//      navigationItem.leftBarButtonItems?.remove(at: 0)
//
//      navigationItem.rightBarButtonItems?.removeSubrange(1 ..< 3)
    }
  }

  // 入力ボタン押下時
  @IBAction func inputButtonClicked(_ sender: Any) {
    let dialog = UIAlertController(title: appTitle,
                                   message: "幅と高さを入力して[作成]をタップしください。", preferredStyle: .alert)
    dialog.addTextField(configurationHandler: {$0.keyboardType = UIKeyboardType.numberPad})
    dialog.addTextField(configurationHandler: {$0.keyboardType = UIKeyboardType.numberPad})
    dialog.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler: nil))
    dialog.addAction(UIAlertAction(title: "作成", style: .default, handler: { (_) in
      if let widthStr = dialog.textFields![0].text, let width = Int(widthStr),
          let heightStr = dialog.textFields![1].text, let height = Int(heightStr) {
        let am = AppManager.sharedInstance
        am.currentPuzzle = Puzzle(folder: am.currentFolder, width: width, height: height)
  
        self.performSegue(withIdentifier: "EditPuzzle", sender: sender)
      }
    }))
    dialog.popoverPresentationController?.sourceView = view
    dialog.popoverPresentationController?.sourceRect = view.frame
    present(dialog, animated: true, completion: nil)
  }
  
  // 削除ボタン押下
  @IBAction func deleteClicked(_ sender: Any) {
    let indecies = (tableView.indexPathsForSelectedRows ?? []).reversed()
    let msg = "選択されている\(indecies.count)個の問題が削除されます。\n削除してもよろしいですか？"
    alert(viewController: self, message: msg, handler: {
      let am = AppManager.sharedInstance
      for index in indecies {
        am.currentFolder.puzzles.remove(at: index.row)
      }
      self.tableView.reloadData()
    })
  }
  
  // 複写ボタン押下
  @IBAction func copyClicked(_ sender: Any) {
    let am = AppManager.sharedInstance

    let puzzles = selectedPuzzles()
    for puzzle in puzzles {
      let _ = Puzzle(folder: am.currentFolder, original: puzzle)
    }
    tableView.reloadData()
  }

  // MARK: - TableViewDataSource
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    // #warning Incomplete implementation, return the number of sections
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    // #warning Incomplete implementation, return the number of rows
    return AppManager.sharedInstance.currentFolder.puzzles.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "PuzzleCell") as! PuzzleCell
    
    let am = AppManager.sharedInstance
    let puzzle = am.currentFolder.puzzles[indexPath.row]
    cell.setup(puzzle)
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let am = AppManager.sharedInstance
    let puzzle = am.currentFolder.puzzles[indexPath.row]
    am.currentPuzzle = puzzle
    if isEditing {
      modifyButton.isEnabled = self.tableView.indexPathsForSelectedRows?.count == 1
      copyButton.isEnabled = true
      deleteButton.isEnabled = true
    } else {
      if puzzle.status != .editing {
        performSegue(withIdentifier: "PlayPuzzle", sender: self)
      }
    }
  }

  override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
    if isEditing {
      let count: Int? = self.tableView.indexPathsForSelectedRows?.count
      modifyButton.isEnabled = count == 1
      if count == nil {
        copyButton.isEnabled = false
        deleteButton.isEnabled = false
      }
    }
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return isEditing
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    debugPrint(">>")
    let am = AppManager.sharedInstance
    
    if (segue.identifier == "PlayPuzzle") {
      am.currentView = .play
    } else if (segue.identifier == "EditPuzzle") {
      am.currentView = .edit
    } else if (segue.identifier == "ShowFolders") {
      let nc = segue.destination as! UINavigationController
      let fv = nc.visibleViewController as! FoldersViewController
      fv.popoverPresentationController?.delegate = self
    }
  }
  
  func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
    self.title = AppManager.sharedInstance.currentFolder.name
  }
  
  /// その時点で画面で選択されている問題の配列を得る
  ///
  /// - Returns: その時点で画面で選択されている問題の配列
  func selectedPuzzles() -> [Puzzle] {
    var puzzles: [Puzzle] = []
    let am = AppManager.sharedInstance
    let currPuzzles = am.currentFolder.puzzles
    for path in tableView.indexPathsForSelectedRows ?? [] {
      puzzles.append(currPuzzles[path.row])
    }
    return puzzles
  }
  
  // 自動生成が完了したとき
  @IBAction func puzzleGenerated(segue: UIStoryboardSegue) {
    tableView.reloadData()
  }
  
  // フォルダ選択画面でフォルダが選択されたとき
  @IBAction func folderSelected(segue: UIStoryboardSegue) {
    let am = AppManager.sharedInstance
    let fv = segue.source as! FoldersViewController
    if (!self.isEditing) {
      am.currentFolder = fv.selectedFolder
      tableView.reloadData()
      title = am.currentFolder.name
    } else {
      _ = am.movePuzzles(selectedPuzzles(), to: fv.selectedFolder)
    }
  }

  // 呼び出した画面がキャンセルされたとき
  @IBAction func dialogCanceled(segue: UIStoryboardSegue) {
    // 何もしない
  }
  
  
}
