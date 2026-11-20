## 体験評価で調整する値を一元管理する。
extends RefCounted

const BASE_HP := 100.0
# 位相の落差と有限の反撃評価を組み合わせ、通常対戦を短くする比較値。
const BASE_DAMAGE := 72.0
const BASE_HEAL := 24.0
# 行動1回を使う防御。次の1攻撃だけ残存倍率を掛け、完全無効にはしない暫定値。
const GUARD_DAMAGE_MULTIPLIER := 0.5
const BASE_MOVE := 3
const BASE_DELAY := 100.0
# 完全同期の上限を保ち、低一致の攻撃、回復と抵抗との差だけを控えめに広げる。
const SYNC_SIGMA_SCALE := 0.85
# CPUの評価は実効量を基準とし、終局を最優先する。戦闘式には使わない。
const CPU_DAMAGE_WEIGHT := 1.2
const CPU_HEAL_WEIGHT := 0.85
# 位置操作だけの補助評価。確定した終局と即時ダメージより控えめに比較する。
const CPU_UTILITY_GOAL_WEIGHT := 12.0
const CPU_UTILITY_PRESSURE_WEIGHT := 0.25
const CPU_KILL_BONUS := 120.0
const CPU_DANGER_WEIGHT := 0.35
# 可能性のある致命傷を、確定した終局のスコアと混同しない。
const CPU_CRITICAL_RISK_WEIGHT := 2.0
const CPU_REPEAT_PENALTY := 18.0
const CPU_MEMORY_LIMIT := 8
const CPU_TERMINAL_SCORE := 1000000.0
const CPU_TIMES := {"THINK":0.30,"ROUTE":0.16,"COMMIT":0.14,"ACTION":0.18,"TARGET":0.20,"RESULT":0.40}
const CPU_FAST_SPEED := 4.0
# 各歩の変化を読み、長経路も抑えた時間で着地へ進める。
const MOVEMENT_CELL_SECONDS := 0.28
const MOVEMENT_MAX_SECONDS := 0.90
# 0より大きく1未満にし、各中心でも平均速度の1-aを残して位置とリングを同じ拍へそろえる。
const MOVEMENT_CELL_PULSE := 0.60
# 移動を伴う攻撃だけ、着地の状態を短く見せてから実行する。
const MOVEMENT_ATTACK_BEAT_SECONDS := 0.22
# 発生源だけを出発前に消し、着地の再表示は攻撃前の一拍へ重ねる。
const MOVEMENT_CLOUD_OUT_SECONDS := 0.12
const MOVEMENT_CLOUD_IN_SECONDS := 0.18
# 待ち時間を加えない表示。攻撃の収束は維持し、回復は中心から広がる。
const CONVERGENCE_COUNT := 3
const CONVERGENCE_STAGGER_SECONDS := 0.06
const CONVERGENCE_TRAVEL_SECONDS := 0.30
const CONVERGENCE_SECONDS := CONVERGENCE_TRAVEL_SECONDS+(CONVERGENCE_COUNT-1)*CONVERGENCE_STAGGER_SECONDS
const CONVERGENCE_OUTER_SCALE := 1.9
const CONVERGENCE_LINE_WIDTH := 1.35
const CONVERGENCE_MIN_PIXEL_WIDTH := 1.0
const CONVERGENCE_HEAL_START_SCALE := 0.12
const CONVERGENCE_HEAL_EASE_POWER := 1.4
const CONVERGENCE_COLOR_VALUE := 0.97
const CONVERGENCE_ALPHA := 0.82
const CONVERGENCE_SEGMENTS := 128
# 最初の回復円がHPを横切る時だけ実増分を見せる。戦闘処理と円の寿命は変えない。
const RING_RESPONSE_HEAL_SECONDS=0.18
const RING_RESPONSE_HEAL_WIDTH=3.4
const RING_RESPONSE_HEAL_ALPHA=0.55
const RING_RESPONSE_HEAL_WHITE=0.8

const CPU_CONTROL_ORIGIN := Vector2(1440,772)
const MUTANT_CHANCE := 0.10
const SAVE_VERSION := 3
# 密度の母数は除外前の全100セル。
const PANEL_EFFECT_RATE := 0.20
const CELL_BORDER_INSET := 1.0
const PANEL_ICON_SIZE := 20.0
# セル枠と外側リングの間へ少し寄せ、左の上下で同じ中心と対称の余白を使う。
const CELL_CORNER_ICON_INSET := 14.0
const PANEL_ICON_OFFSET := Vector2.ONE*(CELL_CORNER_ICON_INSET-PANEL_ICON_SIZE/2)
# 雲片が発生源の周囲8マス内をゆっくり巡る。面だけを重ね、破線は移動後の予測。
const FIELD_CLOUD_WISPS := 6
const FIELD_CLOUD_LAYERS := 3
const FIELD_CLOUD_TEXTURE_SIZE := 64
const FIELD_CLOUD_ORBIT := 1.02
const FIELD_CLOUD_SPEED := 0.13
const FIELD_CLOUD_RADIUS := Vector2(0.48,0.38)
const FIELD_CLOUD_ALPHA := 0.055
const FIELD_CLOUD_PREVIEW_ALPHA := 0.34
const FIELD_CLOUD_PIXEL_MIN := 0.8

