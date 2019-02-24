//
//  BoardTypesViewController.swift
//  Slither
//
//  Created by KO on 2019/02/05.
//  Copyright © 2019 KO. All rights reserved.
//

import UIKit

// 盤面の数字の配置パターンの一覧を表示するビュー
class BoardTypesViewController: UITableViewController {
  
  /// 選択可能な盤面のタイプ
  let boardTypes = [
    [
      BoardType.free,
      BoardType.xSymmetry,
      BoardType.ySymmetry,
      BoardType.xySymmetry,
      BoardType.pointSymmetry,
      BoardType.hPair,
      BoardType.dPair,
      BoardType.hPairSymmetry,
      BoardType.dPairSymmetry,
      BoardType.quad
    ],[
      BoardType.random2Cell,
      BoardType.random4Cell
    ]
  ]
  
  /// 完了ボタン
  @IBOutlet weak var doneButton: UIBarButtonItem!
  
  /// 選択された盤面のタイプ
  var selectedBoardType: BoardType? {
    didSet {
      if let _ = selectedBoardType {
        doneButton.isEnabled = true
      } else {
        doneButton.isEnabled = false
      }
    }
  }
  
  // ビューのロード時
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  // ビューの表示前
  override func viewWillAppear(_ animated: Bool) {
    for s in 0 ..< boardTypes.count {
      for r in 0 ..< boardTypes[s].count {
        if boardTypes[s][r] == selectedBoardType {
          tableView.selectRow(at: IndexPath(row: r, section: s), animated: false, scrollPosition: .none)
        }
      }
    }
  }
  
  // MARK: - UITableVewDataSource
  // セクション数
  override func numberOfSections(in tableView: UITableView) -> Int {
    return boardTypes.count
  }
  
  // 行数
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return boardTypes[section].count
  }
  
  // セクションヘッダ文字列
  override func tableView(_ tableView: UITableView,
                 titleForHeaderInSection section: Int) -> String? {
    return section == 0 ? "直接指定" : "ランダム"
  }
  
  // セル
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "BoardTypeCell", for: indexPath)
    cell.textLabel?.text = boardTypes[indexPath.section][indexPath.row].description
    if boardTypes[indexPath.section][indexPath.row] == selectedBoardType {
      cell.accessoryType = .checkmark
    } else {
      cell.accessoryType = .none
    }
    return cell
  }
  
  // 行選択時
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let cell = tableView.cellForRow(at: indexPath)
    cell?.accessoryType = .checkmark
    selectedBoardType = boardTypes[indexPath.section][indexPath.row]
  }

  // 行選択解除時
  override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
    let cell = tableView.cellForRow(at: indexPath)
    cell?.accessoryType = .none
  }
}
