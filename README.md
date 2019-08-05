Slither2
======================
Slither2は、[スリザーリンク](http://ja.wikipedia.org/wiki/スリザーリンク)、あるいはナンバーラインと呼ばれるペンシルパズルで遊ぶための、Swiftで書かれたiPad専用のアプリケーションです。
Objective-Cで書かれた[SLPlayer](https://github.com/kj-oz/SLPlayer)の後継になります。

このソースからビルドされるアプリケーションは、Apple社のAppStoreで **スリザー2** という名称で
無料で配信中です。  
　[https://apps.apple.com/app/id1473823135](https://apps.apple.com/app/id1473823135)

以下のページで、アプリの中の操作ガイドには書かれていない、生成のロジックなどを解説していますので、合わせて御覧ください。  
　[https://github.com/kj-oz/Slither2](https://github.com/kj-oz/Slither2)

### アプリケーションの特徴 

* 解き味を出来るだけ紙のパズルと同じになるようにしてあります。（線は点の間を指やペンでなぞることで入力します。複数の点を連続して結ぶことも可能です。）
* 問題の自動生成機能があり、初級から難問までの様々なレベルの問題を自由に作ることが可能です。
* 自分で1つ1つの数字を手で入力して新しい問題を入力することも出来ます。
* 各画面で簡単な操作ガイドを見ることができます。

### ソースコードの特徴 

* 使用言語は Swift 5.0 です。
* コメントは全て日本語です。
* クラスの可視性などはあまり真面目に指定していません。
* SLPlayerにはあった写真や画像から問題を自動認識する機能はSlithe2では省略していますので、ご興味のある方は[SLPlayer](https://github.com/kj-oz/SLPlayer)のリポジトリを御覧ください。

### 開発環境

* 2019/07月現在、Mac 0S X 10.14.5、Xcode 10.2.1

動作環境
-----
iOS 9.0以上、iPad専用

ライセンス
-----
 [MIT License](http://www.opensource.org/licenses/mit-license.php). の元で公開します。  

-----
Copyright &copy; 2019 Kj Oz  