# 参照の細い分割円弧を、最小セルでも読める比率で描く。
# COREは固定し、GEARとARMSだけ内側へ寄せる。
const UNIT_RING_RADII := [0.60,0.72,0.84]
const UNIT_RING_WIDTH := 0.055
const UNIT_SECTOR_GAP := 1.2
const UNIT_SECTOR_GAP_RATIO := 0.06
const UNIT_GAP_MAX_FRACTION := 0.30
const UNIT_MIN_LINE := 1.0
const UNIT_HP_RADIUS := 0.41
const UNIT_HP_WIDTH := 0.022
const UNIT_HP_MIN_LINE := 0.65
# 防御はHPとCOREの空間へ薄い八角形を重ね、リングの情報と外形を保つ。
const UNIT_GUARD_SIDES := 8
const UNIT_GUARD_RADIUS := 0.52
const UNIT_GUARD_WIDTH := 0.018
const UNIT_GUARD_PIXEL_MIN := 0.85
const UNIT_GUARD_FILL_ALPHA := 0.045
# 設定アクセントの八角形を白いHPから区別し、薄い雲の上でも輪郭を読める濃さ。
const UNIT_GUARD_LINE_ALPHA := 0.95
const UNIT_NAME_SIZE := 0.52
const UNIT_NAME_MIN := 14
const UNIT_TICK_RADII := Vector2(0.80,0.94)
const UNIT_TICK_WIDTH := 0.025
# 盤面だけを中央に揃え、外径を約13%広げる。
const UNIT_BOARD_CENTER := Vector2(35,35)
const UNIT_BOARD_RADIUS := 31.0
# 細線が物理1px未満で途切れない下限と、円弧の物理的な弦誤差。
const UNIT_HP_PIXEL_MIN := 0.9
const UNIT_COLOR_PIXEL_MIN := 1.1
const UNIT_ARC_ERROR_PIXELS := 0.03
# AAと線端がリングや目盛りに接触しない物理余白。
const ROUTE_RING_GAP_PIXELS := 2.5
const ROUTE_LINE_WIDTH := 2.0
const ROUTE_NODE_RADIUS := 14.0
# 色相とVを維持し、既存プリセットの判読性を保つリング用の彩度強調。
const UNIT_RING_SATURATION_POWER := 2.0

