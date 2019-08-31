//
//  Solver+GateCheck.swift
//  Slither
//
//  Created by KO on 2018/11/09.
//  Copyright © 2018年 KO. All rights reserved.
//

import Foundation

// MARK: - セル4隅のゲートに関するチェック

extension Solver {
  /// 与えられた1のCellの与えられたコーナーの斜めに接するCellとの関係のチェックを行う
  ///
  /// - Parameters:
  ///   - cell: 対象のCell
  ///   - h: 水平方向の位置（0:左側、1:右側)
  ///   - v: 鉛直方向の位置（0:上側、1:下側）
  /// - Throws: 解の探索時例外
  func checkGateC1(cell: Cell, h: Int, v: Int) throws {
    let viEdge = cell.vEdges[h]
    let hiEdge = cell.hEdges[v]
    let voEdge = viEdge.straightEdges[v]
    let hoEdge = hiEdge.straightEdges[h]
    let node = hiEdge.nodes[h]
    let dir = h == v ? 0 : 1
    var gateStatus = node.gateStatus[dir]
    
    if gateStatus == .unset {
      gateStatus = gateStatusOfC1(hiEdge: hiEdge, viEdge: viEdge, hoEdge: hoEdge, voEdge: voEdge)
      if gateStatus != .unset {
        if try setGateStatus(of: node, dir: dir, to: gateStatus) {
          currentStep.gateCheckCells.insert(hoEdge.cells[v])
        }
      } else {
        return
      }
    }
    
    let oh = 1 - h
    let ov = 1 - v
    let oviEdge = cell.vEdges[oh]
    let ohiEdge = cell.hEdges[ov]
    let ovoEdge = oviEdge.straightEdges[ov]
    let ohoEdge = ohiEdge.straightEdges[oh]
    let onode = ohiEdge.nodes[oh]
    
    if gateStatus == .open {
      // Openなら、対象コーナーの内側外側とも1本はOn、1本はOff
      try fillOpenGateEdges(hiEdge: hiEdge, viEdge: viEdge, hoEdge: hoEdge, voEdge: voEdge)
      
      // 逆側のコーナーはClose
      if try setGateStatus(of: onode, dir: dir, to: .close) {
        currentStep.gateCheckCells.insert(ohoEdge.cells[ov])
      }
      // 逆側のコーナーの内側はOff
      try setCloseGateEdgeStatus(hEdge: ohiEdge, vEdge: oviEdge, to: .off)
      // 外側は2本が同じ状態
      try fillCloseGateEdges(hEdge: ohoEdge, vEdge:ovoEdge)
    } else {
      try setCloseGateEdgeStatus(hEdge: hiEdge, vEdge: viEdge, to: .off)
      try fillCloseGateEdges(hEdge: hoEdge, vEdge: voEdge)
      
      if try setGateStatus(of: onode, dir: dir, to: .open) {
        currentStep.gateCheckCells.insert(ohoEdge.cells[ov])
      }
      try fillOpenGateEdges(hiEdge: ohiEdge, viEdge: oviEdge, hoEdge: ohoEdge, voEdge: ovoEdge)
    }
  }
  
