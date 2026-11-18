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
const CPU_CONTROL_ORIGIN := Vector2(1440,772)
const MUTANT_CHANCE := 0.10
const SAVE_VERSION := 1
# 密度の母数は除外前の全100セル。
const PANEL_EFFECT_RATE := 0.20
const CELL_BORDER_INSET := 1.0
const PANEL_ICON_SIZE := 20.0
const PANEL_ICON_OFFSET := Vector2(3,3)
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
const UNIT_HP_COLOR := Color.WHITE
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
const TIMELINE_CARD_GAP := 100.0
const TIMELINE_CARD_SIZE := Vector2(120,88)
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
const BATTLE_HP_VALUE_X := 242.0
const BATTLE_HP_FONT_SIZE := 17
const BATTLE_HP_BAR := Rect2(126,-6,100,5)
const BATTLE_HP_GAP := 16.0
const BATTLE_HP_RIGHT := 360.0
# BUILDは左から構成と結果、装備の比較、スキルと出撃の3列。
const BUILD_RECT := Rect2(300,115,1320,810)
const BUILD_COLUMNS := [36.0,480.0,934.0]
const BUILD_EQUIPMENT_WIDTH := 400.0
const BUILD_STAT_STEP := 84.0
const BUILD_EQUIPMENT_STAT_STEP := 80.0
const BUILD_EQUIPMENT_LABEL_FONT := 14
const BUILD_EQUIPMENT_VALUE_FONT := 15
const BUILD_EQUIPMENT_ROWS := [136.0,410.0]
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
const PREVIEW_PANEL := Rect2(40,680,320,280)
const PREVIEW_CENTER := Vector2(200,804)
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
const PREVIEW_AMPLITUDES := [6.0,6.0,6.0,10.0]
# 局所的一致が低い輪郭も読める最小振幅倍率。完全一致で最大振幅になる。
const PREVIEW_MIN_GAIN := 0.35
# 実境界の両側を滑らかに結び、狭い領域では隣接間隔の半分へ縮める。
const PREVIEW_BLEND_DEGREES := 8.0
const PREVIEW_LINE := 0.9
const PREVIEW_LINE_MAX := 1.4
# 結果の輪郭を通常の縮小表示でも追えるよう、他の細線より少し太くする。
const PREVIEW_RESULT_LINE := 2.0
const PREVIEW_RESULT_LINE_MAX := 3.4
const PREVIEW_PIXEL_MIN := 0.9
# 暗い不一致の輪郭も読み取りやすくし、一致時の鮮明さとの差を残す。
const PREVIEW_BASE_ALPHA := 0.72
const PREVIEW_CLEAR_ALPHA := 1.0
const PREVIEW_RESULT_BASE_ALPHA := 0.45
const PREVIEW_RESULT_CLEAR_ALPHA := 1.0
