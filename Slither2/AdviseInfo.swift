//
//  AdviseInfo.swift
//  Slither2
//
//  Created by KO on 2019/08/28.
//  Copyright © 2019 KO. All rights reserved.
//

import Foundation
import UIKit

class AdviseInfo {
  static let mainColor = UIColor.red
  static let adviseColor = UIColor.green
  static let relatedColor = UIColor.orange
  
  struct Style {
    let color: UIColor
    let showGate: Bool
    let enlargeNode: Bool
    let showCellColor: Bool
    
    init(color: UIColor, showGate: Bool = false, enlargeNode: Bool = true, showCellColor: Bool = false) {
      self.color = color
      self.showGate = showGate
      self.enlargeNode = enlargeNode
      self.showCellColor = showCellColor
    }
  }
  
  func style(of element: Element) -> Style? {
    return nil
  }
}

class CheckResultAdviseInfo : AdviseInfo {
  var checked: Set<Element> = []
  
  init(_ checked: [Element]) {
    self.checked = Set<Element>(checked)
  }
  
  override func style(of element: Element) -> Style? {
    if checked.contains(element) {
      return Style(color: AdviseInfo.mainColor)
    }
    return nil
  }
//
//  func add(_ checked: Element...) {
//    self.checked = self.checked.union(checked)
//  }
}
