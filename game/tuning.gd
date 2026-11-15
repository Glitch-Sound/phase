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
const UNIT_RING_RADII := [0.60,0.78,0.96]
const UNIT_RING_WIDTH := 0.055
const UNIT_SECTOR_GAP := 1.2
const UNIT_SECTOR_GAP_RATIO := 0.06
const UNIT_GAP_MAX_FRACTION := 0.30
const UNIT_MIN_LINE := 1.0
const UNIT_HP_RADIUS := 0.41
const UNIT_HP_WIDTH := 0.045
const UNIT_NAME_SIZE := 0.52
const UNIT_NAME_MIN := 14
const UNIT_TICK_RADII := Vector2(0.88,1.08)
const UNIT_TICK_WIDTH := 0.025