  /// 与えられた2のCellの与えられたコーナーの斜めに接するCellとの関係のチェックを行う
  ///
  /// - Parameters:
  ///   - cell: 対象のCell
  ///   - h: 水平方向の位置（0:左側、1:右側)
  ///   - v: 鉛直方向の位置（0:上側、1:下側）
  /// - Throws: 解の探索時例外
  func checkGateC2(cell: Cell, h: Int, v: Int) throws {
    let viEdge = cell.vEdges[h]
    let hiEdge = cell.hEdges[v]
    let voEdge = viEdge.straightEdges[v]
    let hoEdge = hiEdge.straightEdges[h]
    let node = hiEdge.nodes[h]
    let dir = h == v ? 0 : 1
    var gateStatus = node.gateStatus[dir]
    
    let oh = 1 - h
    let ov = 1 - v
    let oviEdge = cell.vEdges[oh]
    let ohiEdge = cell.hEdges[ov]
    let ovoEdge = oviEdge.straightEdges[ov]
    let ohoEdge = ohiEdge.straightEdges[oh]
    
    if gateStatus == .unset {
      gateStatus = gateStatusOfC2(hiEdge: hiEdge, viEdge: viEdge, hoEdge: hoEdge, voEdge: voEdge)
      if gateStatus == .unset {
        if oviEdge.status == .off || ohiEdge.status == .off ||
          ovoEdge.status == .on || ohoEdge.status == .on {
          // 逆側のコーナーの内側のいずれかの辺ががOffまたは外側のいずれかの辺がOnなら
          if voEdge.status == .on || hoEdge.status == .on {
            // 対象のコーナーの外側のいずれかの辺がOnならOpen
            gateStatus = .open
          } else {
            if let _ = board.getC3AcrossC2(from: cell, h: h, v: v) {
              // 対象コーナーの斜め延長上に(間に2を挟んで)3があればOpen
              gateStatus = .open
            }
          }
        }
      }
      if gateStatus != .unset {
        if try setGateStatus(of: node, dir: dir, to: gateStatus) {
          currentStep.gateCheckCells.insert(hoEdge.cells[v])
        }
      } else {
        return
      }
    }
    
    let onode = ohiEdge.nodes[oh]
    
    if gateStatus == .open {
      // Openなら、対象コーナーの内側外側とも1本はOn、1本はOff
      try fillOpenGateEdges(hiEdge: hiEdge, viEdge: viEdge, hoEdge: hoEdge, voEdge: voEdge)
      
      if try setGateStatus(of: onode, dir: dir, to: .open) {
        currentStep.gateCheckCells.insert(ohoEdge.cells[ov])
      }
      // 逆側のコーナーも内側外側とも1本はOn、1本はOff
      try fillOpenGateEdges(hiEdge: ohiEdge, viEdge: oviEdge, hoEdge: ohoEdge, voEdge: ovoEdge)
    } else {
      // Closeなら隣の2つのコーナーがOpen、対角のコーナーはClose
      var dnode = hiEdge.nodes[oh]
      let ddir = 1 - dir
      var dhoEdge = hiEdge.straightEdges[oh]
      var dvoEdge = oviEdge.straightEdges[v]
      if try setGateStatus(of: dnode, dir: ddir, to: .open) {
        currentStep.gateCheckCells.insert(dhoEdge.cells[v])
      }
      try fillOpenGateEdges(hiEdge: hiEdge, viEdge: oviEdge, hoEdge: dhoEdge, voEdge: dvoEdge)
      
      dnode = viEdge.nodes[ov]
      dhoEdge = ohiEdge.straightEdges[h]
      dvoEdge = viEdge.straightEdges[ov]
      if try setGateStatus(of: dnode, dir: ddir, to: .open) {
        currentStep.gateCheckCells.insert(dhoEdge.cells[ov])
      }
      try fillOpenGateEdges(hiEdge: ohiEdge, viEdge: viEdge, hoEdge: dhoEdge, voEdge: dvoEdge)
      
      try fillCloseGateEdges(hEdge: hiEdge, vEdge: viEdge)
      try fillCloseGateEdges(hEdge: hoEdge, vEdge: voEdge)
      
      if try setGateStatus(of: onode, dir: dir, to: .close) {
        currentStep.gateCheckCells.insert(ohoEdge.cells[ov])
      }
      try fillCloseGateEdges(hEdge: ohiEdge, vEdge: oviEdge)
      try fillCloseGateEdges(hEdge: ohoEdge, vEdge: ovoEdge)
      
      // Closeなコーナーの逆側のCellが3ならそのCellの軸対象のコーナーの内側の2辺がOn
      var aCell = oviEdge.cells[oh]
      if aCell.number == 3 {
        let aEdge = aCell.vEdges[oh]
        try changeEdgeStatus(of: aEdge, to: .on)
        try changeEdgeStatus(of: hiEdge.straightEdges[oh], to: .on)
      }
      aCell = ohiEdge.cells[ov]
      if aCell.number == 3 {
        let aEdge = aCell.hEdges[ov]
        try changeEdgeStatus(of: aEdge, to: .on)
        try changeEdgeStatus(of: viEdge.straightEdges[ov], to: .on)
      }
    }
  }
  
