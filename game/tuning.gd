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

# 左右パネルを維持し、正方形の盤面と入力に同じ寸法を使う。
const BATTLE_BOARD_ORIGIN := Vector2(530,100)
const BATTLE_CELL := 76.0
const PREVIEW_PANEL := Rect2(150,820,370,220)
const PREVIEW_CENTER := Vector2(335,925)
const PREVIEW_RADIUS := 48.0
const PREVIEW_SYNC_BASELINE := 1026.0
# 戦闘通知は予測の右側へ分離し、同期率とフッターを覆わない。
const BATTLE_MESSAGE_POSITION := Vector2(550,976)
# 各領域の中央と境界を、離れた細い閉曲線の山と谷へ写す。
const PREVIEW_SAMPLES := 360
const PREVIEW_RADII := [51.0,57.0,63.0,70.0]
const PREVIEW_AMPLITUDES := [5.0,5.0,5.0,8.0]
const PREVIEW_LINE := 0.9
# 結果の輪郭を通常の縮小表示でも追えるよう、他の細線より少し太くする。
const PREVIEW_RESULT_LINE := 2.0
const PREVIEW_PIXEL_MIN := 0.9
# 通常の縮小表示でも色状態を読めるよう、不一致時の細線を残す。
const PREVIEW_BASE_ALPHA := 0.55
const PREVIEW_CLEAR_ALPHA := 0.92
const PREVIEW_RESULT_BASE_ALPHA := 0.25
const PREVIEW_RESULT_CLEAR_ALPHA := 1.0
