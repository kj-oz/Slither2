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
  
  var logger: Logger!
  
  var advise: AdviseInfo?

  // MARK: - UIViewController
  
  // ビューロード時
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let am = AppManager.sharedInstance
    logger = am.logger
    logger.log("** PlayViewController viewDidLoad")

    puzzle = am.currentPuzzle!
    if puzzle.status == .notStarted {
      puzzle.status = .solving
    } else if puzzle.actions.count == 0 {
      puzzle.loadActions()
    }
    puzzleTitle = "\(puzzle.title)   \(puzzle.sizeString)  \(puzzle.genParams)   "
    
    // 念の為計時関係の初期化
    elapsedLabaelUpdateTimer = nil
    elapsedStart = nil
    
    // 本来awakeFromNibで設定するはずだが、そのタイミングでは何故かいずれもnil
    puzzleView.delegate = self
    puzzleView.mode = puzzle.status == .solved ? .view : .play
    puzzleView.setBoard(puzzle.board)
  }
  
  // ビュー表示直後
  override func viewDidAppear(_ animated: Bool) {
    logger.log("** PlayViewController viewDidAppear")
    super.viewDidAppear(animated)
    updateButtonStatus()
    startPlay()

    // アプリケーションライフサイクルの通知受信
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(self.applicationWillResignActive), name: NSNotification.Name("applicationWillResignActive"), object: nil)
    nc.addObserver(self, selector: #selector(self.applicationDidBecomeActive), name: NSNotification.Name("applicationDidBecomeActive"), object: nil)
  }
  
  // ビューが消える直前
  override func viewWillDisappear(_ animated: Bool) {
    logger.log("** PlayViewController viewWillDisappear")
    super.viewWillDisappear(animated)
    stopPlay()

    // アプリケーションライフサイクルの通知受信解除
    // Viewのload/unloadのタイミングで処理すると、一度表示したビューの計時がずっと残るためこちらに移動
    let nc = NotificationCenter.default
    nc.removeObserver(self, name: NSNotification.Name("applicationWillResignActive"), object: nil)
    nc.removeObserver(self, name: NSNotification.Name("applicationDidBecomeActive"), object: nil)
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
  
  deinit {
    logger.log("** PlayViewController deinit")
  }
  
  // MARK: - アプリケーションのアクティブ化・非アクティブ化
  
  /// アプリケーションがバックグラウンドにまわった直後
  @objc func applicationDidBecomeActive() {
    logger.log("** PlayViewController applicationDidBecomeActive")
    startPlay()
  }
  
  /// アプリケーションがフォアグラウンドに戻る直前
  @objc func applicationWillResignActive() {
    logger.log("** PlayViewController applicationWillResignActive")
    stopPlay()
  }

  /// プレイを開始する.
  func startPlay() {
    logger.log("□□ startPlay:" + puzzle.id)
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
    logger.log("□□ stopPlay:" + puzzle.id)
    if let start = elapsedStart {
      elapsedLabaelUpdateTimer!.invalidate()
      let now = Date()
      let t: TimeInterval = now.timeIntervalSince(start)
      puzzle.elapsedSecond += Int(t)
      puzzle.save()
      elapsedStart = nil
      logger.log("■■ saved:\(puzzle.id) \(Int(t))")
    }
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
        logger.log("■■ saved:\(puzzle.id) \(Int(t))")
        elapsedStart = now
      }
    }
  }

  /// 線の連続入力の終了
  func lineEnded() {
    if let edge = puzzle.board.findOnEdge() {
      let (endNode, _) = puzzle.board.getLoopEnd(from: edge.nodes[0], and: edge)
      if endNode == nil {
        let loopStatus = puzzle.board.check(finished: true)
        switch loopStatus {
        case .finished:
          puzzle.fix()
          puzzle.status = .solved
          stopPlay()
          
          updateButtonStatus()
          let msg = "正解です。所要時間 \(puzzle.elapsedTimeString)"
          alert(viewController: self, message: msg)
        case .nodeError(let elements):
          alert(viewController: self, title: "ループエラー", message: "条件に合致しないノードがあります。")
          puzzleView.advise = CheckResultAdviseInfo(elements)
        case .cellError(let elements):
          alert(viewController: self, title: "ループエラー", message: "条件に合致しないセルがあります。")
          puzzleView.advise = CheckResultAdviseInfo(elements)
        case .multiLoop(let elements):
          alert(viewController: self, title: "ループエラー", message: "複数のループに分かれています。")
          puzzleView.advise = CheckResultAdviseInfo(elements)
        default:
          break
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
    if let advise = self.advise {
      if advise.reasonLabel.count > 0 && advise.reasonIndex < 0 {
        alert.addAction(UIAlertAction(title: advise.reasonLabel, style: .default, handler: { _ in
          self.adviseShowReasonActionSelected(self)
        }))
      }
      alert.addAction(UIAlertAction(title: advise.fixLabel, style: .destructive, handler: { _ in
        self.adviseFixActionSelected(self)
      }))
      alert.addAction(UIAlertAction(title: "アドバイス終了", style: .default, handler: { _ in
        self.adviseEndActionSelected(self)
      }))
    } else {
      alert.addAction(UIAlertAction(title: "初期化", style: .destructive, handler: { _ in
        self.initActionSelected(self)
      }))
      alert.addAction(UIAlertAction(title: "未固定部消去", style: .destructive, handler: { _ in
        self.eraseActionSelected(self)
      }))
      alert.addAction(UIAlertAction(title: "固定", style: .default, handler: { _ in
        self.fixActionSelected(self)
      }))
      alert.addAction(UIAlertAction(title: "アドバイス", style: .default, handler: { _ in
        self.adviseActionSelected(self)
      }))
    }
    alert.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem
    self.present(alert, animated: true, completion: nil)
  }
  
  // アンドゥボタンタップ時
  @IBAction func undoButtonTapped(_ sender: Any) {
    if let advise = advise {
      if let tryFailAdvise = advise as? TryFailAdviseInfo {
        tryFailAdvise.stepBack()
        puzzleView.setNeedsDisplay()
      }
    } else {
      puzzle.undo()
      puzzleView.setNeedsDisplay()
      if (advise as? CheckResultAdviseInfo) != nil {
        puzzleView.advise = nil
      }
    }
    updateButtonStatus()
  }

  // リドゥボタンタップ時
  @IBAction func redoButtonTapped(_ sender: Any) {
    if let advise = advise {
      if let tryFailAdvise = advise as? TryFailAdviseInfo {
        tryFailAdvise.stepForward()
        puzzleView.setNeedsDisplay()
      }
    } else {
      puzzle.redo()
      puzzleView.setNeedsDisplay()
    }
    updateButtonStatus()
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
  
  // アクションシートのアドバイスボタン押下
  @IBAction func adviseActionSelected(_ sender: Any) {
    let adviser = Adviser(puzzle: puzzle)
    if let advise = adviser.advise() {
      puzzle.adviseCount += 1
      self.advise = advise
      alert(viewController: self, message: advise.message)
      puzzleView.startAdvise(advise: advise)
      updateButtonStatus()
    }
  }
  
  // アクションシートのアドバイス理由表示ボタン押下
  @IBAction func adviseShowReasonActionSelected(_ sender: Any) {
    if let advise = self.advise {
      advise.showReason()
      updateButtonStatus()
      puzzleView.setNeedsDisplay()
    }
  }
  
  // アクションシートのアドバイス確定ボタン押下
  @IBAction func adviseFixActionSelected(_ sender: Any) {
    if let advise = self.advise {
      advise.fix(to: puzzle)
      adviseEndActionSelected(self)
    }
  }
  
  // アクションシートのアドバイス終了ボタン押下
  @IBAction func adviseEndActionSelected(_ sender: Any) {
    if self.advise != nil {
      puzzleView.endAdvise()
      self.advise = nil
      updateButtonStatus()
    }
  }
  

  
  
  // MARK: - Navigation
  
  // ヘルプ画面表示時
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
    if let advise = self.advise {
      if let tryFailAdvise = advise as? TryFailAdviseInfo {
        undoButton.isEnabled = tryFailAdvise.reasonIndex > 0
        redoButton.isEnabled = tryFailAdvise.reasonIndex < tryFailAdvise.steps.count - 1
      } else {
        undoButton.isEnabled = false
        redoButton.isEnabled = false
      }
    } else {
      undoButton.isEnabled = puzzle.canUndo
      redoButton.isEnabled = puzzle.canRedo
    }
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
