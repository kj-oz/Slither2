---
layout: default
---

<div style="text-align: right;">
<a href="./index.html">TOPページ</a>
</div>
# 付録B　基本解法パターン

#### ノード

|パターン|説明|
|:----:|:---|
|![](pattern/basic/nodeON2.png)|接するエッジのうち2つがONならば、残りのエッジはOFF|
|![](pattern/basic/nodeOFF2ON1.png)|接するエッジのうち2つがOFFで１つがONならば、残りのエッジはON|
|![](pattern/basic/nodeOFF3.png)|接するエッジのうち3つがOFFならば、残りのエッジもOFF|
|![](pattern/basic/node11.png)|OFFのエッジを延長したエッジの両側が１と１の場合、延長したエッジはOFF|
|![](pattern/basic/node13.png)|OFFのエッジを延長したエッジの両側が１と３の場合、3のノード側のエッジはON、１の３と逆側のエッジとその隣のエッジはOFF|

#### セル

|パターン|説明|
|:----:|:---|
|![](pattern/init/border11.png)|外周に沿って１が並ぶ場合、その間のエッジはOFF|
|![](pattern/init/border13.png)|外周に沿って１と３が並ぶ場合、|


<div style="text-align: right;">
<a href="./index.html">TOPページ</a>
</div>



