//
//  PuzzleView.swift
//  Slither2
//
//  Created by KO on 2018/12/29.
//  Copyright © 2018 KO. All rights reserved.
//

import UIKit

/// パズルビューのモード
///
/// - view:   表示のみ
/// - play:   EdgeのOn、Offの指定
/// - input:  数字の入力
enum PuzzleViewMode {
  case view
  case play
  case input
}

/// パズルビューのデリゲート
protocol PuzzleViewDelegate {
  /// 拡大画面での表示位置（回転後の問題座標系）
  var zoomedPoint: CGPoint { get set }
  
  /// 線の連続入力の開始
  func lineBegan()
  
  /// 何らかの操作が行われた時の発生するイベント
  ///
  /// - Parameter action: 操作
  func actionDone(_ action: Action)
  
  /// 線の連続入力の終了
  func lineEnded()
}

/// スリザーリンク専用のビュー
class PuzzleView: UIView {
  enum PanMode {
    case none
    case pan
    case slideH
    case slideV
    case line
  }
  
  /// 問題の末端の点からの余白（問題座標系）
  static let margin: CGFloat = 1.0
  
  /// 拡大表示時の端部のグレー表示幅（問題座標系）
  static let boderWidth: CGFloat = 0.2
  
  /// 拡大表示時の最小ピッチ（ピクセル単位）
  static let touchablePitch: CGFloat =  44.0
  
  static let sliderWidth: CGFloat = 1.0
  
  static let sliderRailWidth: CGFloat = 0.4
  
  /// 盤面の情報の取得、設定を行うデリゲート
  var delegate: PuzzleViewDelegate?
  
  /// 描画対象の盤面データ
  var board: Board?
  
  /// ビューのモード
  var mode = PuzzleViewMode.play
  
  /// 拡大画面での表示範囲（回転後の問題座標系）
  var zoomedArea: CGRect = CGRect.zero
  
  /// 各種ジェスチャーリコグナイザ
  var panGr: UIPanGestureRecognizer?
  var pinchGr: UIPinchGestureRecognizer?
  var tap1Gr: UITapGestureRecognizer?
  var tap2Gr: UITapGestureRecognizer?
  
  /// 線の連続入力時の軌跡
  var tracks: [CGPoint] = []
  
  /// タップ位置にノードが含まれているかどうかの判定の半径
  var r: CGFloat = 0.0
  
  /// 線の連続入力時の直前にたどったノード
  var prevNode: Node?
  
  /// 線の連続入力時の直前にたどった辺（微小のドラッグをタップとして扱うため）
  var prevEdge: Edge?
  
  var panMode = PanMode.none
  
  /// ズーム中かどうか
  var zoomed  = true
  
  ///
  var currentPitch: CGFloat = 0.0
  
  var currentOrigin: CGPoint = CGPoint.zero
  
  /// 回転しているかどうか
  /// 問題の縦横比と画面の縦横比の方向が一致していなければ回転
  /// 問題が正方形の場合縦向きとして扱う
  var rotated = false
  
  /// 拡大領域を調整したか
  /// 初回描画時、及び回転時に拡大領域の調整が実行される
  var adjusted = false
  
  /// 画面座標系でのズーム時の問題原点（左上）の座標と点の間隔
  var zx0: CGFloat = 0.0
  var zy0: CGFloat = 0.0
  var zpitch: CGFloat = 0.0
  
  /// 画面座標系での全体表示時の問題原点（左上）の座標と点の間隔
  var ax0: CGFloat = 0.0
  var ay0: CGFloat = 0.0
  var apitch: CGFloat = 0.0
  
  /// 問題座標系でのズームエリアの可動範囲
  var zoomableArea = CGRect.zero
  
  /// 拡大時の盤面サイズが画面より小さく、スクロールの必要がない場合にYES
  var fixH = false
  var fixV = false
  
