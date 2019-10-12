---
layout: default
---

<div style="text-align: right;">
<a href="./index.html">TOPページ</a>
</div>
# 付録D　セルの色の解法

#### 調査対象

|パターン|説明|
|:----:|:---|
|![](pattern/color/color_targetCell.png)|あるエッジの状態が確定すると、そのエッジの両側のセルの色が確定しないかのチェックを行う|
|![](pattern/color/color_targetEdge.png)|あるセルの色が確定すると、その４周のエッジの状態が確定しないかのチェックを行う|

#### セルの色の確定

|パターン|説明|
|:----:|:---|
|![](pattern/color/colorON.png)|ONのエッジの片側のセルに色がついていると、もう一方のセルは逆の色になる|
|![](pattern/color/colorOFF.png)|OFFのエッジの片側のセルに色がついていると、もう一方のセルも同じ色になる|

#### セルの色によるエッジの確定

|パターン|説明|
|:----:|:---|
|![](pattern/color/colorSAME.png)|隣り合ったセルの色が同じなら、間のエッジはOFF|
|![](pattern/color/colorDIFF.png)|隣り合ったセルの色が異なるなら、間のエッジはON|

<div style="text-align: right;">
<a href="./index.html">TOPページ</a>
</div>



