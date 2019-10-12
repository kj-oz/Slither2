---
layout: default
---

<div style="text-align: right;">
<a href="./index.html">TOPページ</a>
</div>
# 付録C　斜めゲート解法

#### 共通事項

##### 調査対象のセル

|パターン|説明|
|:----:|:---|
|![](pattern/gate/gate_targetCell.png)|あるエッジの状態が確定すると、そのエッジの周囲の６つセル（の４隅のゲート）を対象にゲートのチェックを行う|
|![](pattern/gate/gate_nextCell.png)|あるセルの一つのゲートの状態が確定すると、そのゲートの向こう側のセル（の４隅のゲート）もゲートチェックの対象の加える|

##### ゲートの状態の確定

|パターン|説明|
|:----:|:---|
|![](pattern/gate/gateOPEN.png)|セルのゲートに接するエッジの片方がONで片方がOFFならば、ゲートはOPEN|
|![](pattern/gate/gateCLOSE.png)|セルのゲートに接するエッジの両方がON、または両方がOFFならば、ゲートはCLOSE|

##### OPENなゲートによるエッジの確定

|パターン|説明|
|:----:|:---|
|![](pattern/gate/gateOPEN_ON.png)|セルのOPENなゲートに接する２本のエッジの片方がONなら、もう一方のエッジはOFF|
|![](pattern/gate/gateOPEN_OFF.png)|セルのOPENなゲートに接する２本のエッジの片方がOFFなら、もう一方のエッジはON|

##### CLOSEなゲートによるエッジの確定

|パターン|説明|
|:----:|:---|
|![](pattern/gate/gateCLOSE_ON.png)|セルのCLOSEなゲートに接する２本のエッジの片方がONなら、もう一方のエッジもON|
|![](pattern/gate/gateCLOSE_OFF.png)|セルのCLOSEなゲートに接する２本のエッジの片方がOFFなら、もう一方のエッジもOFF|

#### セルの数字に固有の解法

##### １のセル

|パターン|説明|
|:----:|:---|
|![](pattern/gate/gate1OPEN.png)|１つのゲートがOPENなら、その対角のゲートはCLOSE、対角のゲートに接する２本のエッジはOFF|
|![](pattern/gate/gate1CLOSE.png)|１つのゲートがCLOSEなら、そのゲートに接する２本のエッジはOFF、対角のゲートはOPEN|

##### ２のセル

|パターン|説明|
|:----:|:---|
|![](pattern/gate/gate2OPEN.png)|１つのゲートがOPENなら、その対角のゲートもOPEN|
|![](pattern/gate/gate2CLOSE.png)|１つのゲートがCLOSEなら、その対角のゲートもCLOSE、その他の２つのゲートはOPEN|
|![](pattern/gate/gate2oON_doON.png)|１つのゲートの外側の２本のエッジのいずれかがONで、対角のゲートの外側の２本のエッジのいずれかもONなら、それらの２つのゲートはOPEN|
|![](pattern/gate/gate2oON_diOFF.png)|１つのゲートの外側の２本のエッジのいずれかがONで、対角のゲートの内側の２本のエッジのいずれかがOFFなら、それらの２つのゲートはOPEN|
|![](pattern/gate/gate23_doON.png)|ゲートの向こう側が（間に複数の２があってもよい）３で、対角のゲートの外側の２本のエッジのいずれかがONなら、それらの２つのゲートはOPEN|
|![](pattern/gate/gate23_diOFF.png)|ゲートの向こう側が（間に複数の２があってもよい）３で、対角のゲートの内側の２本のエッジのいずれかがOFFなら、それらの２つのゲートはOPEN|
|![](pattern/gate/gate2CLOSE3.png)|１つのゲートがCLOSEで、ゲートに接しないエッジの逆側が３なら、３のセルのゲートから伸びてくるエッジの延長上のエッジと、２と逆側のエッジはON|

##### ３のセル

|パターン|説明|
|:----:|:---|
|![](pattern/gate/gate3OPEN.png)|１つのゲートがOPENなら、その対角のゲートはCLOSE、対角のゲートに接する２本のエッジはON|
|![](pattern/gate/gate3CLOSE.png)|１つのゲートがCLOSEなら、そのゲートに接する２本のエッジはON、対角のゲートはOPEN|

<div style="text-align: right;">
<a href="./index.html">TOPページ</a>
</div>



