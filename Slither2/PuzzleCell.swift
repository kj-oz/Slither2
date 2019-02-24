//
//  PuzzleCell.swift
//  Slither
//
//  Created by KO on 2019/01/25.
//  Copyright © 2019 KO. All rights reserved.
//

import UIKit

class PuzzleCell: UITableViewCell {
  
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var sizeLabel: UILabel!
  @IBOutlet weak var difficultyLabel: UILabel!
  @IBOutlet weak var statusLabel: UILabel!
  
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
  
  /**
   * 問題セルのenable/disableとenableの場合の色を設定する.
   * @param cell 対象の問題用セル
   * @param enabled enable/disable
   * @param color enabeの場合の文字色
   */
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
