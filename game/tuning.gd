## 体験評価で調整する値を一元管理する。
extends RefCounted

const BASE_HP := 100.0
const BASE_DAMAGE := 45.0
const BASE_HEAL := 24.0
const BASE_MOVE := 3
const BASE_DELAY := 100.0
const MUTANT_CHANCE := 0.10
const SAVE_VERSION := 1
# 密度の母数は除外前の全100セル。
const PANEL_EFFECT_RATE := 0.20
const PANEL_ICON_SIZE := 20.0
const PANEL_ICON_OFFSET := Vector2(3,3)

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
const TIMELINE_AXIS_X := 200.0
const TIMELINE_TOP := 242.0
const TIMELINE_BOTTOM := 624.0
const TIMELINE_CARD_X := Vector2(100,300)
const TIMELINE_CARD_MIN := 254.0
const TIMELINE_CARD_MAX := 586.0
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
const TIMELINE_READOUT_FONT := 15
const BATTLE_INFO_OFFSET := Vector2(76,-44)
const BATTLE_HP_BASELINE := 120.0
const BATTLE_HP_STEP := 40.0
const BATTLE_HP_VALUE_X := 126.0
const BATTLE_HP_FONT_SIZE := 17
const BATTLE_HP_BAR := Rect2(240,-6,120,5)
const BATTLE_HP_GAP := 16.0
# 右情報を盤面から56px離し、識別と行動判断に必要な内容へ絞る。
const BATTLE_INFO_CLASS := Vector2(1440,96)
const BATTLE_INFO_RING := Vector2(1640,201)
const BATTLE_INFO_MOVE := Vector2(1440,477)
const BATTLE_INFO_SKILLS := Vector2(1440,563)
# 説明は低い不透明度ではなく既存MUTED色で読みやすさを保つ。
const BATTLE_INFO_DESCRIPTION_OFFSET := Vector2(0,24)
const BATTLE_INFO_DESCRIPTION_FONT := 15
# 背景と入力部品を持たない装備の輪郭だけをリングの直下へ置く。
const BATTLE_EQUIPMENT_FRAME := Rect2(1440,322,400,44)
const BATTLE_EQUIPMENT_FRAME_STEP := 56.0
const BATTLE_EQUIPMENT_LABEL_OFFSET := Vector2(16,28)
const BATTLE_EQUIPMENT_FRAME_LINE := 0.8
const BATTLE_EQUIPMENT_FRAME_OPACITY := 0.28
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
const PREVIEW_SAMPLES := 360
const PREVIEW_RADII := [78.0,78.8,79.6,78.8]
const PREVIEW_AMPLITUDES := [8.0,8.0,8.0,10.0]
# 実境界の両側を滑らかに結び、狭い領域では隣接間隔の半分へ縮める。
const PREVIEW_BLEND_DEGREES := 8.0
const PREVIEW_LINE := 0.9
# 結果の輪郭を通常の縮小表示でも追えるよう、他の細線より少し太くする。
const PREVIEW_RESULT_LINE := 2.0
const PREVIEW_PIXEL_MIN := 0.9
# 暗い不一致の輪郭も読み取りやすくし、一致時の鮮明さとの差を残す。
const PREVIEW_BASE_ALPHA := 0.72
const PREVIEW_CLEAR_ALPHA := 0.92
const PREVIEW_RESULT_BASE_ALPHA := 0.45
const PREVIEW_RESULT_CLEAR_ALPHA := 1.0