# 高さを盤面に使い、右下のメニューと盤面の下端を揃える。
const BATTLE_BOARD_ORIGIN := Vector2(384,16)
const BATTLE_CELL := 100.0
const BATTLE_LEFT_ORIGIN := Vector2(40,0)
const BATTLE_TITLE_BASELINE := 76.0
# 縦間隔は行動順だけを表し、待ち量は各点の円弧へ分離する。
# HPからTURNと、状態下端から予測の見える余白を揃える。
const TIMELINE_AXIS_X := 200.0
const TIMELINE_TOP := 270.0
const TIMELINE_BOTTOM := 652.0
const TIMELINE_CARD_X := Vector2(100,300)
const TIMELINE_CARD_MIN := 282.0
const TIMELINE_CARD_MAX := 602.0
const TIMELINE_CARD_GAP := 108.0
const TIMELINE_CARD_SIZE := Vector2(152,104)
const TIMELINE_RADIUS := 22.0
const TIMELINE_READOUT := Vector2(40,664)
const TIMELINE_EVENTS := 6
const TIMELINE_LINE := 0.8
const TIMELINE_NODE_RADIUS := 9.0
const TIMELINE_NODE_WIDTH := 1.4
const TIMELINE_HIT_RADIUS := 14.0
const TIMELINE_NODE_RATIO := 0.30
const TIMELINE_HIT_RATIO := 0.45
const TIMELINE_HP_FONT := 13
const TIMELINE_FACTOR_FONT := 13
# 固定3桁とIの位置を保ったまま、既存の1文字分の空白へ加えるR側の余白。
const TIMELINE_FACTOR_EXTRA_GAP := 4.0
const TIMELINE_TURN_CENTER := Vector2(200,232)
const TIMELINE_TURN_FONT := 15
const TIMELINE_READOUT_FONT := 15
const BATTLE_INFO_OFFSET := Vector2(76,-44)
const BATTLE_HP_BASELINE := 120.0
const BATTLE_HP_STEP := 40.0
const BATTLE_HP_FONT_SIZE := 17
const BATTLE_HP_BAR := Rect2(96,-6,130,5)
const BATTLE_HP_GAP := 16.0
const BATTLE_HP_RIGHT := 360.0
# BUILDは左から構成と結果、装備の比較、スキルと出撃の3列。
const BUILD_RECT := Rect2(300,115,1320,810)
# トグル同士を近づけて右へ揃え、ユニット選択との余白を広くする。
const BUILD_CPU_TOGGLE_RECT := Rect2(988,22,288,43)
const BUILD_TOGGLE_GAP := 16.0
# ラベル、ON/OFF、スイッチを小さな間隔でまとめ、項目間の余白と区別する。
const BUILD_TOGGLE_CONTENT_GAP := 8.0
const DEBUG_TOGGLE_RECT := Rect2(BUILD_CPU_TOGGLE_RECT.position-Vector2(BUILD_CPU_TOGGLE_RECT.size.x+BUILD_TOGGLE_GAP,0),BUILD_CPU_TOGGLE_RECT.size)
const CHOICE_ROW_FONT := 16
# 配置コードを主にし、通常配置の補足だけを小さく添える。
const LAYOUT_STANDARD_FONT := 13
const LAYOUT_STANDARD_GAP := 10.0
const CHOICE_RECT := Rect2(320,130,1280,820)
const DEBUG_BADGE_RECT := Rect2(40,8,500,28)
const DEBUG_BADGE_FONT := 18
const BUILD_COLUMNS := [36.0,480.0,934.0]
const BUILD_EQUIPMENT_WIDTH := 400.0
const BUILD_STAT_STEP := 84.0
const BUILD_EQUIPMENT_STAT_STEP := 80.0
const BUILD_EQUIPMENT_LABEL_FONT := 14
const BUILD_EQUIPMENT_VALUE_FONT := 15
const BUILD_EQUIPMENT_ROWS := [136.0,410.0]
# 剣と盾の可視中心を見出し文字へ揃え、図柄と大きさは保つ。
const BUILD_EQUIPMENT_ICON := Rect2(0,-1,20,20)
const UI_FIELD_LINE := 1
const UI_FOCUS_LINE := 2
# 右情報を盤面から56px離し、識別と行動判断に必要な内容へ絞る。
const BATTLE_INFO_CLASS := Vector2(1440,96)
const BATTLE_INFO_RING := Vector2(1640,201)
const BATTLE_INFO_MOVE := Vector2(1440,477)
const BATTLE_INFO_SKILLS := Vector2(1440,563)
# 説明は低い不透明度ではなく既存MUTED色で読みやすさを保つ。
const BATTLE_INFO_DESCRIPTION_OFFSET := Vector2(0,24)
const BATTLE_INFO_DESCRIPTION_FONT := 15
# 背景と枠を持たない種別記号と名称。最長の突然変異名でも省略しない。
const BATTLE_EQUIPMENT_ICON := Rect2(1440,334,20,20)
const BATTLE_EQUIPMENT_STEP := 56.0
const BATTLE_EQUIPMENT_NAME_GAP := 12.0
const BATTLE_EQUIPMENT_BASELINE := 16.0
const BATTLE_SKILL_STEP := 62.0
const BATTLE_MENU_ORIGIN := Vector2(1440,928)
const BATTLE_MENU_SIZE := Vector2(190,40)
const BATTLE_MENU_GAP := Vector2(20,8)
const BATTLE_CONTEXT_BUTTON := Rect2(1440,872,400,40)
# 見出しも含むまとまりの上端を下げ、HPからTURNと同じ余白を作る。下端は維持する。
const PREVIEW_VERTICAL_OFFSET := 33.0
const PREVIEW_PANEL := Rect2(40,680+PREVIEW_VERTICAL_OFFSET,320,280-PREVIEW_VERTICAL_OFFSET)
const PANEL_HINT_RECT := Rect2(40,962,320,72)
const PANEL_HINT_TITLE_FONT := 15
const PANEL_HINT_DETAIL_FONT := 14
const PREVIEW_HEADING_CENTER := Vector2(200,696+PREVIEW_VERTICAL_OFFSET)
const PREVIEW_CENTER := Vector2(200,804+PREVIEW_VERTICAL_OFFSET)
const PREVIEW_RADIUS := 60.0
const PREVIEW_SYNC_BASELINE := 934.0
# 通知は盤面の下で、同期率とシステムメニューを避ける。
const BATTLE_MESSAGE_POSITION := Vector2(40,1053)
# 同じ軌道付近で4曲線を重ね、形は実際の配分と一致度へ従わせる。
# 実SPDによる基礎速度に役割差を加え、同SPDでも表示の周期を分ける。
const PREVIEW_MOTION_RATE := TAU/5.0
const PREVIEW_RATE_BIASES := [1.0,1.17,1.37]
const PREVIEW_RATE_GAP := PREVIEW_MOTION_RATE*0.04
const PREVIEW_MOTION_PHASES := [0.0,TAU/3,TAU*2/3]
const PREVIEW_SAMPLES := 360
const PREVIEW_RADII := [78.0,78.8,79.6,78.8]
const PREVIEW_AMPLITUDES := [8.0,8.0,8.0,14.0]
# 不一致の揺れを抑え、局所的一致の振幅差を動画でも読み取れるようにする。
const PREVIEW_MIN_GAIN := 0.14
const PREVIEW_RESULT_MIN_GAIN := 0.025
# 強一致の合成だけを共通の速い時計と有界な増幅へ混ぜ、個別3波と弱一致は維持する。
const PREVIEW_RESULT_BOOST_START := 0.35
const PREVIEW_RESULT_RATE_SCALE := 1.8
const PREVIEW_RESULT_WAVE_GAIN := 2.4
# 実境界の両側を滑らかに結び、狭い領域では隣接間隔の半分へ縮める。
const PREVIEW_BLEND_DEGREES := 8.0
const PREVIEW_LINE := 0.9
const PREVIEW_LINE_MAX := 1.7
# 結果の輪郭を通常の縮小表示でも追えるよう、他の細線より少し太くする。
const PREVIEW_RESULT_LINE := 2.0
const PREVIEW_RESULT_LINE_MAX := 3.8
const PREVIEW_PIXEL_MIN := 0.9
# RGBと境界の補間を保ち、不一致だけを暗くして一致部分の明るい縁を強調する。
const PREVIEW_BASE_ALPHA := 0.24
const PREVIEW_CLEAR_ALPHA := 1.0
const PREVIEW_RESULT_BASE_ALPHA := 0.07
const PREVIEW_RESULT_CLEAR_ALPHA := 1.0

