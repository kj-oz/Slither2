//
//  Solver+InitCheck.swift
//  Slither
//
//  Created by KO on 2018/11/09.
//  Copyright © 2018年 KO. All rights reserved.
//

import Foundation

// MARK: - 盤面初期のチェック

extension Solver {
  /// 角の数字により確定する辺を設定する
  ///
  /// - Throws: 解の探索時例外
  public func initCorner() throws {
    try initCorner(h: 0, v: 0)
    try initCorner(h: 0, v: 1)
    try initCorner(h: 1, v: 0)
    try initCorner(h: 1, v: 1)
  }
  
  /// 指定の位置の角の数字により確定する辺を設定する
  ///
  /// - Parameters:
  ///   - h: 水平方向位置（0:左側、1:右側）
  ///   - v: 鉛直方向位置（0:上側、1:下側）
  /// - Throws: 解の探索時例外
  private func initCorner(h: Int, v: Int) throws {
    let x = h > 0 ? board.width - 1 : 0
    let y = v > 0 ? board.height - 1 : 0
    let dx = h > 0 ? -1 : 1
    let dy = v > 0 ? -1 : 1
    
    switch board.cellAt(x: x, y: y).number {
    case 1:
      try changeEdgeStatus(of: board.vEdgeAt(x: x+h, y: y), to: .off)
      try changeEdgeStatus(of: board.hEdgeAt(x: x, y: y+v), to: .off)
    case 2:
      try changeEdgeStatus(of: board.vEdgeAt(x: x+h, y: y+dy), to: .on)
      try changeEdgeStatus(of: board.hEdgeAt(x: x+dx, y: y+v), to: .on)
      if board.cellAt(x: x+dx, y: y).number == 3 {
        try changeEdgeStatus(of: board.vEdgeAt(x: x+h+dx+dx, y: y), to: .on)
      }
      if board.cellAt(x: x, y: y+dy).number == 3 {
        try changeEdgeStatus(of: board.hEdgeAt(x: x, y: y+v+dy+dy), to: .on)
      }
    case 3:
      try changeEdgeStatus(of: board.vEdgeAt(x: x+h, y: y), to: .on)
      try changeEdgeStatus(of: board.hEdgeAt(x: x, y: y+v), to: .on)
    default:
      break
    }
  }
  
  /// 0により確定する辺を設定する
  ///
  /// - Throws: 解の探索時例外
  public func initC0() throws {
    for y in 0 ..< board.height {
      for x in 0 ..< board.width {
        let cell = board.cellAt(x: x, y: y)
        if cell.number == 0 {
          try changeEdgeStatus(of: cell.hEdges[0], to: .off)
          try changeEdgeStatus(of: cell.vEdges[0], to: .off)
          try changeEdgeStatus(of: cell.hEdges[1], to: .off)
          try changeEdgeStatus(of: cell.vEdges[1], to: .off)
        }
      }
    }
  }
  
