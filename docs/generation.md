---
layout: default
---

Text can be **bold**, _italic_, or ~~strikethrough~~.

[Link to another page](./index.html).

There should be whitespace between paragraphs.

There should be whitespace between paragraphs. We recommend including a README, or a file with information about your project.

# パズルの生成

パズル生成の画面では、様々な条件が指定できますが、それらの条件が実際にパズルを生成する際にどういう意味合いを持つのかを説明します。

## 生成の仕組み

各種の条件の意味合いを理解するには、まず、パズル生成の仕組みを知る必要があります。  
パズルの生成は大きく、以下の2つの段階に分けることができます。

### 1）ループの生成

まず、最終的な正解となるできるだけ長い一続きのループを生成します。  
基本的には、ランダムに選択された点から、ランダムに線を伸ばしていき、できるだけ長い線が得られるよう試行錯誤します。  
もうそれ以上、線の先端を伸ばしていく余地がなくなり、まだ長さが足りない場合には、広い空き領域に接する部分の線を切断して、そこから空き領域へ向けて線を伸ばします。  
このようにして、盤面の大きさに対してある割合以上の長さのループを得ます。  
実際にはここで得られるループの形が問題の難易度に大きく影響しますが、あくまで偶然の結果であり、ここではどのレベルの問題でも同じ処理を行います。

### 2）数字の間引き

ループが決まったあと、盤面の全セルに数字を記入します。  
次に、生成パラメータの中の除去パターンによって定まるパターンに従って、盤面の数字を一定数ずつ順番に抜いてい（空白にして）行きます。  
1組数字を除去するたびに、その問題が論理的に解けるかどうかを確認して、制限時間内に解けた場合には抜いたセルはそのまま空白とし、解けなかった場合には元の数字に戻します。  
これを全セル分繰り返して、残ったものが生成された問題になります。  
生成パラメータの中の除去パターン以外のものは、問題が解けるかどうかを確認する際に使用する解法と、その制限時間になります。  
より高度な解法、長い制限時間を使用することで、数字が除去される率が上がり、結果的に難しい問題が生成されます。ただし、高度な解法＋長い制限時間の方が必ず難しくなるわけでもなく、場合によっては簡単な解法だけで非常に難しい問題ができてしまったりしますので、あくまでそういう傾向がある、というお話です。


## 生成パラメータ詳細

### 1）解法

#### 初期配置

まず最初に数字の配置の状態から確定する辺の状態を確定します。本アプリでは、以下のようなパターンを利用しています。


#### 基本解法

解法オプションを一つも指定しない場合、以下のようなロジックで問題を解いていきます。

*    複数の数字のセルの並びから、あるいはコーナーに置かれた数字から、一部の辺の状態が確定
*   セルの数字といくつかの辺の状態から他の辺の状態を確定
*   1つの頂点に集まる複数の辺の中のいくつかの辺の状態から他の辺の状態を確定

#### 斜めゲート[G]

一つのセルには、4隅に４つの頂点があります。その一つ一つの頂点を門に見立てて、ループが対象のセルの側からそのセルとは逆側に抜けていく場合にはその門が開いている、ループがその頂点で対象のセルの側からセルの外側には抜けない場合にはその門が閉じていると考えます。　　
このように考えたときに、セルの中の数字と辺の入り方で門の状態が確定したり、逆に門の状態が確定すると他の門のループの入り方が確定したりしますので、この性質を利用して問題を解いていきます。

#### セルの色[C]

スリザーリンクでは、問題が解けた際に一連のループが出来上がりますが、その内側のセルと外側のセルに異なる色がついていると考えた場合に、隣り合った２つのセルの色が同じ場合、その２つのセルの間にはループは通らず（辺がOFF）、異なる色だった場合にはループが通る（辺がON）という性質があります。  
この性質を利用して、問題を解き進めることができます。

#### １手仮置き[T]

スリザーリンクでは、問題が解けた際に一連のループが出来上がりますが、その内側のセルと外側のセルに異なる色がついていると考えた場合に、隣り合った２つのセルの色が同じ場合、その２つのセルの間にはループは通らず（辺がOFF）、異なる色だった場合にはループが通る（辺がON）という性質があります。  
この性質を利用して、問題を解き進めることができます。






```js
// Javascript code with syntax highlighting.
var fun = function lang(l) {
  dateformat.i18n = require('./lang/' + l)
  return true;
}
```

```ruby
# Ruby code with syntax highlighting
GitHubPages::Dependencies.gems.each do |gem, version|
  s.add_dependency(gem, "= #{version}")
end
```

#### Header 4

*   This is an unordered list following a header.
*   This is an unordered list following a header.
*   This is an unordered list following a header.

##### Header 5

1.  This is an ordered list following a header.
2.  This is an ordered list following a header.
3.  This is an ordered list following a header.

###### Header 6

| head1        | head two          | three |
|:-------------|:------------------|:------|
| ok           | good swedish fish | nice  |
| out of stock | good and plenty   | nice  |
| ok           | good `oreos`      | hmm   |
| ok           | good `zoute` drop | yumm  |

### There's a horizontal rule below this.

* * *

### Here is an unordered list:

*   Item foo
*   Item bar
*   Item baz
*   Item zip

### And an ordered list:

1.  Item one
1.  Item two
1.  Item three
1.  Item four

### And a nested list:

- level 1 item
  - level 2 item
  - level 2 item
    - level 3 item
    - level 3 item
- level 1 item
  - level 2 item
  - level 2 item
  - level 2 item
- level 1 item
  - level 2 item
  - level 2 item
- level 1 item

### Small image

![Octocat](https://assets-cdn.github.com/images/icons/emoji/octocat.png)

### Large image

![Branching](https://guides.github.com/activities/hello-world/branching.png)


### Definition lists can be used with HTML syntax.

<dl>
<dt>Name</dt>
<dd>Godzilla</dd>
<dt>Born</dt>
<dd>1952</dd>
<dt>Birthplace</dt>
<dd>Japan</dd>
<dt>Color</dt>
<dd>Green</dd>
</dl>

```
Long, single-line code blocks should not wrap. They should horizontally scroll if they are too long. This line should be long enough to demonstrate this.
```

```
The final element.
```
