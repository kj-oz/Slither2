//
//  PlayViewController.swift
//  Slither2
//
//  Created by KO on 2019/01/30.
//  Copyright © 2019 KO. All rights reserved.
//

import UIKit

/// パズルを実行する画面
class PlayViewController: UIViewController, PuzzleViewDelegate {
  
  /// パズルビュー
  @IBOutlet weak var puzzleView: PuzzleView!
  
  /// アンドゥボタン
  @IBOutlet weak var undoButton: UIBarButtonItem!
  
  /// リドゥボタン
  @IBOutlet weak var redoButton: UIBarButtonItem!
  
  /// アクションボタン
  @IBOutlet weak var actionButton: UIBarButtonItem!
  
  /// パズル
  var puzzle: Puzzle!
  
  /// パズルタイトル
  var puzzleTitle = ""
  
  /// 経過時間更新用タイマー
  var elapsedLabaelUpdateTimer: Timer?
  
  /// 経過時間の開始時刻
  var elapsedStart:  Date?
  
//  /// 前回保存時の時刻
//  var lastSaved: Date?
  
  // MARK: - UIViewController
  
  // ビューロード時
  override func viewDidLoad() {
    super.viewDidLoad()
    let am = AppManager.sharedInstance
    puzzle = am.currentPuzzle!
    print("viewDidLoad:" + puzzle.id)
    if puzzle.status == .notStarted {
      puzzle.status = .solving
    } else if puzzle.actions.count == 0 {
      puzzle.loadActions()
    }
    puzzleTitle = "\(puzzle.title)  (\(puzzle.sizeString))  "
    
    // 念の為計時関係の初期化
    elapsedLabaelUpdateTimer = nil
    elapsedStart = nil
//    lastSaved = nil
    
    // 本来awakeFromNibで設定するはずだが、そのタイミングでは何故かいずれもnil
    puzzleView.delegate = self
    puzzleView.mode = puzzle.status == .solved ? .view : .play
    puzzleView.setBoard(puzzle.board)

    // アプリケーションライフサイクルの通知受信
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(self.applicationDidEnterBackground), name: NSNotification.Name("applicationDidEnterBackground"), object: nil)
    nc.addObserver(self, selector: #selector(self.applicationWillEnterForeground), name: NSNotification.Name("applicationWillEnterForeground"), object: nil)
  }
  
  // ビュー表示直後
  override func viewDidAppear(_ animated: Bool) {
    print("viewDidAppear:" + puzzle.id)
    super.viewDidAppear(animated)
    
    updateButtonStatus()
    startPlay()
  }
  
  // ビューが消える直前
  override func viewWillDisappear(_ animated: Bool) {
    print("viewWillDisappear:" + puzzle.id)
    super.viewWillDisappear(animated)
    stopPlay()
  }

  // MARK: - アプリケーションのアクティブ化・非アクティブ化
  
  /// アプリケーションがバックグラウンドにまわった直後
  @objc func applicationDidEnterBackground() {
    print("applicationDidEnterBackground:" + puzzle.id)
    stopPlay()
  }
  
  /// アプリケーションがフォアグラウンドに戻る直前
  @objc func applicationWillEnterForeground() {
    print("applicationWillEnterForeground:" + puzzle.id)
    startPlay()
  }

  /// プレイを開始する.
  func startPlay() {
    print("startPlay:" + puzzle.id)
    if puzzle.status == .solved {
      return
    }
    elapsedStart = Date()
    updateElapsedlabel()
    
    elapsedLabaelUpdateTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self,
                                 selector: #selector(self.updateElapsedlabel), userInfo: nil, repeats: true)
  }
  
  /// プレイを中断する.
  func stopPlay() {
    print("stopPlay:" + puzzle.id)
    if puzzle.status == .solved {
      return
    }
    elapsedLabaelUpdateTimer!.invalidate()
    if let start = elapsedStart {
      let now = Date()
      let t: TimeInterval = now.timeIntervalSince(start)
      puzzle.elapsedSecond += Int(t)
      puzzle.save()
      elapsedStart = nil
    }
  }

