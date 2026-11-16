## 体験評価で調整する値を一元管理する。
extends RefCounted

const BASE_HP := 100.0
const BASE_DAMAGE := 45.0
const BASE_HEAL := 24.0
const BASE_MOVE := 3
const BASE_DELAY := 100.0
const MUTANT_CHANCE := 0.10
const SAVE_VERSION := 1

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
# 色相とVを維持し、既存プリセットの判読性を保つリング用の彩度強調。
const UNIT_RING_SATURATION_POWER := 2.0

# フッターを残して高さを使い、周囲の情報を盤面へ近接配置する。
const BATTLE_BOARD_ORIGIN := Vector2(384,16)
const BATTLE_CELL := 100.0
const BATTLE_LEFT_ORIGIN := Vector2(40,0)
const BATTLE_TITLE_BASELINE := 76.0
const BATTLE_TIMELINE_RECT := Rect2(40,232,320,58)
const BATTLE_TIMELINE_STEP := 64.0
const BATTLE_INFO_OFFSET := Vector2(76,-44)
const BATTLE_HP_BASELINE := 120.0
const BATTLE_HP_STEP := 40.0
const BATTLE_HP_VALUE_X := 126.0
const BATTLE_HP_FONT_SIZE := 17
const BATTLE_HP_BAR := Rect2(240,-6,120,5)
const BATTLE_HP_GAP := 16.0
const BATTLE_CONTEXT_BUTTON := Rect2(1400,950,360,37)
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
# 通常の縮小表示でも色状態を読めるよう、不一致時の細線を残す。
const PREVIEW_BASE_ALPHA := 0.55
const PREVIEW_CLEAR_ALPHA := 0.92
const PREVIEW_RESULT_BASE_ALPHA := 0.25
const PREVIEW_RESULT_CLEAR_ALPHA := 1.0
