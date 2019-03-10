//
//  PuzzleCell.swift
//  Slither2
//
//  Created by KO on 2019/01/25.
//  Copyright © 2019 KO. All rights reserved.
//

import UIKit

/// パズル一覧で利用するセル
class PuzzleCell: UITableViewCell {
  
  /// パズル名称
  @IBOutlet weak var titleLabel: UILabel!
  /// サイズ文字列
  @IBOutlet weak var sizeLabel: UILabel!
  /// 難易度文字列（生成時パラメータの表示）
  @IBOutlet weak var difficultyLabel: UILabel!
  /// 状態文字列
  @IBOutlet weak var statusLabel: UILabel!
  
  /// パズルの情報をセットする
  ///
  /// - Parameter puzzle: パズル
  func setup(_ puzzle: Puzzle) {
    titleLabel.text = puzzle.title
    sizeLabel.text = puzzle.sizeString
    difficultyLabel.text = puzzle.genParams
    if puzzle.status != .notStarted {
      statusLabel.text = puzzle.statusString
    } else {
      statusLabel.text = ""
    }
    
    if puzzle.status == .solved {
      setEnabled(true, color: UIColor.black)
    } else if !isEditing && puzzle.status == .editing {
      setEnabled(false, color: UIColor.black)
    } else {
      setEnabled(true, color: UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0))
    }
  }
  
  /// セルのenable/disableとenableの場合の色を設定する
  ///
  /// - Parameters:
  ///   - enabled: enable/disable
  ///   - color: enabeの場合の文字色
  func setEnabled(_ enabled: Bool, color: UIColor) {
    titleLabel.isEnabled = enabled
    sizeLabel.isEnabled = enabled
    difficultyLabel.isEnabled = enabled
    statusLabel.isEnabled = enabled
    
    if enabled {
      titleLabel.textColor = color
      sizeLabel.textColor = color
      difficultyLabel.textColor = color
      statusLabel.textColor = color
    }
  }
}
