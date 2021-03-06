//
//  GenerateViewController.swift
//  Slither
//
//  Created by KO on 2019/02/04.
//  Copyright © 2019 KO. All rights reserved.
//

import UIKit

/// 自動生成時のパラメータ設定画面
class GenerateViewController: UITableViewController, UITextFieldDelegate {
  /// タイトル入力欄
  @IBOutlet weak var titleText: UITextField!
  /// 幅入力欄
  @IBOutlet weak var widthText: UITextField!
  /// 高さ入力欄
  @IBOutlet weak var heightText: UITextField!
  /// プリセット選択セグメント
  @IBOutlet weak var presetSegment: UISegmentedControl!
  /// 回答チェック時、セルのコーナーの通過チェックを使用するかどうかのスイッチ
  @IBOutlet weak var gateCheckSwitch: UISwitch!
  /// 回答チェック時、セルの色のチェックを使用するかどうかのスイッチ
  @IBOutlet weak var cellColorSwitch: UISwitch!
  /// 回答チェック時、1ステップだけの仮置きを使用する場合の許容延長の入力欄
  @IBOutlet weak var tryExtentText: UITextField!
  /// 回答チェック時の許容時間(ms)の入力欄
  @IBOutlet weak var solveTimeText: UITextField!
  /// 盤面の除去パターン名
  @IBOutlet weak var pruneTypeLabel: UILabel!

  /// 作成ボタン
  @IBOutlet weak var generateButton: UIBarButtonItem!
  /// プログレスビュー
  @IBOutlet weak var progressView: UIProgressView!
  
  /// 盤面の数値の除去パターン
  var pruneType: PruneType!
  
  // MARK: - UIViewController
  
  // ビューのロード時
  override func viewDidLoad() {
    super.viewDidLoad()
    let am = AppManager.sharedInstance
    titleText.text = am.nextPuzzleId(readonly: true)
    titleText.delegate = self
    widthText.delegate = self
    heightText.delegate = self
    tryExtentText.delegate = self
    solveTimeText.delegate = self
    loadSettings()
    setGenerateButtonEnabled()
  }
  
  // MARK: - UITextFieldDelegate
  
  // テキスト欄の変更時
  // 何故かこちらは発生しない
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
  
