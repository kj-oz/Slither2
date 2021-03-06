//
//  PuzzlesViewController.swift
//  Slither2
//
//  Created by KO on 2019/01/25.
//  Copyright © 2019 KO. All rights reserved.
//

import UIKit

/// パズル一覧を表示するビュー
class PuzzlesViewController: UITableViewController,
    FoldersViewDelegate, UIPopoverPresentationControllerDelegate {
  
  /// 名称変更ボタン
  @IBOutlet var renameButton: UIBarButtonItem!
  /// 複写ボタン
  @IBOutlet var copyButton: UIBarButtonItem!
  /// 移動ボタン
  @IBOutlet var moveButton: UIBarButtonItem!
  /// 削除ボタン
  @IBOutlet var deleteButton: UIBarButtonItem!
  /// フォルダボタン
  @IBOutlet var folderButton: UIBarButtonItem!
  /// 自動生成ボタン
  @IBOutlet var generateButton: UIBarButtonItem!
  /// 入力ボタン
  @IBOutlet var inputButton: UIBarButtonItem!
  
  /// ヘルプボタン
  @IBOutlet weak var helpButton: UIBarButtonItem!
  
  var logger: Logger!
  
  // MARK: - UIViewController

  // ビューのロード時
  override func viewDidLoad() {
    super.viewDidLoad()
    
    logger = AppManager.sharedInstance.logger
    logger.log("PuzzlesViewController viewDidLoad")
    
    // 編集ボタンの追加
    self.navigationItem.rightBarButtonItems?.append(editButtonItem)
    
    updateNavigationItems(for: self.isEditing)
  }
  
  /// ビューが画面に表示された直後
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    logger.log("PuzzlesViewController viewDidApear")

    // データを読み込む
    let am = AppManager.sharedInstance
    // alert(viewController: self, message: String(am.solveTimes.last!))
    
    title = am.currentFolder.name
    navigationItem.title = title
    
    if am.restoring {
      if am.currentView == .play || am.currentView == .edit {
        if let currentPuzzle = am.currentPuzzle {
          if let puzzleIndex = am.currentFolder.puzzles.firstIndex(of: currentPuzzle) {
            tableView.selectRow(at: IndexPath(row: puzzleIndex, section: 0), animated: false, scrollPosition: .bottom)
            if am.currentView == .play {
              performSegue(withIdentifier: "PlayPuzzle", sender: self)
            } else {
              performSegue(withIdentifier: "EditPuzzle", sender: self)
            }
          }
        }
      }
      am.restoring = false
    } else if am.currentView == .play || am.currentView == .edit {
      // Backボタンで戻った場合には、アクションは発生しないためここで処理
      if let currentPuzzle = am.currentPuzzle {
        if tableView.numberOfRows(inSection: 0) < am.currentFolder.puzzles.count {
          // 入力ボタン→編集画面からの戻り時
          tableView.reloadData()
        } else if let puzzleIndex = am.currentFolder.puzzles.firstIndex(of: currentPuzzle) {
          let indexPath = IndexPath(row: puzzleIndex, section: 0)
          let cell = tableView.cellForRow(at: indexPath) as! PuzzleCell
          cell.setup(currentPuzzle)
        }
      }
      
      am.currentPuzzle = nil
      am.currentView = .list
    }
  }
  
  /// ビューのアンロード時
  deinit {
    // 表示を消すことがあるため、強参照している
    generateButton = nil
    inputButton = nil
    moveButton = nil
    renameButton = nil
    copyButton = nil
    deleteButton = nil
  }

  // 編集状態が変更されたとき
  override func setEditing(_ editing: Bool, animated: Bool) {
    super.setEditing(editing, animated: animated)
    updateNavigationItems(for: editing)
  }
  
  // MARK: - UITableViewDataSource/Delegate
  
  // 行数
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return AppManager.sharedInstance.currentFolder.puzzles.count
  }
  
  // セル
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "PuzzleCell") as! PuzzleCell
    
    let am = AppManager.sharedInstance
    let puzzle = am.currentFolder.puzzles[indexPath.row]
    cell.setup(puzzle)
    return cell
  }

  // 行が選択された直後
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let am = AppManager.sharedInstance
    let puzzle = am.currentFolder.puzzles[indexPath.row]
    am.currentPuzzle = puzzle
    if isEditing {
      renameButton.isEnabled = self.tableView.indexPathsForSelectedRows?.count == 1
      moveButton.isEnabled = true
      copyButton.isEnabled = true
      deleteButton.isEnabled = true
    } else {
      if puzzle.status == .editing {
        performSegue(withIdentifier: "EditPuzzle", sender: self)
      } else {
        performSegue(withIdentifier: "PlayPuzzle", sender: self)
      }
    }
  }

  // 行の選択が解除された直後
  override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
    if isEditing {
      let count: Int? = self.tableView.indexPathsForSelectedRows?.count
      renameButton.isEnabled = count == 1
      if count == nil {
        moveButton.isEnabled = false
        copyButton.isEnabled = false
        deleteButton.isEnabled = false
      }
    }
  }
  
  // 行が編集可能かどうか
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return isEditing
  }

  // MARK: - FoldersViewDelegate
  
  // フォルダが選択された直後
  func folderDidSelect(_ folder: Folder) {
    let am = AppManager.sharedInstance
    if (!self.isEditing) {
      am.currentFolder = folder
      navigationItem.title = folder.name
    } else {
      _ = am.movePuzzles(selectedPuzzles(), to: folder)
    }
    tableView.reloadData()
  }
  
  // フォルダが名称変更された直後
  func folderDidRename(_ folder: Folder) {
    navigationItem.title = folder.name
  }
  
  // MARK: - ボタンのアクション
  
  // 入力ボタン押下時
  @IBAction func inputButtonTapped(_ sender: Any) {
    let dialog = UIAlertController(title: appTitle,
                                   message: "幅と高さを入力して[作成]をタップしください。", preferredStyle: .alert)
    dialog.addTextField(configurationHandler: {$0.keyboardType = UIKeyboardType.numberPad; $0.placeholder = "幅"})
    dialog.addTextField(configurationHandler: {$0.keyboardType = UIKeyboardType.numberPad; $0.placeholder = "高さ"})
    dialog.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler: nil))
    dialog.addAction(UIAlertAction(title: "作成", style: .default, handler: { (_) in
      if let widthStr = dialog.textFields![0].text, let width = Int(widthStr),
        let heightStr = dialog.textFields![1].text, let height = Int(heightStr) {
        let am = AppManager.sharedInstance
        let id = am.nextPuzzleId()
        am.currentPuzzle = Puzzle(folder: am.currentFolder, id: id, title: id, width: width, height: height)
        
        self.performSegue(withIdentifier: "EditPuzzle", sender: sender)
      }
    }))
    dialog.popoverPresentationController?.sourceView = view
    dialog.popoverPresentationController?.sourceRect = view.frame
    present(dialog, animated: true, completion: nil)
  }
  
  // 削除ボタン押下
  @IBAction func deleteButtonTapped(_ sender: Any) {
    let indecies = (tableView.indexPathsForSelectedRows ?? []).reversed()
    let msg = "選択されている\(indecies.count)個の問題が削除されます。\n削除してもよろしいですか？"
    alert(viewController: self, message: msg, handler: {
      let am = AppManager.sharedInstance
      if am.removePuzzles(self.selectedPuzzles()) {
        self.tableView.reloadData()
      }
    })
  }
  
  // 複写ボタン押下
  @IBAction func copyButtonTapped(_ sender: Any) {
    let am = AppManager.sharedInstance
    am.copyPuzzles(selectedPuzzles())
    tableView.reloadData()
  }
  
  // 名称変更ボタン押下
  @IBAction func renameButtonTapped(_ sender: Any) {
    let puzzle = selectedPuzzles()[0]
    let dialog = UIAlertController(title: appTitle,
                                   message: "タイトルとメモを入力して[変更]をタップしください。", preferredStyle: .alert)
    dialog.addTextField(configurationHandler: {$0.keyboardType = UIKeyboardType.alphabet;
      $0.placeholder = "タイトル"; $0.text = puzzle.title})
    dialog.addTextField(configurationHandler: {$0.keyboardType = UIKeyboardType.alphabet;
      $0.placeholder = "高さ"; $0.text = puzzle.genParams})
    dialog.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler: nil))
    dialog.addAction(UIAlertAction(title: "変更", style: .default, handler: { (_) in
      if let nameStr = dialog.textFields![0].text {
        puzzle.title = nameStr
        puzzle.genParams = dialog.textFields![1].text ?? ""
        puzzle.save()
        let am = AppManager.sharedInstance
        if let puzzleIndex = am.currentFolder.puzzles.firstIndex(of: puzzle) {
          let indexPath = IndexPath(row: puzzleIndex, section: 0)
          let cell = self.tableView.cellForRow(at: indexPath) as! PuzzleCell
          cell.setup(puzzle)
        }
      }
    }))
    dialog.popoverPresentationController?.sourceView = view
    dialog.popoverPresentationController?.sourceRect = view.frame
    present(dialog, animated: true, completion: nil)
  }
  
  // MARK: - ナビゲーション
  
  // セグエの実行の直前
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    debugPrint(">>")
    let am = AppManager.sharedInstance
    
    if segue.identifier == "PlayPuzzle" {
      am.currentView = .play
    } else if segue.identifier == "EditPuzzle" {
      am.currentView = .edit
    } else if segue.identifier == "ShowFolders" {
      let nc = segue.destination as! UINavigationController
      let fv = nc.visibleViewController as! FoldersViewController
      fv.delegate = self
    } else if segue.identifier == "ShowHelp" {
      let hv = segue.destination as? HelpViewController
      let bundle = Bundle.main
      let url: URL? = bundle.url(forResource: "puzzlesview", withExtension: "html", subdirectory: "www")
      hv!.url = url
    } else if segue.identifier == "GeneratePuzzle" {
      let nc = segue.destination as! UINavigationController
      nc.popoverPresentationController?.delegate = self
    }
  }

  // 自動生成が完了したとき
  @IBAction func puzzleGenerated(segue: UIStoryboardSegue) {
    tableView.reloadData()
  }
  
  // フォルダ選択画面でフォルダが選択されたとき
  @IBAction func folderSelected(segue: UIStoryboardSegue) {
    // 何もしない（デリゲート側で処理）
  }

  // 呼び出した画面がキャンセルされたとき
  @IBAction func dialogCanceled(segue: UIStoryboardSegue) {
    // 何もしない
  }
  
  // 生成画面は外をタップしても消せない
  func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool {
    return false
  }
    
  // MARK: - ヘルパメソッド

  /// ナビゲーションバー上のボタンを状況に応じて更新する.
  func updateNavigationItems(for editing: Bool) {
    if editing {
      navigationItem.leftBarButtonItems = [moveButton, renameButton, copyButton, deleteButton]
      navigationItem.rightBarButtonItems = [helpButton, editButtonItem]
      moveButton.isEnabled = false
      renameButton.isEnabled = false
      copyButton.isEnabled = false
      deleteButton.isEnabled = false
    } else {
      navigationItem.leftBarButtonItems = [folderButton]
      navigationItem.rightBarButtonItems = [helpButton, generateButton, inputButton, editButtonItem]
    }
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
}