# 紋章はHP円弧より内側へ置き、位相とHPとは別の単色の形として描く。
const UNIT_IDENTICON_RADIUS := 0.29
const UNIT_IDENTICON_ALPHA := 0.86
const UNIT_IDENTICON_EDGE := 0.55
const UNIT_IDENTICON_PIXEL_MIN := 0.65
const OWNER_MARK_OFFSET := Vector2(CELL_CORNER_ICON_INSET-BATTLE_CELL/2,BATTLE_CELL/2-CELL_CORNER_ICON_INSET)
const TIMELINE_NAME_FONT := 12
const TIMELINE_NAME_OFFSET := Vector2(0,-30)
const TIMELINE_NAME_WIDTH := 152.0
const BATTLE_NAME_ORIGIN := Vector2(1480,28)
const BATTLE_NAME_WIDTH := 360.0
const BATTLE_NAME_FONT := 18
const BATTLE_NAME_MAX_LINES := 2
const BATTLE_NAME_LINE := 22

const ASSEMBLY_EMBLEM_RADIUS := 10.0
const ASSEMBLY_HP_GAP := 12.0
const ASSEMBLY_INFO_GAP := 12.0
const ASSEMBLY_EMBLEM_EDGE := 1.0
const ASSEMBLY_EMBLEM_PIXEL_MIN := 1.0
const ASSEMBLY_BUILD_ENTRY := Rect2(1030,77,246,35)
const ASSEMBLY_DIALOG_RECT := Rect2(550,244,820,544)
const ASSEMBLY_COLOR_NOTE_Y := 413.0
const ASSEMBLY_ACTION_Y := 468.0
const OWNER_MARK_RADIUS := 6.0

# Languageは表示操作の行へ収め、配色の既存配置を維持する。
const SETTINGS_LANGUAGE_LABEL := Rect2(524,214,120,26)
const SETTINGS_LANGUAGE_CHOICE := Rect2(652,205,372,44)
const SETTINGS_LANGUAGE_NOTE := Rect2(36,254,988,26)
# HELPの既存SVGだけ、見出しの大文字の実描画中心へ合わせる。
const HELP_ICON_VERTICAL_OFFSET := -5.5

# 日本語本文は既存の段落高に収め、文字サイズは英語と揃える。
const JAPANESE_PROSE_SPACING := 0

# 既存の目標文の紋章比率。段落の行内領域も同じ直径を確保する。
const OBJECTIVE_REF_CREST_SCALE := 0.65