  // テキスト欄の変更時
  func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
    if textField == solveTimeText || textField == tryExtentText {
      presetSegment.selectedSegmentIndex = -1
    } else if textField === widthText || textField === heightText {
      if presetSegment.selectedSegmentIndex >= 0 &&
          isInt(of: widthText) && isInt(of: heightText) {
        updateSolveTime()
      }
    }
    setGenerateButtonEnabled()
    return true
  }
  
  // MARK: - 各種アクション

  // プリセットセグメント変更時
  @IBAction func presetChanged(_ sender: Any) {
    if presetSegment.selectedSegmentIndex >= 0 {
      setOptions(of: presetSegment.selectedSegmentIndex)
    }
  }

  // 解法オプションのスイッチの変更時
  @IBAction func solveOptionChanged(_ sender: Any) {
    presetSegment.selectedSegmentIndex = -1
  }
  
  // MARK: - Navigation
  
  // セグエ呼び出し前
  override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
    if identifier == "GenerateDone" {
      guard let width = Int(widthText.text!), let height = Int(heightText.text!),
        let solveTime = Int(solveTimeText.text!) else {
          return false
      }

      let indicator = UIActivityIndicatorView()
      indicator.style = .whiteLarge
      indicator.center = self.view.center
      indicator.color = UIColor.red
      indicator.hidesWhenStopped = true
      self.view.addSubview(indicator)
      self.view.bringSubviewToFront(indicator)
      indicator.startAnimating()
      
      let title = titleText.text!
      
      var solveOption = SolveOption()
      solveOption.doAreaCheck = false
      let tryExtent = Int(tryExtentText.text!) ?? 0
      solveOption.tryOneStepMaxExtent = tryExtent
      solveOption.useCache = true
      solveOption.doColorCheck = cellColorSwitch.isOn
      solveOption.doGateCheck = gateCheckSwitch.isOn
      solveOption.maxGuessLevel = 0
      solveOption.elapsedSec = Double(solveTime) / 1000.0
      
      var baseProgress = 0.0
      var genProgress = 0.05
      
      DispatchQueue.global().async {
        self.generatePuzzle(width: width, height: height, title: title, solveOption: solveOption,
          progressHandler: { count, total in
            var progress = 0.0
            if total == 0 {
              // ループ生成時
              progress = baseProgress + genProgress
              baseProgress = progress
              genProgress *= 0.5
            } else {
              // 数値間引き時
              let half = total / 2
              if count < half {
                progress = baseProgress + Double(count) / Double(half) * (1.0 - baseProgress) / 3.0
              } else {
                progress = baseProgress + (1.0 - baseProgress) / 3.0 +
                  Double(count - half) / Double(half) * (1.0 - baseProgress) / 3.0  * 2.0
              }
            }
            DispatchQueue.main.async {
              self.progressView.progress = Float(progress)
            }
        })
        DispatchQueue.main.async {
          self.saveSetting()
          indicator.stopAnimating()
          self.performSegue(withIdentifier: identifier, sender: sender)
        }
      }
      return false
    }
    return true
  }
  
  // 他画面への移動時
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    switch segue.identifier {
    case "SelectPruneType":
      let dst = segue.destination as! PruneTypesViewController
      dst.selectedPruneType = pruneType
    default:
      break
    }
  }
  
  // 盤面タイプ選択画面からの戻り時のアクション
  @IBAction func pruneTypesSelected(segue: UIStoryboardSegue) {
    let bv = segue.source as! PruneTypesViewController
    pruneType = bv.selectedPruneType!
    pruneTypeLabel.text = pruneType.description
    presetSegment.selectedSegmentIndex = -1
  }
  
  // 盤面タイプ選択画面のキャンセル時のアクション
  @IBAction func pruneTypesCanceled(segue: UIStoryboardSegue) {
    // 何もしない
  }
  
  // MARK: - ヘルパメソッド
  
  /// 保存されている設定値を呼び出す
  private func loadSettings() {
    widthText.text = UserDefaults.standard.string(forKey: "genWidth") ?? "15"
    heightText.text = UserDefaults.standard.string(forKey: "genHeight") ?? "10"
    let level = Int(UserDefaults.standard.string(forKey: "genLevel") ?? "2")!
    presetSegment.selectedSegmentIndex = level
    if level >= 0 {
      setOptions(of: level)
    } else {
      let solveOpStr = UserDefaults.standard.string(forKey: "genSolveOp") ?? ""
      gateCheckSwitch.isOn = solveOpStr.firstIndex(of: "G") != nil
      cellColorSwitch.isOn = solveOpStr.firstIndex(of: "C") != nil
      tryExtentText.text = tryOneStepExtentFromOpStr(solveOpStr: solveOpStr)
      //areaCheckSwitch.isOn = solveOpStr.firstIndex(of: "A") != nil
      solveTimeText.text = UserDefaults.standard.string(forKey: "genSolveTime") ?? "100"
      pruneType = PruneType(rawValue: UserDefaults.standard.string(forKey: "genPruneType") ?? "R4")
      pruneTypeLabel.text = pruneType.description
    }
  }
  
  /// 解法オプション文字列から1手仮置きのレベルを得る
  ///
  /// - Parameter solveOpStr: 解法オプション文字列
  /// - Returns: 1手仮置きのレベル
  private func tryOneStepExtentFromOpStr(solveOpStr: String) -> String {
    let tryIndex = solveOpStr.firstIndex(of: "T")
    if let tryIndex = tryIndex {
      let numIndex = solveOpStr.index(after: tryIndex)
      return String(solveOpStr.suffix(from: numIndex))
    } else {
      return "0"
    }
  }
  
  /// 画面に設定された状態を保存する
  private func saveSetting() {
    UserDefaults.standard.set(widthText.text, forKey: "genWidth")
    UserDefaults.standard.set(heightText.text, forKey: "genHeight")
    let level = presetSegment.selectedSegmentIndex
    UserDefaults.standard.set(String(level), forKey: "genLevel")
    if level == UISegmentedControl.noSegment {
      var solveOpStr = ""
      if gateCheckSwitch.isOn {
        solveOpStr += "G"
      }
      if cellColorSwitch.isOn {
        solveOpStr += "C"
      }
      if let text = tryExtentText.text, text != "" && text != "0" {
        solveOpStr += "T\(text)"
      }
      UserDefaults.standard.set(solveOpStr, forKey: "genSolveOp")
      UserDefaults.standard.set(solveTimeText.text, forKey: "genSolveTime")
      UserDefaults.standard.set(pruneType.rawValue, forKey: "genPruneType")
    }
  }
  
  /// 指定されたプリセットの状態を画面に設定する
  ///
  /// - Parameter level: プリセットのレベル
  private func setOptions(of level: Int) {
    var solveOpStr = ""
    var tryExtent = 0
    switch level {
    case 0:
      solveOpStr = "GC"
      pruneType = PruneType.random4Cell
    case 1:
      solveOpStr = "GCT10"
      pruneType = PruneType.random2Cell
      tryExtent = 10
    case 2:
      solveOpStr = "GCT10"
      pruneType = PruneType.random1Cell
      tryExtent = 10
    case 3:
      solveOpStr = "GCT40"
      pruneType = PruneType.randomSCell
      tryExtent = 40
    default:
      break
    }
    gateCheckSwitch.isOn = solveOpStr.firstIndex(of: "G") != nil
    cellColorSwitch.isOn = solveOpStr.firstIndex(of: "C") != nil
    tryExtentText.text = "\(tryExtent)"
    pruneTypeLabel.text = pruneType.description
    
    updateSolveTime()
  }
  
  /// [作成]ボタンの活性の設定
  private func setGenerateButtonEnabled() {
    generateButton.isEnabled = isString(of: titleText)
      && isInt(of: widthText) && isInt(of: heightText) && isInt(of: solveTimeText)
  }
  
  /// 盤面のサイズに応じて、回答を求める際の許容時間を変更する
  private func updateSolveTime() {
    if let width = Int(widthText.text!), let height = Int(heightText.text!) {
      // iPadAir2で1セルあたり1msを目処として使用（レベル0の問題はその半分）
      var solveTime = (width * height / 100) * 100 / 2
      if solveTime == 0 {
        solveTime = 50
      }
      if presetSegment.selectedSegmentIndex >= 2 {
        solveTime *= 2
      }
      solveTimeText.text = String(solveTime)
    }
  }
  
  /// テキストフィールドに整数値が入力されているかどうかの判定
  ///
  /// - Parameter textFeild: 対象のテキストフィールド
  /// - Returns: 整数値が入力されて入ればtrue
  private func isInt(of textFeild: UITextField) -> Bool {
    if let text = textFeild.text, let _ = Int(text) {
      return true
    }
    return false
  }
  
  /// テキストフィールドに長さ1以上の文字列が入力されているかどうかの判定
  ///
  /// - Parameter textFeild: 対象のテキストフィールド
  /// - Returns: 長さ1以上の文字列が入力されて入ればtrue
  private func isString(of textFeild: UITextField) -> Bool {
    if let text = textFeild.text, text.count > 0 {
      return true
    }
    return false
  }
  
  /// パズルを生成する
  ///
  /// - Parameters:
  ///   - width: 幅
  ///   - height: 高さ
  ///   - title: タイトル
  ///   - solveOption: 解法オプション
  private func generatePuzzle(width: Int, height: Int, title: String, solveOption: SolveOption,
                              progressHandler: ((_ count: Int, _ total: Int) -> ())?) {
    let am = AppManager.sharedInstance
    let realType = pruneType.realType
    let generator = Generator(width: width, height: height)
    // パズルの生成パラメータは、iPAdAir2換算の時間制限を使用
    let genParam = solveOption.description + "-" + realType.rawValue
    // 実際の生成時間制限は、機器毎の時間係数を乗じる
    var solveOp = solveOption
    solveOp.elapsedSec *= am.timeFactor
    let numbers = generator.generate(genOp: GenerateOption(), pruneType: realType,
                                     solveOp: solveOp, progressHandler: progressHandler)
    let genStats = generator.stats.description
    let id = am.nextPuzzleId()
    let _ = Puzzle(folder: am.currentFolder,  id: id, title: title, width: width, height: height,
                   genParams: genParam, genStats: genStats, data: numbers)
  }
}