  /// 与えられた3のCellの与えられたコーナーの斜めに接するCellとの関係のチェックを行う
  ///
  /// - Parameters:
  ///   - cell: 対象のCell
  ///   - h: 水平方向の位置（0:左側、1:右側)
  ///   - v: 鉛直方向の位置（0:上側、1:下側）
  /// - Throws: 解の探索時例外
  func checkGateC3(cell: Cell, h: Int, v: Int) throws {
    let viEdge = cell.vEdges[h]
    let hiEdge = cell.hEdges[v]
    let voEdge = viEdge.straightEdges[v]
    let hoEdge = hiEdge.straightEdges[h]
    let node = hiEdge.nodes[h]
    let dir = h == v ? 0 : 1
    var gateStatus = node.gateStatus[dir]
    
    if gateStatus == .unset {
      gateStatus = gateStatusOfC3(hiEdge: hiEdge, viEdge: viEdge,hoEdge: hoEdge, voEdge: voEdge)
      if gateStatus != .unset {
        if try setGateStatus(of: node, dir: dir, to: gateStatus) {
          currentStep.gateCheckCells.insert(hoEdge.cells[v])
        }
      } else {
        return
      }
    }
    
    let oh = 1 - h
    let ov = 1 - v
    let oviEdge = cell.vEdges[oh]
    let ohiEdge = cell.hEdges[ov]
    let ovoEdge = oviEdge.straightEdges[ov]
    let ohoEdge = ohiEdge.straightEdges[oh]
    let onode = ohiEdge.nodes[oh]
    
    if gateStatus == .open {
      // Openなら、対象コーナーの内側外側とも1本はOn、1本はOff
      try fillOpenGateEdges(hiEdge: hiEdge, viEdge: viEdge, hoEdge: hoEdge, voEdge: voEdge)
      
      if try setGateStatus(of: onode, dir: dir, to: .close) {
        currentStep.gateCheckCells.insert(ohoEdge.cells[ov])
      }
      // 逆側コーナーの内側2辺はOn
      try setCloseGateEdgeStatus(hEdge: ohiEdge, vEdge: oviEdge, to: .on)
      // 外側2辺はOff
      try setCloseGateEdgeStatus(hEdge: ohoEdge, vEdge: ovoEdge, to: .off)
    } else {
      try setCloseGateEdgeStatus(hEdge: hiEdge, vEdge: viEdge, to: .on)
      try setCloseGateEdgeStatus(hEdge: hoEdge, vEdge: voEdge, to: .off)
      
      if try setGateStatus(of: onode, dir: dir, to: .open) {
        currentStep.gateCheckCells.insert(ohoEdge.cells[ov])
      }
      try fillOpenGateEdges(hiEdge: ohiEdge, viEdge: oviEdge, hoEdge: ohoEdge, voEdge: ovoEdge)
    }
  }
  
  /// 与えられたNodeの与えられた方向のGateの状態を、与えられた状態に変更する
  ///
  /// - Parameters:
  ///   - node: 対象のNode
  ///   - dir: 方向
  ///   - status: 状態
  /// - Returns: 実際に変更されたか（既に変更されていた場合はNO）
  /// - Throws: 解の探索時例外
  func setGateStatus(of node: Node, dir: Int, to status:  GateStatus) throws -> Bool {
    if node.gateStatus[dir] == status {
      return false
    }
    if node.gateStatus[dir] == .unset {
      currentStep.add(action: SetGateStatusAction(node: node, dir: dir, status: status))
      return true
    } else {
      //debug(">>> cannot set to \(status): \(node.id):\(dir) is \(node.gateStatus[dir])")
      throw SolveException.failed(reason: node)
    }
  }
  
  /// 1のセルの1つのコーナーのGateの状態を得る
  ///
  /// - Parameters:
  ///   - hiEdge: 水平方向の内側のEdge
  ///   - viEdge: 鉛直方向の内側のEdge
  ///   - hoEdge: 水平方向の外側のEdge
  ///   - voEdge: 鉛直方向の外側のEdge
  /// - Returns: Gateの状態
  private func gateStatusOfC1(hiEdge:Edge, viEdge: Edge, hoEdge: Edge, voEdge: Edge) -> GateStatus {
    if hiEdge.status == .on || viEdge.status == .on {
      return .open
    } else if hiEdge.status == .off && viEdge.status == .off {
      return .close
    }
    if hoEdge.status == .on {
      if voEdge.status == .on {
        return .close
      } else if voEdge.status == .off {
        return .open
      }
    } else if hoEdge.status == .off {
      if voEdge.status == .on {
        return .open
      } else if voEdge.status == .off {
        return .close
      }
    }
    return .unset
  }
  
