# 仕様書

## 一覧

| capability | 内容 |
| --- | --- |
| [phase-rings](phase-rings/spec.md) | 位相、同期、効果量 |
| [tactical-battle](tactical-battle/spec.md) | 経路、手番、対象、勝敗 |
| [build-collection](build-collection/spec.md) | ビルド、共有開放、保存 |
| [battle-interface](battle-interface/spec.md) | 画面、入力、オーバーレイ |
| [battle-movement](battle-movement/spec.md) | 確定経路の移動表示、着地、中断 |
| [enemy-cpu](enemy-cpu/spec.md) | 敵CPUの判断、モード、操作過程と中断 |

## 関係

戦闘は位相計算を使い、ビルドの構成を受け取る。
画面は戦闘、ビルド、位相予測を同時に表示する。
構成の依存方向はopenspec/tech.mdのアーキテクチャに従う。
