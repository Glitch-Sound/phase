# 効果音の確認状況

select.ogg、ring_rotate.ogg、ring_rotate1.ogg、ring_rotate2.ogg、attack.ogg、heal.ogg、defeated.oggは、利用者が選び、この場所へ置いた素材である。\
今回の実装では元ファイルの内容と更新時刻を変更せず、そのまま依存として同梱する。

作者、取得元とライセンスを確認できる文書は同梱されていない。\
Vorbisのタグだけでは出典を確定できず、KenneyやCC0などの出典と権利条件を推定しない。\
公開と外部配布は今回行わない。

音量と再生条件はコード側で管理し、原音への音量変更、切り出しと上書きは行わない。

現在はring_rotate1.oggとring_rotate2.oggを移動用に交互再生し、attack.oggとheal.oggを従来どおり使う。\
select.oggと旧ring_rotate.oggは保持するだけとし、再生しない。

撃破音はdefeated.oggの冒頭を保持し、独立した再生音量で長い余韻を滑らかに消す。\
原音の編集と上書きは行わない。
