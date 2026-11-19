## 戦闘予定を変更せず、独立した行動順点と現在状態の配置を生成する。
extends RefCounted
const I=preload("res://game/unit_identity.gd")
const T=preload("res://game/tuning.gd")
const B=preload("res://game/battle.gd")

## battleは戦闘。戻り値は直近の予定と全生存者の初回を含む連続した実行順。戦闘を変更しない。
static func rows(battle: RefCounted) -> Array:
	if battle.mode=="RESULT" or battle.actor<0:
		return []
	var horizon=float(battle.units[battle.actor].next_time)
	for unit in battle.units:
		if unit.hp>0:
			horizon=maxf(horizon,unit.next_time)
	var count=0
	for unit in battle.units:
		if unit.hp>0:
			count+=maxi(1,floori((horizon+B.TIME_EPS-unit.next_time)/battle.M.delay(unit))+1)
	return battle.timeline(maxi(T.TIMELINE_EVENTS,count))

## unitsは現在状態、actorは行動番号、rowsは連続予定、finishedは終了。戻り値は純粋な配置辞書。入力を変更しない。
static func layout(units: Array, actor: int, rows: Array, finished: bool=false) -> Dictionary:
	var now=float(units[actor].next_time) if actor>=0 else 0.0
	var events=[]
	var seen=[]
	var alive=units.filter(func(u):return u.hp>0).size()
	if not finished:
		for row in rows:
			if units[row.index].hp<=0:
				continue
			events.append({"index":row.index,"time":row.time,"rank":events.size()+1,"repeated":seen.has(row.index),"name":I.effective_name(units[row.index].get("display_name",""),units[row.index].id,units[row.index].camp)})
			if not seen.has(row.index):
				seen.append(row.index)
			if events.size()>=T.TIMELINE_EVENTS and seen.size()==alive:
				break
	var span=0.0
	for event in events:
		event.remaining=maxf(0.0,event.time-now)
		span=maxf(span,event.remaining)
	var spacing=(T.TIMELINE_BOTTOM-T.TIMELINE_TOP)/maxi(1,events.size()-1)
	for i in range(events.size()):
		var event=events[i]
		event.point=Vector2(T.TIMELINE_AXIS_X,T.TIMELINE_TOP+i*spacing)
		event.wait_fraction=event.remaining/span if span>0 else 0.0
		event.progress_fraction=1.0-event.wait_fraction
		event.radius=minf(T.TIMELINE_NODE_RADIUS,spacing*T.TIMELINE_NODE_RATIO)
		var hit_size=minf(T.TIMELINE_HIT_RADIUS,spacing*T.TIMELINE_HIT_RATIO)
		event.hit_rect=Rect2(event.point-Vector2(T.TIMELINE_HIT_RADIUS,hit_size),Vector2(T.TIMELINE_HIT_RADIUS*2,hit_size*2))
	var cards=[]
	for i in range(units.size()):
		var event={}
		for e in events:
			if e.index==i:
				event=e
				break
		cards.append({"index":i,"unit":units[i].duplicate(true),"event":event,"center":Vector2(T.TIMELINE_CARD_X.x if units[i].camp=="PLAYER" else T.TIMELINE_CARD_X.y,clampf(event.point.y if not event.is_empty() else T.TIMELINE_CARD_MAX,T.TIMELINE_CARD_MIN,T.TIMELINE_CARD_MAX))})
	for camp in ["PLAYER","ENEMY"]:
		var side=range(cards.size()).filter(func(index):return cards[index].unit.camp==camp)
		side.sort_custom(func(a,b):return cards[a].center.y<cards[b].center.y if cards[a].center.y!=cards[b].center.y else a<b)
		for position in range(side.size()):
			var remaining=side.size()-1-position
			cards[side[position]].center.y=minf(cards[side[position]].center.y,T.TIMELINE_CARD_MAX-T.TIMELINE_CARD_GAP*remaining)
			if position>0:
				cards[side[position]].center.y=maxf(cards[side[position]].center.y,cards[side[position-1]].center.y+T.TIMELINE_CARD_GAP)
	for card in cards:
		card.rect=Rect2(card.center-Vector2(T.TIMELINE_CARD_SIZE.x/2,44),T.TIMELINE_CARD_SIZE)
	var links=[]
	for event in events:
		var card=cards[event.index]
		var sign=-1.0 if card.unit.camp=="PLAYER" else 1.0
		links.append({"index":card.index,"event":event,"points":PackedVector2Array([event.point+Vector2(sign*event.radius,0),Vector2(T.TIMELINE_AXIS_X+sign*20,event.point.y),Vector2(card.center.x-sign*44,card.center.y),Vector2(card.center.x-sign*24,card.center.y)])})
	return {"now":now,"span":span,"events":events,"links":links,"cards":cards,"finished":finished}

## viewは配置、pointは論理座標。戻り値は対応節点か状態の番号と時刻、範囲外は空辞書。副作用なし。
static func hit(view: Dictionary, point: Vector2) -> Dictionary:
	for event in view.events:
		if event.hit_rect.has_point(point):
			return event
	for card in view.cards:
		if card.rect.has_point(point):
			return card.event if not card.event.is_empty() else {"index":card.index,"name":I.effective_name(card.unit.get("display_name",""),card.unit.id,card.unit.camp)}
	return {}

## eventは節点、actorは行動番号。戻り値は正確な相対待ち量と0の意味。副作用なし。
static func caption(event: Dictionary, actor: int) -> String:
	if event.is_empty():
		return "FINISHED"
	if not event.has("remaining"):
		return "DEFEATED"
	var number=("%.12f" % event.remaining).rstrip("0").rstrip(".")
	if event.remaining<=B.TIME_EPS:
		return number+" / "+("ACTING" if event.index==actor and not event.repeated else "QUEUED")
	return "+"+number