  /// 描画色
  var boardColor = UIColor(red: 0.95, green: 0.95, blue: 0.9, alpha: 1.0)
  var erasableColor = UIColor(red: 0.0, green: 0.5, blue: 0.9, alpha: 1.0)
//  var zoomAreaStrokeColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.2)
//  var zoomAreaFillColor = UIColor(red:1.0, green:1.0, blue:0.0, alpha:0.1)
  var bgColor = UIColor.lightGray
  var trackColor = UIColor(red:0.0, green:1.0, blue:1.0, alpha:0.03)
  var sliderColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
  var sliderRailColor = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)
  var sliderAreaColor = UIColor(red: 0.0, green: 0.5, blue: 0.9, alpha: 1.0)
  

  // MARK: - 初期化
  // コンストラクタ
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  // Storyboardからの復元時
  override func awakeFromNib() {
    // NOTE この段階ではまだdelegateは設定されていない
    panGr = UIPanGestureRecognizer(target: self, action: #selector(panned))
    pinchGr = UIPinchGestureRecognizer(target: self, action: #selector(pinched))
    tap1Gr = UITapGestureRecognizer(target: self, action: #selector(tapped1))
    tap2Gr = UITapGestureRecognizer(target: self, action: #selector(tapped2))
    tap2Gr!.numberOfTouchesRequired = 2
    
    self.addGestureRecognizer(panGr!)
    self.addGestureRecognizer(pinchGr!)
    self.addGestureRecognizer(tap1Gr!)
    self.addGestureRecognizer(tap2Gr!)
//
//    // 定数
    zpitch = PuzzleView.touchablePitch
    r = zpitch * 0.5;
  }
  
  
  /// 盤面の設定
  ///
  /// - Parameter board: 盤面
  func setBoard(_ board: Board) {
    self.board = board
    rotated = isRotated()

    adjusted = false
//    zoomed = true
//    currentPitch = zpitch
    // この時点では、ツールバーがある前提のビューのサイズとなるので
    // adjustZoomedArea()は実行不可
    zoomed = false
//    currentPitch = apitch
//    currentOrigin = CGPoint(x: ax0, y: ay0)
  }
  
  /// MARK: - 描画
  
  // 描画
  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else {
      return
    }
    let boardColor = self.boardColor.cgColor
    let erasableColor = self.erasableColor.cgColor
//    let zoomAreaStrokeColor = self.zoomAreaStrokeColor.cgColor;
//    let zoomAreaFillColor = self.zoomAreaFillColor.cgColor;
    let bgColor = self.bgColor.cgColor;
    let trackColor = self.trackColor.cgColor;
    
    let w = self.frame.size.width
    let h = self.frame.size.height
    
    if let board = board {
      let rotated = isRotated()
      if rotated != self.rotated || !adjusted {
        self.rotated = rotated
        adjustZoomedArea()
      }
      let editing = (mode == .input)
      
      context.setFillColor(bgColor)
      context.fill(CGRect(x: 0.0, y: 0.0, width: w, height: h))
      
      context.setFillColor(boardColor)
      var boardRect: CGRect
      let x0 = currentOrigin.x
      let y0 = currentOrigin.y
      let pitch = currentPitch
      let r = pitch * 0.5
      let margin = (PuzzleView.margin - PuzzleView.boderWidth) * pitch;
      if rotated {
        boardRect = CGRect(x: x0 - margin, y: y0 - CGFloat(board.width) * pitch - margin,
                           width: CGFloat(board.height) * pitch + margin * 2,
                           height: CGFloat(board.width) * pitch + margin * 2)
      } else {
        boardRect = CGRect(x: x0 - margin, y: y0 - margin,
                           width: CGFloat(board.width) * pitch + margin * 2,
                           height: CGFloat(board.height) * pitch + margin * 2)
      }
      context.fill(boardRect)
      
      // タッチの余韻描画
      context.setFillColor(trackColor)
      for track in tracks {
        context.fillEllipse(in: CGRect(x: track.x - r, y: track.y - r, width: 2 * r, height: 2 * r))
      }
      
      drawBoard(context: context, rotate: rotated, erasableColor: erasableColor, editing: editing)
      

      if zoomed {
//        context.setFillColor(bgColor)
//        context.fill(CGRect(x: 0.0, y: 0.0, width: w, height: h))
//
//        context.setFillColor(boardColor)
//        var boardRect: CGRect
//        let margin = (PuzzleView.margin - PuzzleView.boderWidth) * zpitch;
//        if rotated {
//          boardRect = CGRect(x: zx0 - margin, y: zy0 - CGFloat(board.width) * zpitch - margin,
//                             width: CGFloat(board.height) * zpitch + margin * 2,
//                             height: CGFloat(board.width) * zpitch + margin * 2)
//        } else {
//          boardRect = CGRect(x: zx0 - margin, y: zy0 - margin,
//                             width: CGFloat(board.width) * zpitch + margin * 2,
//                             height: CGFloat(board.height) * zpitch + margin * 2)
//        }
//        context.fill(boardRect)
//
//        // タッチの余韻描画
//        context.setFillColor(trackColor)
//        for track in tracks {
//          context.fillEllipse(in: CGRect(x: track.x - r, y: track.y - r, width: 2 * r, height: 2 * r))
//        }
//
//        drawBoard(context: context, rotate: rotated, erasableColor: erasableColor, editing: editing)
        
        drawSlider(context: context, rotate: rotated)
      } else {
//        context.setFillColor(bgColor)
//        context.fill(CGRect(x: 0, y: 0, width: w, height: h))
//
//        let borderW = PuzzleView.boderWidth * apitch
//        context.setFillColor(boardColor)
//        context.fill(CGRect(x: borderW, y: borderW, width: w - 2 * borderW, height: h - 2 * borderW))
//
//        // タッチの余韻描画
//        context.setFillColor(trackColor)
//        for track in tracks {
//          context.fillEllipse(in: CGRect(x: track.x - r, y: track.y - r, width: 2 * r, height: 2 * r))
//        }
//
//        drawBoard(context: context, rotate: rotated, erasableColor: erasableColor, editing: editing)
//
//        context.setFillColor(zoomAreaFillColor)
//        context.setStrokeColor(zoomAreaStrokeColor)
//        let rect = zoomedAreaInView()
//        context.fill(rect)
//        context.stroke(rect)
      }
    }
  }
  
  /// 盤面を描画する
  ///
  /// - Parameters:
  ///   - context: コンテキスト
  ///   - origin: 原点
  ///   - pitch: セルのピッチ
  ///   - rotate: 回転しているかどうか
  ///   - erasableColor: 削除可能な線の色
  ///   - editing: 編集中かどうか
  private func drawBoard(context: CGContext, rotate: Bool, erasableColor: CGColor, editing: Bool) {
    guard let board = board else {
      return
    }
    let pitch = currentPitch
    let charH = 0.8 * pitch
    let pointR = 0.03 * pitch
    let lineW = 0.06 * pitch
    let crossLineW = 0.04 * pitch
    let crossR = 0.08 * pitch
    
    let fixedColor = UIColor.black.cgColor
    
    let x0 = currentOrigin.x
    let y0 = currentOrigin.y
    
    context.setFillColor(fixedColor)
    context.setLineWidth(crossLineW)
    context.setShouldAntialias(false)
    
    var x: CGFloat = 0.0
    var y: CGFloat = 0.0
    for v in 0 ... board.height {
      if rotate {
        x = x0 + CGFloat(v) * pitch
      } else {
        y = y0 + CGFloat(v) * pitch
      }
      for u in 0 ... board.width {
        if rotate {
          y = y0 - CGFloat(u) * pitch;
        } else {
          x = x0 + CGFloat(u) * pitch;
        }
        let rect = CGRect(x: x-pointR, y: y-pointR, width: pointR * 2, height: pointR * 2)
        context.fill(rect)
      }
    }
    
    let chars = ["0", "1", "2", "3"]
    let font = UIFont.systemFont(ofSize: charH)
    
    context.setShouldAntialias(true)
    if editing {
      context.setFillColor(erasableColor)
      
    }
    let size = "0".size(withAttributes: [NSAttributedString.Key.font: font])
    let nx = (pitch - size.width) * 0.5 + 0.5
    let ny = (pitch - size.height) * 0.5
    
    for v in 0 ..< board.height {
      if rotate {
        x = x0 + CGFloat(v) * pitch + nx
      } else {
        y = y0 + CGFloat(v) * pitch + ny
      }
      for u in 0  ..< board.width {
        if rotate {
          y = y0 - CGFloat(u + 1) * pitch + ny
        } else {
          x = x0 + CGFloat(u) * pitch + nx
        }
        let number = board.cellAt(x: u, y: v).number
        if number >= 0 {
          let char = chars[number] as NSString
          char.draw(at: CGPoint(x: x, y: y), withAttributes: [NSAttributedString.Key.font: font])
        }
      }
    }
    
    for v in 0 ... board.height {
      if rotate {
        x = x0 + CGFloat(v) * pitch
      } else {
        y = y0 + CGFloat(v) * pitch
      }
      for u in 0  ..< board.width {
        if rotate {
          y = y0 - CGFloat(u + 1) * pitch
        } else {
          x = x0 + CGFloat(u) * pitch
        }
        let edge = board.hEdgeAt(x: u, y: v)
        context.setFillColor(edge.fixed ? fixedColor : erasableColor)
        context.setStrokeColor(edge.fixed ? fixedColor : erasableColor)
        let status = edge.status
        if status == .on {
          var rect: CGRect
          if rotate {
            rect = CGRect(x: x-lineW*0.5, y: y+pointR, width: lineW, height: pitch-2*pointR)
          } else {
            rect = CGRect(x: x+pointR, y: y-lineW*0.5, width: pitch-2*pointR, height: lineW)
          }
          context.fill(rect)
        } else if status == .off {
          if rotate {
            drawCross(context: context, cx: x, cy: y + 0.5 * pitch, r: crossR)
          } else {
            drawCross(context: context, cx: x + 0.5 * pitch, cy: y, r: crossR)
          }
        }
      }
    }
    
    for v in 0 ..< board.height {
      if rotate {
        x = x0 + CGFloat(v) * pitch
      } else {
        y = y0 + CGFloat(v) * pitch
      }
      for u in 0 ... board.width {
        if rotate {
          y = y0 - CGFloat(u) * pitch
        } else {
          x = x0 + CGFloat(u) * pitch
        }
        let edge = board.vEdgeAt(x: u, y: v)
        context.setFillColor(edge.fixed ? fixedColor : erasableColor)
        context.setStrokeColor(edge.fixed ? fixedColor : erasableColor)
        let status = edge.status
        if status == .on {
          var rect: CGRect
          if rotate {
            rect = CGRect(x: x+pointR, y: y-lineW*0.5, width: pitch-2*pointR, height: lineW)
          } else {
            rect = CGRect(x: x-lineW*0.5, y: y+pointR, width: lineW, height: pitch-2*pointR)
          }
          context.fill(rect)
        } else if status == .off {
          if (rotate) {
            drawCross(context: context, cx: x+0.5*pitch, cy: y, r: crossR)
          } else {
            drawCross(context: context, cx: x, cy: y + 0.5 * pitch, r: crossR)
          }
        }
      }
    }
  }
  
  private func drawSlider(context: CGContext, rotate: Bool) {
    guard let board = board else {
      return
    }
    if zoomed {
      let zoomedArea = zoomedAreaInView()

      let w = self.frame.size.width
      let h = self.frame.size.height
      var hasSliderH = false
      var hasSliderV = false
      let sliderW = PuzzleView.sliderWidth * zpitch
      let sliderR0 = (PuzzleView.sliderWidth + PuzzleView.sliderRailWidth) * 0.5 * zpitch
      let sliderRW = PuzzleView.sliderRailWidth * zpitch
      let sliderColor = self.sliderColor.cgColor
      let sliderRailColor = self.sliderRailColor.cgColor
      let sliderAreaColor = self.sliderAreaColor.cgColor
      
      var wholeArea: CGRect
      let margin = PuzzleView.margin * apitch;
      if rotated {
        wholeArea = CGRect(x: ax0 - margin, y: ay0 - CGFloat(board.width) * apitch - margin,
                           width: CGFloat(board.height) * apitch + margin * 2,
                           height: CGFloat(board.width) * apitch + margin * 2)
      } else {
        wholeArea = CGRect(x: ax0 - margin, y: ay0 - margin,
                           width: CGFloat(board.width) * apitch + margin * 2,
                           height: CGFloat(board.height) * apitch + margin * 2)
      }

      if (!rotated && !fixH || rotated && !fixV) {
        let rect = CGRect(x: 0, y: h - sliderW, width: w, height: sliderW)
        context.setFillColor(sliderColor)
        context.fill(rect)
        let rrect = CGRect(x: wholeArea.origin.x, y: h - sliderR0,
                           width: wholeArea.width, height: sliderRW)
        context.setFillColor(sliderRailColor)
        context.fill(rrect)
        hasSliderH = true
      }
      if (!rotated && !fixV || rotated && !fixH) {
        let he = hasSliderH ? h - sliderW : h
        let rect = CGRect(x: w - sliderW, y: 0, width: sliderW, height: he)
        context.setFillColor(sliderColor)
        context.fill(rect)
        let rrect = CGRect(x: w - sliderR0, y: wholeArea.origin.y,
                           width: sliderRW, height: wholeArea.height)
        context.setFillColor(sliderRailColor)
        context.fill(rrect)
        hasSliderV = true
      }
      if (hasSliderH) {
        let zrect = CGRect(x: zoomedArea.origin.x, y: h - sliderR0,
                           width: zoomedArea.width, height: sliderRW)
        context.setFillColor(sliderAreaColor)
        context.fill(zrect)
        hasSliderH = true
      }
      if (hasSliderV) {
        let zrect = CGRect(x: w - sliderR0, y: zoomedArea.origin.y,
                           width: sliderRW, height: zoomedArea.height)
        context.setFillColor(sliderAreaColor)
        context.fill(zrect)
      }
    }
  }
//  private func drawSlider(context: CGContext, origin: CGPoint, rotate: Bool) {
//    guard let board = board else {
//      return
//    }
//    if zoomed {
//      let x0 = origin.x
//      let y0 = origin.y
//      var x: CGFloat = 0.0
//      var y: CGFloat = 0.0
//      let bgColor = self.bgColor.cgColor;
//
//      let w = self.frame.size.width
//      let h = self.frame.size.height
//      let sliderW = PuzzleView.sliderWidth * zpitch
//      let lineW = 0.06 * zpitch
//      let sliderColor = self.sliderColor.cgColor
//      var bothSlider = true
//      if (!rotated && !fixH || rotated && !fixV) {
//        let rect = CGRect(x: 0, y: h - sliderW, width: w, height: sliderW)
//        context.setFillColor(sliderColor)
//        context.fill(rect)
//        if rotated {
//          let x = w - sliderW * 0.65
//          for u in 0 ... board.width {
//            y = y0 + CGFloat(u) * zpitch
//            context.setFillColor(bgColor)
//            context.setStrokeColor(bgColor)
//            let rect = CGRect(x: x, y: y-lineW*0.5, width: sliderW * 0.3, height: lineW)
//            context.fill(rect)
//          }
//        } else {
//          let y = h - sliderW * 0.65
//          for u in 0 ... board.width {
//            x = x0 + CGFloat(u) * zpitch
//            context.setFillColor(bgColor)
//            context.setStrokeColor(bgColor)
//            let rect = CGRect(x: x-lineW*0.5, y: y, width: lineW, height: sliderW * 0.3)
//            context.fill(rect)
//          }
//        }
//      } else {
//        bothSlider = false
//      }
//
//      if (!rotated && !fixV || rotated && !fixH) {
//        let rect = CGRect(x: w - sliderW, y: 0, width: sliderW, height: h)
//        context.setFillColor(sliderColor)
//        context.fill(rect)
//        if rotated {
//          let y = h - sliderW * 0.65
//          for v in 0 ... board.height {
//            x = x0 + CGFloat(v) * zpitch
//            context.setFillColor(bgColor)
//            context.setStrokeColor(bgColor)
//            let rect = CGRect(x: x-lineW*0.5, y: y, width: lineW, height: sliderW * 0.3)
//            context.fill(rect)
//          }
//        } else {
//          let x = w - sliderW * 0.65
//          for v in 0 ... board.height {
//            y = y0 + CGFloat(v) * zpitch
//            context.setFillColor(bgColor)
//            context.setStrokeColor(bgColor)
//            let rect = CGRect(x: x, y: y-lineW*0.5, width: sliderW * 0.3, height: lineW)
//            context.fill(rect)
//          }
//        }
//      } else {
//        bothSlider = false
//      }
//
//      if bothSlider {
//        context.setFillColor(bgColor)
//        let rect = CGRect(x: w - sliderW, y: h - sliderW, width: sliderW, height: sliderW)
//        context.fill(rect)
//      }
//    }
//  }

  /// 線無しを示すバツを描画する
  ///
  /// - Parameters:
  ///   - context: コンテキスト
  ///   - cx: バツの中心のX座標
  ///   - cy: バツの中心のY座標
  ///   - r: バツの腕の長さ
  private func drawCross(context: CGContext, cx: CGFloat, cy: CGFloat, r: CGFloat) {
    let x1 = cx - r
    let y1 = cy - r
    let x2 = cx + r
    let y2 = cy + r
    var points: [CGPoint] = []
    points.append(CGPoint(x: x1, y: y1))
    points.append(CGPoint(x: x2, y: y2))
    context.strokeLineSegments(between: points)
    points[0] = CGPoint(x: x1, y: y2)
    points[1] = CGPoint(x: x2, y: y1)
    context.strokeLineSegments(between: points)
  }
  
  // MARK: - プライベートメソッド（ジェスチャー）
  
  // パン：1本指　拡大時-線、全体表示時-ズーム位置移動、２本指　拡大時-スクロール
  @objc func panned(_ sender: Any) {
    if mode == .play {
      if panGr!.state == .began {
        let pos = panGr!.location(in: self)
        panMode = .line
        if zoomed {
          if (!rotated && !fixH || rotated && !fixV) &&
              pos.y > frame.height - PuzzleView.sliderWidth * zpitch {
            panMode = .slideH
          } else if (!rotated && !fixV || rotated && !fixH) &&
              pos.x > frame.width - PuzzleView.sliderWidth * zpitch {
            panMode = .slideV
          }
        }
      }
      if panMode == .slideH || panMode == .slideV {
        pan()
      } else {
        line()
      }
      if panGr!.state == .ended {
        panMode = .none
      }
    }
  }
  
  /// ズーム範囲の移動
  private func pan() {
    var translation = panGr!.translation(in: self)
    panGr!.setTranslation(CGPoint.zero, in: self)
    let location = subtract(pt1: panGr!.location(in: self), pt2: translation)
    let rect = zoomedAreaInView()

    var shouldPan = false
    if panMode == .slideH && rect.minX < location.x && location.x < rect.maxX {
      translation.y = 0
      shouldPan = true
    } else if panMode == .slideV && rect.minY < location.y && location.y < rect.maxY {
      translation.x = 0
      shouldPan = true
    }
    if shouldPan {
      if rotated {
        setZoomedAreaTo(rect: zoomedArea.offsetBy(dx: -translation.y / apitch, dy: translation.x / apitch))
      } else {
        setZoomedAreaTo(rect: zoomedArea.offsetBy(dx:  translation.x / apitch, dy: translation.y / apitch))
      }
      setNeedsDisplay()
    }
    
//    var translation = panGr!.translation(in: self)
//    panGr!.setTranslation(CGPoint.zero, in: self)
//    if panMode == .slideH {
//      translation.y = 0
//    } else {
//      translation.x = 0
//    }
//    if rotated {
//      setZoomedAreaTo(rect: zoomedArea.offsetBy(dx: translation.y / zpitch, dy: -translation.x / zpitch))
//    } else {
//      setZoomedAreaTo(rect: zoomedArea.offsetBy(dx: -translation.x / zpitch, dy: -translation.y / zpitch))
//    }
    setNeedsDisplay()
  }
  
  /// 線の描画
  private func line() {
    guard let board = board else {
      return
    }
    let state = panGr!.state
    if state == .began {
      debugPrint(">>START\n")
      tracks.removeAll()
      prevNode = nil
      delegate?.lineBegan()
      
      let translation = panGr!.translation(in: self)
      var track = panGr!.location(in: self)
      track = subtract(pt1: track, pt2: translation)
      tracks.append(track)
      let node = findNode(point: track)
      debugPrint("node0:%s\n", node != nil ? node!.id : "(nil)");
      if let node = node {
        prevNode = node
      }
      prevEdge = findEdge(point: track)
    }
    var track: CGPoint
    track = panGr!.location(in: self)
    tracks.append(track)
    
    let node = findNode(point: track)
    debugPrint("node:%s-%s\n", node != nil ? node!.id : "(nil)",
               prevNode != nil ? prevNode!.id : "(nil)")
    if let node = node, node != prevNode {
      if let prevNode = prevNode {
        let edge = board.getJointEdge(of: prevNode, and: node)
        debugPrint("> edge:%s\n", edge != nil ? edge!.id : "(nil)")
        if let edge = edge, edge.status == .unset {
          let action = SetEdgeStatusAction(edge: edge, status: .on)
          delegate!.actionDone(action)
          prevEdge = nil
        }
      }
      prevNode = node
    }
    let edge = findEdge(point: track)
    if let edge = edge, edge != prevEdge {
      prevEdge = nil
    }
    
    setNeedsDisplay()
    
    if state == .ended && prevEdge != nil && edge != nil && !edge!.fixed {
      tap(edge: edge!)
    }
    if state == .ended || state == .cancelled {
      delegate!.lineEnded()
      perform(#selector(clearTrackes), with: nil, afterDelay: 1)
    }
  }
  
  // ピンチ
  @objc func pinched(_ sender: Any) {
    let scale = pinchGr!.scale
    if scale < 1 && zoomed {
      if apitch != zpitch {
        zoomed = false
        currentPitch = apitch
        currentOrigin = CGPoint(x: ax0, y: ay0)
      } else {
        return
      }
    } else if scale > 1 && !zoomed {
      let (cx, cy) = locationInPuzzle(point: pinchGr!.location(in: self))
      setZoomedAreaTo(center: CGPoint(x: cx, y: cy))
      
      zoomed = true
      currentPitch = zpitch
      currentOrigin = CGPoint(x: zx0, y: zy0)
    } else {
      return
    }
    r = currentPitch * 0.5
    setNeedsDisplay()
  }
  
  // タップ：×またはクリア
  @IBAction func tapped1(_ sender: Any) {
    // Note: tapのイベントのstateは常に3になる
    let track: CGPoint = tap1Gr!.location(in: self)
    tracks.append(track)
    switch mode {
    case .input:
      if let cell = findCell(point: track) {
        let oldNumber = cell.number
        let newNumber = oldNumber == 3 ? -1 : oldNumber + 1
        let action = SetCellNumberAction(cell: cell, number: newNumber)
        delegate!.actionDone(action)
      }
    case .play:
      if let edge = findEdge(point: track), !edge.fixed {
        tap(edge: edge)
      }
    default:
      break
    }
    perform(#selector(clearTrackes), with: nil, afterDelay: 1)
    setNeedsDisplay()
  }

  /// 辺上をタップした際の処理（微小パンの場合にもこの処理が呼ばれる）
  ///
  /// - Parameter edge: 辺
  func tap(edge: Edge) {
    let oldStatus = edge.status
    let newStatus: EdgeStatus = oldStatus == .unset ? .off : .unset
    let action = SetEdgeStatusAction(edge: edge, status: newStatus)
    delegate!.actionDone(action)
  }

  // 2本指タップ：ズームの切替
  @IBAction func tapped2(_ sender: Any) {
    if zoomed {
      if apitch != zpitch {
        zoomed = false
      } else {
        return
      }
    } else {
      // TODO ズーム位置の計算
      zoomed = true
    }
    setNeedsDisplay()
  }

  // MARK: - プライベートメソッド（表示領域）
  
  /// 拡大表示時の領域を調整する
  func adjustZoomedArea() {
    guard board != nil else {
      return
    }
    calculateOverallParameter()
    calculateZoomedParameter()
    
    setZoomedAreaTo(center: delegate!.zoomedPoint)
    
    if zoomed {
      currentPitch = zpitch
      currentOrigin = CGPoint(x: zx0, y: zy0)
    } else {
      currentPitch = apitch
      currentOrigin = CGPoint(x: ax0, y: ay0)
    }
    r = currentPitch * 0.5
    
//    let zoomedPoint = delegate!.zoomedPoint
//    let cx = zoomedPoint.x
//    let cy = zoomedPoint.y
//
//    var (zoomedW, zoomedH) = sizeInZoomedPuzzle()
//    if !fixH {
//      zoomedH -= PuzzleView.sliderWidth
//    }
//    if !fixV {
//      zoomedW -= PuzzleView.sliderWidth
//    }
//    var x0 = cx - 0.5 * zoomedW
//    var y0 = cy - 0.5 * zoomedH
//    if !fixH {
//      if x0 < 0 {
//        x0 = -PuzzleView.margin
//      } else if x0 + zoomedW > CGFloat(board.width) {
//        x0 = CGFloat(board.width) + PuzzleView.margin - zoomedW
//      }
//    }
//    if !fixV {
//      if y0 < 0 {
//        y0 = -PuzzleView.margin
//      } else if y0 + zoomedH > CGFloat(board.height) {
//        y0 = CGFloat(board.height) + PuzzleView.margin - zoomedH
//      }
//    }
//    self.setZoomedAreaTo(rect: CGRect(x: x0, y: y0, width: zoomedW, height: zoomedH))
    
    adjusted = true
  }

  /// 全体表示時の位置や点の間隔を予め計算しておく
  func calculateOverallParameter() {
    guard let board = board else {
      return
    }
    let (w, h) = sizeInPuzzleRotation()

    let pitchH = w / (CGFloat(board.width) + 2 * PuzzleView.margin)
    let pitchV = h / (CGFloat(board.height) + 2 * PuzzleView.margin)
    if pitchH > PuzzleView.touchablePitch && pitchV > PuzzleView.touchablePitch {
      // 実際には常にズーム中として扱うため使用されない
      apitch = PuzzleView.touchablePitch
      if rotated {
        ax0 = (h - apitch * CGFloat(board.height)) / 2
        ay0 = w - (w - apitch * CGFloat(board.width)) / 2
      } else {
        ax0 = (w - apitch * CGFloat(board.width)) / 2
        ay0 = (h - apitch * CGFloat(board.height)) / 2
      }
    } else if pitchH < pitchV {
      apitch = pitchH
      if rotated {
        ax0 = (h - apitch * CGFloat(board.height)) / 2
        ay0 = w - apitch * PuzzleView.margin
      } else {
        ax0 = apitch * PuzzleView.margin
        ay0 = (h - apitch * CGFloat(board.height)) / 2
      }
    } else {
      apitch = pitchV
      if rotated {
        ax0 = apitch * PuzzleView.margin
        ay0 = w - (w - apitch * CGFloat(board.width)) / 2
      } else {
        ax0 = (w - apitch * CGFloat(board.width)) / 2
        ay0 = apitch * PuzzleView.margin
      }
    }
  }

  /// ズーム時の位置や点の間隔を予め計算しておく
  func calculateZoomedParameter() {
    guard let board = board else {
      return
    }
    var (w, h) = sizeInZoomedPuzzle()
    var zxmin: CGFloat
    var zxmax: CGFloat
    var zymin: CGFloat
    var zymax: CGFloat
    
    if apitch == PuzzleView.touchablePitch {
      fixH = true
      fixV = true
    } else {
      w -= PuzzleView.sliderWidth
      h -= PuzzleView.sliderWidth
      if CGFloat(board.width) + 2 * PuzzleView.margin < w {
        fixH = true
      } else {
        fixH = false
      }
      
      if CGFloat(board.height) + 2 * PuzzleView.margin < h {
        fixV = true
      } else {
        fixV = false
      }

      if !fixH && fixV {
        w += PuzzleView.sliderWidth
      }
      
      if !fixV && fixH {
        h += PuzzleView.sliderWidth
      }
    }
    
    if fixH {
      zxmax = (w - CGFloat(board.width)) / 2
      zxmin = zxmax
    } else {
      zxmin = w - (CGFloat(board.width) + PuzzleView.margin)
      zxmax = PuzzleView.margin
    }
    
    if fixV {
      zymax = (h - CGFloat(board.height)) / 2
      zymin = zymax
    } else {
      zymin = h - (CGFloat(board.height) + PuzzleView.margin)
      zymax = PuzzleView.margin
    }
    
    zoomableArea = CGRect(x: -zxmax, y: -zymax, width: zxmax + w - zxmin, height: zymax + h - zymin)
  }

  func setZoomedAreaTo(center: CGPoint) {
    guard let board = board else {
      return
    }
    
    let cx = center.x
    let cy = center.y
    
    var (zoomedW, zoomedH) = sizeInZoomedPuzzle()
    if !fixH {
      zoomedH -= PuzzleView.sliderWidth
    }
    if !fixV {
      zoomedW -= PuzzleView.sliderWidth
    }
    var x0 = cx - 0.5 * zoomedW
    var y0 = cy - 0.5 * zoomedH
    if !fixH {
      if x0 < 0 {
        x0 = -PuzzleView.margin
      } else if x0 + zoomedW > CGFloat(board.width) {
        x0 = CGFloat(board.width) + PuzzleView.margin - zoomedW
      }
    }
    if !fixV {
      if y0 < 0 {
        y0 = -PuzzleView.margin
      } else if y0 + zoomedH > CGFloat(board.height) {
        y0 = CGFloat(board.height) + PuzzleView.margin - zoomedH
      }
    }
    self.setZoomedAreaTo(rect: CGRect(x: x0, y: y0, width: zoomedW, height: zoomedH))
  }

  /// 拡大表示領域を設定する
  ///
  /// - Parameter rect: 領域を指定する長方形（問題座標系）
  func setZoomedAreaTo(rect: CGRect) {
    zoomedArea = clumpRect(rect: rect, border: zoomableArea)
    delegate!.zoomedPoint = CGPoint(x: zoomedArea.midX, y: zoomedArea.midY)
    if rotated {
      zx0 = -zoomedArea.origin.y * zpitch
      zy0 = self.frame.size.height + zoomedArea.origin.x * zpitch
    } else {
      zx0 = -zoomedArea.origin.x * zpitch
      zy0 = -zoomedArea.origin.y * zpitch
    }
    if zoomed {
      currentOrigin = CGPoint(x: zx0, y: zy0)
    }
  }
  
  /// 拡大領域の表示座標系上での位置を得る
  ///
  /// - Returns: 拡大領域の表示座標系上での位置
  func zoomedAreaInView() -> CGRect {
    var x: CGFloat
    var y: CGFloat
    var w: CGFloat
    var h: CGFloat
    if rotated {
      x = ax0 + zoomedArea.origin.y * apitch
      y = ay0 - (zoomedArea.origin.x + zoomedArea.size.width) * apitch
      w = zoomedArea.size.height * apitch
      h = zoomedArea.size.width * apitch
    } else {
      x = ax0 + zoomedArea.origin.x * apitch
      y = ay0 + zoomedArea.origin.y * apitch
      w = zoomedArea.size.width * apitch
      h = zoomedArea.size.height * apitch
    }
    return CGRect(x: x, y: y, width: w, height: h)
  }
  
  /// 拡大領域を移動する
  ///
  /// - Parameter translation: 拡大領域を移動する量（表示座標系）
  func panZoomedArea(translation: CGPoint) {
    if rotated {
      setZoomedAreaTo(rect: zoomedArea.offsetBy(dx: translation.y / zpitch, dy: -translation.x / zpitch))
    } else {
      setZoomedAreaTo(rect: zoomedArea.offsetBy(dx: -translation.x / zpitch, dy: -translation.y / zpitch))
    }
  }
  
  // MARK: - プライベートメソッド（検索）
  
  /// 指定の座標の近傍のノードを得る
  ///
  /// - Parameter point: 座標
  /// - Returns: 指定の座標の近傍のノード
  func findNode(point: CGPoint) -> Node? {
    guard let board = board else {
      return nil
    }
    let (xp, yp) = locationInPuzzle(point: point)
    
    var xi = Int(xp + 0.5)
    var yi = Int(yp + 0.5)
    xi = clumpInt(value: xi, min: 0, max: board.width)
    yi = clumpInt(value: yi, min: 0, max: board.height)
    
    let dx = (xp - CGFloat(xi)) * currentPitch
    let dy = (yp - CGFloat(yi)) * currentPitch
    if (dx * dx + dy * dy < r * r) {
      return board.nodeAt(x: xi, y: yi)
    }
    return nil
  }
  
  /// 指定の座標の含まれるセルを得る
  ///
  /// - Parameter point: 座標
  /// - Returns: 指定の座標の含まれるセル
  func findCell(point: CGPoint) -> Cell? {
    guard let board = board else {
      return nil
    }
    let (xp, yp) = locationInPuzzle(point: point)
    var xi = Int(xp)
    var yi = Int(yp)
    xi = clumpInt(value: xi, min: 0, max: board.width - 1)
    yi = clumpInt(value: yi, min: 0, max: board.height - 1)
    
    let dx = (xp - (CGFloat(xi) + 0.5)) * currentPitch
    let dy = (yp - (CGFloat(yi) + 0.5)) * currentPitch
    if dx * dx + dy * dy < r * r {
      return board.cellAt(x: xi, y: yi)
    }
    return nil
  }
  
  /// 指定の座標が中点の近傍の辺を得る
  ///
  /// - Parameter point: 座標
  /// - Returns: 指定の座標が中点の近傍の辺
  private func findEdge(point: CGPoint) -> Edge? {
    guard let board = board else {
      return nil
    }
    let (xp, yp) = locationInPuzzle(point: point)
    var xi = Int(xp + 0.5)
    var yi = Int(yp + 0.5)
    if xi < 0 || xi > board.width || yi < 0 || yi > board.height {
      return nil
    }

    var dx = (xp - CGFloat(xi)) * currentPitch
    var dy = (yp - CGFloat(yi)) * currentPitch
    if (abs(dx) < abs(dy)) {
      yi = Int(yp)
      if yi == board.height {
        return nil
      }
      dy = (yp - (CGFloat(yi) + 0.5)) * currentPitch
      if (dx * dx + dy * dy < r * r) {
        debugPrint(String(format: "VE:%d/%d (%.1f/%.1f)\n", xi, yi, xp, yp))
        return board.vEdgeAt(x: xi, y: yi)
      }
    } else {
      xi = Int(xp)
      if xi == board.width {
        return nil
      }
      dx = (xp - (CGFloat(xi) + 0.5)) * currentPitch
      if (dx * dx + dy * dy < r * r) {
        debugPrint(String(format: "HE:%d/%d (%.1f/%.1f)\n", xi, yi, xp, yp))
        return board.hEdgeAt(x: xi, y: yi)
      }
    }
    return nil
  }
  
  // MARK: - プライベートメソッド（その他）
  
  /// 与えられた点の問題座標系上の位置を求める
  ///
  /// - Parameter point: 対象の点
  /// - Returns: 点の問題座標系上の位置
  private func locationInPuzzle(point: CGPoint) -> (CGFloat, CGFloat) {
    var xp: CGFloat
    var yp: CGFloat
    if rotated {
      xp = -(point.y - currentOrigin.y) / currentPitch
      yp = (point.x - currentOrigin.x) / currentPitch
    } else {
      xp = (point.x - currentOrigin.x) / currentPitch
      yp = (point.y - currentOrigin.y) / currentPitch
    }
    return (xp, yp)
  }
  
  /// 画面のサイズの拡大表示時の問題座標系での値を得る
  ///
  /// - Returns: 画面のサイズの問題座標系での値
  private func sizeInZoomedPuzzle() -> (CGFloat, CGFloat) {
    var w: CGFloat
    var h: CGFloat
    if rotated {
      w = frame.size.height / zpitch
      h = frame.size.width / zpitch
    } else {
      w = frame.size.width / zpitch
      h = frame.size.height / zpitch
    }
    return (w, h)
  }
  
  /// 画面のサイズの問題座標系の回転での値を得る
  ///
  /// - Returns: 画面のサイズの問題座標系の回転での値
  private func sizeInPuzzleRotation() -> (CGFloat, CGFloat) {
    var w: CGFloat
    var h: CGFloat
    if rotated {
      w = frame.size.height
      h = frame.size.width
    } else {
      w = frame.size.width
      h = frame.size.height
    }
    return (w, h)
  }
  
  /// 問題の正規の向きに対して画面が回転しているかどうかを調べる
  ///
  /// - Returns: 問題の正規の向きに対して画面が回転しているかどうか
  private func isRotated() -> Bool {
    guard let board = board else {
      return false
    }
    return board.width > board.height && self.frame.size.width <= self.frame.size.height ||
      board.width <= board.height && self.frame.size.width > self.frame.size.height
  }
  
  /// 画面に表示中の軌跡をクリアする
  @objc private func clearTrackes() {
    tracks.removeAll()
    setNeedsDisplay()
  }
  
}