  // 画面の回転を許容する方向
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return .all
  }
  
  // 画面が回転する直前に呼び出される
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    
    puzzleView.setNeedsDisplay()
  }
  
  // MARK: - PuzzleViewDelegateの実装
  
  /// 線の連続入力の開始
  func lineBegan() {
  }
  
  /// 何らかの操作が行われた時の発生するイベント
  func actionDone(_ action: Action) {
    puzzle.addAction(action as! SetEdgeStatusAction)
    undoButton.isEnabled = true
    puzzleView.setNeedsDisplay()
    let now = Date()
    if let start = elapsedStart {
      let t: TimeInterval = now.timeIntervalSince(start)
      if t > 10.0 {
        puzzle.elapsedSecond += Int(t)
        puzzle.save()
        elapsedStart = now
      }
    }
  }

  /// 線の連続入力の終了
  func lineEnded() {
    if let edge = puzzle.board.findOnEdge() {
      let endNode = puzzle.board.getLoopEnd(from: edge.nodes[0], and: edge)
      if endNode == nil {
        let loopStatus = puzzle.board.getLoopStatus(including: edge)
        if loopStatus == .finished {
          puzzle.fix()
          stopPlay()
          
          puzzle.status = .solved
          updateButtonStatus()
          let msg = "正解です。所要時間 \(puzzle.elapsedTimeString))"
          alert(viewController: self, message: msg)
        } else if loopStatus == .cellError {
          alert(viewController: self, title: "ループエラー", message: "条件に合致しないセルがあります。")
        } else if loopStatus == .multiLoop {
          alert(viewController: self, title: "ループエラー", message: "複数のループに分かれています。")
        }
      }
    }
  }
  
  // MARK: - ボタンのアクション
  
  // アクションボタンタップ時
  @IBAction func actionButtonTapped(_ sender: Any) {
    let alert: UIAlertController = UIAlertController(title: "スリザー2", message: "操作”",
                                                     preferredStyle: .actionSheet)
    alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler: nil))
    alert.addAction(UIAlertAction(title: "初期化", style: .destructive, handler: { _ in
      self.initActionSelected(self)
    }))
    alert.addAction(UIAlertAction(title: "未固定部消去", style: .destructive, handler: { _ in
      self.eraseActionSelected(self)
    }))
    alert.addAction(UIAlertAction(title: "固定", style: .default, handler: { _ in
      self.fixActionSelected(self)
    }))
    alert.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem
    self.present(alert, animated: true, completion: nil)
  }
  
  // アンドゥボタンタップ時
  @IBAction func undoButtonTapped(_ sender: Any) {
    puzzle.undo()
    updateButtonStatus()
    puzzleView.setNeedsDisplay()
  }

  // リドゥボタンタップ時
  @IBAction func redoButtonTapped(_ sender: Any) {
    puzzle.redo()
    updateButtonStatus()
    puzzleView.setNeedsDisplay()
  }
  
  // アクションシートの初期化ボタン押下
  @IBAction func initActionSelected(_ sender: Any) {
    confirm(viewController: self, title: "初期化",
            message: "盤面を全て初期化してもよろしいですか？", handler: { answer in
      if answer {
        self.puzzle.resetCount += 1
        self.puzzle.clear()
        self.undoButton.isEnabled = false
        self.puzzleView.setNeedsDisplay()
      }
    })
  }
  
  // アクションシートの消去ボタン押下
  @IBAction func eraseActionSelected(_ sender: Any) {
    confirm(viewController: self, title: "消去",
            message: "固定されていない部分を消去してもよろしいですか？", handler: { answer in
      if answer {
        self.puzzle.erase()
        self.undoButton.isEnabled = false
        self.puzzleView.setNeedsDisplay()
      }
    })
  }
  
  // アクションシートの固定ボタン押下
  @IBAction func fixActionSelected(_ sender: Any) {
    puzzle.fixCount += 1
    puzzle.fix()
    undoButton.isEnabled = false
    puzzleView.setNeedsDisplay()
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if (segue.identifier == "ShowHelp") {
      let hv = segue.destination as? HelpViewController
      let bundle = Bundle.main
      let url: URL? = bundle.url(forResource: "playview", withExtension: "html", subdirectory: "www")
      hv!.url = url
    }
  }


  // MARK: - ヘルパメソッド
  
  /// アンドゥ、リドゥボタンの活性・非活性を更新する
  private func updateButtonStatus() {
    undoButton.isEnabled = puzzle.canUndo
    redoButton.isEnabled = puzzle.canRedo
    actionButton.isEnabled = puzzle.status == .solving
  }
  
  /// 画面のタイトルを更新する
  @objc func updateElapsedlabel() {
    if let start = elapsedStart {
      let now = Date()
      let t = now.timeIntervalSince(start)
      let sec = puzzle.elapsedSecond + Int(t)
      navigationItem.title = "\(puzzleTitle)\(elapsedlabelString(sec))"
    }
  }
  
  /// 経過時間文字列を得る
  ///
  /// - Parameter sec: 秒数
  /// - Returns: 経過時間文字列
  func elapsedlabelString(_ sec: Int) -> String {
    return String(format: "%d:%02d:%02d", sec / 3600, (sec % 3600) / 60, sec % 60)
  }

}
