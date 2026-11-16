## 戦闘予定を変更せず、待ち量の実点と現在状態の配置を生成する。
extends RefCounted
const T=preload("res://game/tuning.gd")
const B=preload("res://game/battle.gd")

## unitsは現在状態、actorは行動番号、rowsは予定、finishedは終了。戻り値は純粋な配置辞書。入力を変更しない。
static func layout(units: Array, actor: int, rows: Array, finished: bool=false) -> Dictionary:
	var now=float(units[actor].next_time) if actor>=0 else 0.0
	var events=[]
	var seen=[]
	if not finished:
		for row in rows:
			if units[row.index].hp<=0:
				continue
			events.append({"index":row.index,"time":row.time,"rank":events.size()+1,"extra":false,"repeated":seen.has(row.index)})
			seen.append(row.index)
		# 6件に入らない遅いユニットも、順位を捏造せず次回の実時刻をつなぐ。
		var missing=[]
		for i in range(units.size()):
			if units[i].hp>0 and not seen.has(i):
				missing.append({"index":i,"time":units[i].next_time,"rank":-1,"extra":true,"repeated":false})
		while not missing.is_empty():
			var best=0
			for i in range(1,missing.size()):
				if missing[i].time<missing[best].time-B.TIME_EPS:
					best=i
			events.append(missing.pop_at(best))
	var span=0.0
	for event in events:
		event.remaining=maxf(0.0,event.time-now)
		span=maxf(span,event.remaining)
	var groups=[]
	for event in events:
		event.point=Vector2(T.TIMELINE_AXIS_X,T.TIMELINE_TOP+(event.remaining/span if span>0 else 0.0)*(T.TIMELINE_BOTTOM-T.TIMELINE_TOP))
		if groups.is_empty() or event.point.y-groups[-1].events[-1].point.y>=T.TIMELINE_GROUP_GAP:
			groups.append({"events":[],"labels":[]})
		groups[-1].events.append(event)
	for group in groups:
		for i in range(group.events.size()):
			# 通常は最大4件。極端な外部データでもIDを省略せず折り返す。
			var column=i%4
			var count=mini(4,group.events.size()-int(i/4)*4)
			var center=Vector2(T.TIMELINE_AXIS_X+(column-(count-1)/2.0)*T.TIMELINE_ID_STEP,group.events[0].point.y-10-int(i/4)*18)
			group.labels.append({"event":group.events[i],"center":center,"rect":Rect2(center-Vector2(7,13),Vector2(14,17))})
	var cards=[]
	for i in range(units.size()):
		var event={}
		for e in events:
			if e.index==i:
				event=e
				break
		cards.append({"index":i,"unit":units[i].duplicate(true),"event":event,"center":Vector2(T.TIMELINE_CARD_X.x if i<2 else T.TIMELINE_CARD_X.y,clampf(event.point.y if not event.is_empty() else T.TIMELINE_CARD_MAX,T.TIMELINE_CARD_MIN,T.TIMELINE_CARD_MAX))})
	for side in [[0,1],[2,3]]:
		side.sort_custom(func(a,b):return cards[a].center.y<cards[b].center.y if cards[a].center.y!=cards[b].center.y else a<b)
		cards[side[0]].center.y=minf(cards[side[0]].center.y,T.TIMELINE_CARD_MAX-T.TIMELINE_CARD_GAP)
		cards[side[1]].center.y=maxf(cards[side[1]].center.y,cards[side[0]].center.y+T.TIMELINE_CARD_GAP)
	for card in cards:
		card.rect=Rect2(card.center-Vector2(T.TIMELINE_CARD_SIZE.x/2,26),T.TIMELINE_CARD_SIZE)
	return {"now":now,"span":span,"events":events,"groups":groups,"cards":cards,"finished":finished}

## viewは配置、pointは論理座標。戻り値は対応節点か状態の番号と時刻、範囲外は空辞書。副作用なし。
static func hit(view: Dictionary, point: Vector2) -> Dictionary:
	for group in view.groups:
		for label in group.labels:
			if label.rect.has_point(point):
				return label.event
	for event in view.events:
		if point.distance_to(event.point)<=7.0:
			return event
	for card in view.cards:
		if card.rect.has_point(point):
			return card.event if not card.event.is_empty() else {"index":card.index}
	return {}

## eventは節点、actorは行動番号。戻り値は正確な相対待ち量と0の意味。副作用なし。
static func caption(event: Dictionary, actor: int) -> String:
	if event.is_empty():
		return "FINISHED"
	var name=["1","2","A","B"][event.index]
	if not event.has("remaining"):
		return name+" / DEFEATED"
	var number=("%.12f" % event.remaining).rstrip("0").rstrip(".")
	if event.remaining<=B.TIME_EPS:
		return name+"  "+number+" / "+("ACTING" if event.index==actor and not event.repeated else "QUEUED")
	return name+"  +"+number+(" / NEXT" if event.extra else "")
