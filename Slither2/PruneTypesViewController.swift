//
//  PruneTypesViewController.swift
//  Slither2
//
//  Created by KO on 2019/02/05.
//  Copyright © 2019 KO. All rights reserved.
//

import UIKit

// 盤面の数字の除去パターンの一覧を表示するビュー
class PruneTypesViewController: UITableViewController {
  
  /// 選択可能な盤面のタイプ
  let pruneTypes = [
    [
      PruneType.free
    ],[
      PruneType.random2Cell,
      PruneType.xSymmetry,
      PruneType.ySymmetry,
      PruneType.pointSymmetry,
      PruneType.hPair,
      PruneType.dPair
    ],[
      PruneType.random4Cell,
      PruneType.xySymmetry,
      PruneType.hPairSymmetry,
      PruneType.dPairSymmetry,
      PruneType.quad
    ]
  ]
  
  /// 完了ボタン
  @IBOutlet weak var doneButton: UIBarButtonItem!
  
  /// 選択された盤面のタイプ
  var selectedPruneType: PruneType? {
    didSet {
      if let _ = selectedPruneType {
        doneButton.isEnabled = true
      } else {
        doneButton.isEnabled = false
      }
    }
  }
  
  // MARK: - UIViewController
  
  // ビューのロード時
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  // ビューの表示前
  override func viewWillAppear(_ animated: Bool) {
    for s in 0 ..< pruneTypes.count {
      for r in 0 ..< pruneTypes[s].count {
        if pruneTypes[s][r] == selectedPruneType {
          tableView.selectRow(at: IndexPath(row: r, section: s), animated: false, scrollPosition: .none)
        }
      }
    }
  }
  
  // MARK: - UITableVewDataSource/Delegate
  
  // セクション数
  override func numberOfSections(in tableView: UITableView) -> Int {
    return pruneTypes.count
  }
  
  // 行数
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return pruneTypes[section].count
  }
  
  // セクションヘッダ文字列
  override func tableView(_ tableView: UITableView,
                 titleForHeaderInSection section: Int) -> String? {
    return ["1セル", "2セル", "4セル"][section]
  }
  
  // セル
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "PruneTypeCell", for: indexPath)
    cell.textLabel?.text = pruneTypes[indexPath.section][indexPath.row].description
    if pruneTypes[indexPath.section][indexPath.row] == selectedPruneType {
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
    selectedPruneType = pruneTypes[indexPath.section][indexPath.row]
  }

  // 行選択解除時
  override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
    let cell = tableView.cellForRow(at: indexPath)
    cell?.accessoryType = .none
  }
}
