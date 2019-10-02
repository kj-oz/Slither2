---
layout: default
---

<div style="text-align: right;">
<a href="./index.html">TOPページ</a>
</div>
# 付録A　初期探索パターン

#### コーナー

|パターン|説明|
|:----:|:---|
|![](pattern/init/corner1.png)|コーナーに１がある場合、その外側のエッジはOFF|
|![](pattern/init/corner3.png)|コーナーに３がある場合、その外側のエッジはON|
|![](pattern/init/corner2.png)|コーナーに２がある場合、コーナーの隣のノードから２と逆側に伸びるエッジはON|
|![](pattern/init/corner23.png)|コーナーに２があり、その隣に３がある場合、コーナーの隣のノードから２と逆側に伸びるエッジはON、３の２と逆側のエッジもON|

#### 辺

|パターン|説明|
|:----:|:---|
|![](pattern/init/border11.png)|外周に沿って１が並ぶ場合、その間のエッジはOFF|
|![](pattern/init/border13.png)|外周に沿って１と３が並ぶ場合、3との外周に接するエッジはON、１の３と逆側のエッジとその隣のエッジはOFF|

#### 数字の並び

|パターン|説明|
|:----:|:---|
|![](pattern/init/init0.png)|０の周囲の4本のエッジはOFF|
|![](pattern/init/init33.png)|３が横に並んだ場合、3本の縦のエッジがON、中央のONエッジの両延長エッジがOFF|
|![](pattern/init/init332.png)|３が横に並んでその上(下)に２がある場合、上のパターンに加えて、２の３と逆側のエッジはON、３の外側の２に接続する縦線の２と逆側のエッジがOFF|
|![](pattern/init/init33D.png)|３が斜めに並んだ場合、お互いの外側の2本の縦のエッジがON|
|![](pattern/init/init323D.png)|３が間がすべて２で埋まった状態で斜めに並んだ場合も、上と同様にお互いの外側の2本の縦のエッジがON|


<div style="text-align: right;">
<a href="./index.html">TOPページ</a>
</div>