  /// 3と周辺の数字により確定する辺を設定する
  ///
  /// - Throws: 解の探索時例外
  public func initC3() throws {
    for y in 0 ..< board.height {
      for x in 0 ..< board.width {
        let cell = board.cellAt(x: x, y: y)
        if cell.number == 3 {
          if x < board.width - 1 {
            let aCell = cell.vEdges[1].cells[1]
            if aCell.number == 3 {
              // 左側のセルが3の場合
              try changeEdgeStatus(of: cell.vEdges[0], to: .on)
              try changeEdgeStatus(of: cell.vEdges[1], to: .on)
              try changeEdgeStatus(of: aCell.vEdges[1], to: .on)
              if y > 0 {
                try changeEdgeStatus(of: cell.vEdges[1].straightEdges[0], to: .off)
                if cell.hEdges[0].cells[0].number == 2 {
                  try changeEdgeStatus(of: cell.hEdges[0].cells[0].hEdges[0], to: .on)
                  if x > 0 {
                    try changeEdgeStatus(of: cell.hEdges[0].straightEdges[0], to: .off)
                  }
                }
                if aCell.hEdges[0].cells[0].number == 2 {
                  try changeEdgeStatus(of: aCell.hEdges[0].cells[0].hEdges[0], to: .on)
                  if x < board.width - 2 {
                    try changeEdgeStatus(of: aCell.hEdges[0].straightEdges[1], to: .off)
                  }
                }
              }
              if y < board.height - 1 {
                try changeEdgeStatus(of: cell.vEdges[1].straightEdges[1], to: .off)
                if cell.hEdges[1].cells[1].number == 2 {
                  try changeEdgeStatus(of: cell.hEdges[1].cells[1].hEdges[1], to: .on)
                  if x > 0 {
                    try changeEdgeStatus(of: cell.hEdges[1].straightEdges[0], to: .off)
                  }
                }
                if aCell.hEdges[1].cells[1].number == 2 {
                  try changeEdgeStatus(of: aCell.hEdges[1].cells[1].hEdges[1], to: .on)
                  if x < board.width - 2 {
                    try changeEdgeStatus(of: aCell.hEdges[1].straightEdges[1], to: .off)
                  }
                }
              }
            }
            
            // 右上方向に2を挟んで3がある場合
            var dCell = board.getC3AcrossC2(from: cell, h: 1, v: 0)
            if let dCell = dCell {
              try changeEdgeStatus(of: cell.hEdges[1], to: .on)
              try changeEdgeStatus(of: cell.vEdges[0], to: .on)
              try changeEdgeStatus(of: dCell.hEdges[0], to: .on)
              try changeEdgeStatus(of: dCell.vEdges[1], to: .on)
            }
            // 右下方向に2を挟んで3がある場合
            dCell = board.getC3AcrossC2(from: cell, h: 1, v: 1)
            if let dCell = dCell {
              try changeEdgeStatus(of: cell.hEdges[0], to: .on)
              try changeEdgeStatus(of: cell.vEdges[0], to: .on)
              try changeEdgeStatus(of: dCell.hEdges[1], to: .on)
              try changeEdgeStatus(of: dCell.vEdges[1], to: .on)
            }
          }
          if y > 0 {
            let aCell = cell.hEdges[0].cells[0]
            if aCell.number == 3 {
              try changeEdgeStatus(of: cell.hEdges[1], to: .on)
              try changeEdgeStatus(of: cell.hEdges[0], to: .on)
              try changeEdgeStatus(of: aCell.hEdges[0], to: .on)
              if x > 0 {
                try changeEdgeStatus(of: cell.hEdges[0].straightEdges[0], to: .off)
                if cell.vEdges[0].cells[0].number == 2 {
                  try changeEdgeStatus(of: cell.vEdges[0].cells[0].vEdges[0], to: .on)
                  if y < board.height - 1 {
                    try changeEdgeStatus(of: cell.vEdges[0].straightEdges[1], to: .off)
                  }
                }
                if aCell.vEdges[0].cells[0].number == 2 {
                  try changeEdgeStatus(of: aCell.vEdges[0].cells[0].vEdges[0], to: .on)
                  if y > 1 {
                    try changeEdgeStatus(of: aCell.vEdges[0].straightEdges[0], to: .off)
                  }
                }
              }
              if x < board.width - 1 {
                try changeEdgeStatus(of: cell.hEdges[0].straightEdges[1], to: .off)
                if cell.vEdges[1].cells[1].number == 2 {
                  try changeEdgeStatus(of: cell.vEdges[1].cells[1].vEdges[1], to: .on)
                  if y < board.height - 1 {
                    try changeEdgeStatus(of: cell.vEdges[1].straightEdges[1], to: .off)
                  }
                }
                if aCell.vEdges[1].cells[1].number == 2 {
                  try changeEdgeStatus(of: aCell.vEdges[1].cells[1].vEdges[1], to: .on)
                  if y > 1 {
                    try changeEdgeStatus(of: aCell.vEdges[1].straightEdges[0], to: .off)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  
  /// 外周の数字で確定する辺を設定する
  ///
  /// - Throws: 解の探索時例外
  public func initBorder() throws {
    try initVBorder(h: 0)
    try initVBorder(h: 1)
    try initHBorder(v: 0)
    try initHBorder(v: 1)
  }
  
  /// 左右の外周の数字で確定する辺を設定する
  ///
  /// - Parameter h: 水平方向位置（0:左側、1:右側）
  /// - Throws: 解の探索時例外
  private func initVBorder(h: Int) throws {
    let x = h > 0 ? board.width - 1 : 0
    
    for y in 1 ..< board.height - 1 {
      let cell = board.cellAt(x: x, y: y)
      if cell.number == 1 {
        var aCell = board.cellAt(x: x, y: y-1)
        if aCell.number == 1 {
          try changeEdgeStatus(of: cell.hEdges[0], to: .off)
        } else if aCell.number == 3 {
          try changeEdgeStatus(of: board.vEdgeAt(x: x+h, y: y-1), to: .on)
          try changeEdgeStatus(of: board.vEdgeAt(x: x+1-h, y: y), to: .off)
          try changeEdgeStatus(of: cell.hEdges[1], to: .off)
        }
        aCell = board.cellAt(x: x, y: y+1)
        if aCell.number == 3 {
          try changeEdgeStatus(of: board.vEdgeAt(x: x+h, y: y+1), to: .on)
          try changeEdgeStatus(of: board.vEdgeAt(x: x+1-h, y: y), to: .off)
          try changeEdgeStatus(of: cell.hEdges[0], to: .off)
        }
      }
    }
  }
  
  /// 上下の外周の数字で確定する辺を設定する
  ///
  /// - Parameter v: 鉛直方向位置（0:上側、1:下側）
  /// - Throws: 解の探索時例外
  private func initHBorder(v: Int) throws {
    let y = v > 0 ? board.height - 1 : 0
    
    for x in 1 ..< board.width - 1 {
      let cell = board.cellAt(x: x, y: y)
      if cell.number == 1 {
        var aCell = board.cellAt(x: x-1, y: y)
        if aCell.number == 1 {
          try changeEdgeStatus(of: cell.vEdges[0], to: .off)
        } else if aCell.number == 3 {
          try changeEdgeStatus(of: board.hEdgeAt(x: x-1, y: y+v), to: .on)
          try changeEdgeStatus(of: board.hEdgeAt(x: x, y: y+1-v), to: .off)
          try changeEdgeStatus(of: cell.vEdges[1], to: .off)
        }
        aCell = board.cellAt(x: x+1, y: y)
        if aCell.number == 3 {
          try changeEdgeStatus(of: board.hEdgeAt(x: x+1, y: y+v), to: .on)
          try changeEdgeStatus(of: board.hEdgeAt(x: x, y: y+1-v), to: .off)
          try changeEdgeStatus(of: cell.vEdges[0], to: .off)
        }
      }
    }
  }
}
