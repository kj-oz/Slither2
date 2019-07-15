//
//  EditViewController.swift
//  Slither2
//
//  Created by KO on 2019/01/30.
//  Copyright © 2019 KO. All rights reserved.
//

import UIKit

class EditViewController: UIViewController, PuzzleViewDelegate {
  
  /// パズルビュー
  @IBOutlet weak var puzzleView: PuzzleView!
  
  /// パズル
  var puzzle: Puzzle!
  
  /// 最後に保存した時刻
  var lastSaved: Date?
  
  // MARK: - UIViewController
  
  // ビューロード時
  override func viewDidLoad() {
    super.viewDidLoad()
    let am = AppManager.sharedInstance
    puzzle = am.currentPuzzle!
    navigationItem.title = "\(puzzle.title)  (\(puzzle.sizeString))  \(puzzle.genParams)"

    // 本来awakeFromNibで設定するはずだが、そのタイミングでは何故かいずれもnil
    puzzleView.delegate = self
    puzzleView.mode = puzzle.status == .editing || puzzle.status == .notStarted ? .input : .view
    puzzleView.setBoard(puzzle.board)
    
    // アプリケーションライフサイクルの通知受信
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(self.applicationDidEnterBackground), name: NSNotification.Name("applicationDidEnterBackground"), object: nil)
    nc.addObserver(self, selector: #selector(self.applicationWillEnterForeground), name: NSNotification.Name("applicationWillEnterForeground"), object: nil)
  }
  
  // ビュー表示直後
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    startPlay()
  }
  
  // ビューが消える直前
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    stopPlay()
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
  
  // MARK: - アプリケーションのアクティブ化・非アクティブ化
  
  /// アプリケーションがバックグラウンドにまわった直後
  @objc func applicationDidEnterBackground() {
    stopPlay()
  }
  
  /// アプリケーションがフォアグラウンドに戻る直前
  @objc func applicationWillEnterForeground() {
    startPlay()
  }
    
  /// プレイを開始する.
  func startPlay() {
    lastSaved = Date()
  }
  
  /// プレイを中断する.
  func stopPlay() {
    if puzzle.status == .editing {
      puzzle.save()
    }
  }
  

  // MARK: - PuzzleViewDelegateの実装
  
  /// 線の連続入力の開始
  func lineBegan() {
  }
  
  /// 何らかの操作が行われた時の発生するイベント
  func actionDone(_ action: Action) {
    puzzle.addAction(action as! SetCellNumberAction)
    if puzzle.status != .editing {
      puzzle.status = .editing
    }
    if let lastSaved = lastSaved {
      let now = Date()
      if now.timeIntervalSince(lastSaved) > 10.0 {
        puzzle.save()
        self.lastSaved = now
      }
    }
    puzzleView.setNeedsDisplay()
  }
  
  /// 線の連続入力の終了
  func lineEnded() {
  }
  

  // MARK: - ボタンのアクション
  
  /// チェックボタンタップ時
  @IBAction func checkTapped(_ sender: Any) {
    let solver = Solver(board: puzzle.board)
    var option = SolveOption()
    option.doAreaCheck = true
    option.tryOneStepMaxExtent = 10000
    option.useCache = true
    option.doColorCheck = true
    option.doGateCheck = true
    option.maxGuessLevel = 120
    option.elapsedSec = 120.0
    
    let result = solver.solve(option: option)
    if result.solved {
      let msg = "問題が完成しました。"
      alert(viewController: self, message: msg)
      
      puzzle.status = .notStarted
      puzzle.save()
    } else {
      switch result.reason {
      case .multiloop:
        let msg = "複数の解答が存在します。"
        alert(viewController: self, message: msg)
      default:
        let msg = "解答が存在しません。"
        alert(viewController: self, message: msg)
      }
    }
  }
  

  // MARK: - Navigation
  
  // ヘルプ画面表示時
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if (segue.identifier == "ShowHelp") {
      let hv = segue.destination as? HelpViewController
      let bundle = Bundle.main
      let url: URL? = bundle.url(forResource: "editview", withExtension: "html", subdirectory: "www")
      hv!.url = url
    }
  }
}
