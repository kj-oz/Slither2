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
      setColor(UIColor.black)
    } else if puzzle.status == .editing {
      setColor(UIColor.gray)
    } else {
      setColor(UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0))
    }
  }
  
  /// セルの文字の色を設定する
  ///
  /// - Parameter color: 文字色
  func setColor(_ color: UIColor) {
    titleLabel.textColor = color
    sizeLabel.textColor = color
    difficultyLabel.textColor = color
    statusLabel.textColor = color
  }
}
