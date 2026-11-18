## デバッグ限定の新規全解放と、編集しない通常状態への復帰を管理する。
extends RefCounted
const C=preload("res://game/catalog.gd")
const L=preload("res://game/collection.gd")
var allowed := true
var _normal: RefCounted

## 利用可否を返す。戻り値は実際のデバッグビルドかつ許可された場合だけ真。副作用なし。
func available() -> bool:
	return OS.is_debug_build() and allowed

## 一時モードの状態を返す。戻り値は通常データを保持しているか。副作用なし。
func active() -> bool:
	return _normal!=null

## 全解放を開始する。normalは保持する通常データ。戻り値は新規の一時コレクション、利用不可または開始済みならnull。通常データは変更しない。
func begin(normal: RefCounted) -> RefCounted:
	if not available() or active():return null
	_normal=normal
	var sandbox=L.new()
	sandbox.temporary=true
	sandbox.items={"ARMS":{},"GEAR":{}}
	for kind in ["ARMS","GEAR"]:
		for stats in C.equipment_catalog():sandbox.items[kind][C.serial(kind,stats)]=stats
	sandbox.skills=C.SKILLS.keys()
	sandbox.mutations=C.mutation_catalog()
	return sandbox

## 一時モードを終了する。戻り値は元の通常データ、非実行時はnull。保持した参照だけを戻し、一時データを転記しない。
func end() -> RefCounted:
	var original=_normal
	_normal=null
	return original