  /// 2のセルの1つのコーナーのGateの状態を得る
  ///
  /// - Parameters:
  ///   - hiEdge: 水平方向の内側のEdge
  ///   - viEdge: 鉛直方向の内側のEdge
  ///   - hoEdge: 水平方向の外側のEdge
  ///   - voEdge: 鉛直方向の外側のEdge
  /// - Returns: Gateの状態
  private func gateStatusOfC2(hiEdge:Edge, viEdge: Edge, hoEdge: Edge, voEdge: Edge) -> GateStatus {
    if hiEdge.status == .on {
      if viEdge.status == .on {
        return .close
      } else if viEdge.status == .off {
        return .open
      }
    } else if hiEdge.status == .off {
      if viEdge.status == .on {
        return .open
      } else if viEdge.status == .off {
        return .close
      }
    }
    if hoEdge.status == .on {
      if voEdge.status == .on {
        return .close
      } else if voEdge.status == .off {
        return .open
      }
    } else if hoEdge.status == .off {
      if voEdge.status == .on {
        return .open
      } else if voEdge.status == .off {
        return .close
      }
    }
    return .unset
  }
  
  /// 3のセルの1つのコーナーのGateの状態を得る
  ///
  /// - Parameters:
  ///   - hiEdge: 水平方向の内側のEdge
  ///   - viEdge: 鉛直方向の内側のEdge
  ///   - hoEdge: 水平方向の外側のEdge
  ///   - voEdge: 鉛直方向の外側のEdge
  /// - Returns: Gateの状態
  private func gateStatusOfC3(hiEdge:Edge, viEdge: Edge, hoEdge: Edge, voEdge: Edge) -> GateStatus {
    if hiEdge.status == .off || viEdge.status == .off {
      return .open
    } else if hiEdge.status == .on && viEdge.status == .on {
      return .close
    }
    
    if hoEdge.status == .on || voEdge.status == .on {
      return .open
    } else if hoEdge.status == .off && voEdge.status == .off {
      return .close
    }
    return .unset
  }
  
  /// 開いたGateの内外の2組のEdgeの状態を（可能であれば）設定する
  ///
  /// - Parameters:
  ///   - hiEdge: 水平方向の内側のEdge
  ///   - viEdge: 鉛直方向の内側のEdge
  ///   - hoEdge: 水平方向の外側のEdge
  ///   - voEdge: 鉛直方向の外側のEdge
  /// - Throws: 解の探索時例外
  func fillOpenGateEdges(hiEdge: Edge, viEdge:Edge, hoEdge: Edge, voEdge: Edge) throws {
    if hiEdge.status == .on {
      try changeEdgeStatus(of: viEdge, to: .off)
    } else if hiEdge.status == .off {
      try changeEdgeStatus(of: viEdge, to: .on)
    } else if viEdge.status == .on {
      try changeEdgeStatus(of: hiEdge, to: .off)
    } else if viEdge.status == .off {
      try changeEdgeStatus(of: hiEdge, to: .on)
    }
    
    if hoEdge.status == .on {
      try changeEdgeStatus(of: voEdge, to: .off)
    } else if hoEdge.status == .off {
      try changeEdgeStatus(of: voEdge, to: .on)
    } else if voEdge.status == .on {
      try changeEdgeStatus(of: hoEdge, to: .off)
    } else if voEdge.status == .off {
      try changeEdgeStatus(of: hoEdge, to: .on)
    }
  }
  
  /// 閉じたGateの内部あるいは外部の1組のEdgeの状態を（可能であれば）設定する
  ///
  /// - Parameters:
  ///   - hEdge: 水平方向のEdge
  ///   - vEdge: 鉛直方向のEdge
  /// - Throws: 解の探索時例外
  func fillCloseGateEdges(hEdge: Edge, vEdge: Edge) throws {
    if hEdge.status == .on {
      try changeEdgeStatus(of: vEdge, to: .on)
    } else if hEdge.status == .off {
      try changeEdgeStatus(of: vEdge, to: .off)
    } else if vEdge.status == .on {
      try changeEdgeStatus(of: hEdge, to: .on)
    } else if vEdge.status == .off {
      try changeEdgeStatus(of: hEdge, to: .off)
    }
  }
  
  /// 閉じたGateの内部あるいは外部の1組のEdgeの状態を強制的に所定の状態に設定する
  ///
  /// - Parameters:
  ///   - hEdge: 水平方向のEdge
  ///   - vEdge: 鉛直方向のEdge
  ///   - status: 設定する状態
  /// - Throws: 解の探索時例外
  func setCloseGateEdgeStatus(hEdge: Edge, vEdge: Edge, to status:  EdgeStatus) throws {
    try changeEdgeStatus(of: hEdge, to: status)
    try changeEdgeStatus(of: vEdge, to: status)
  }
  

}
