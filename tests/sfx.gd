extends SceneTree
var checks=0
var failures=0
var events=[]
var sound
class Motion:
	extends RefCounted
	var owner=RefCounted.new()
	var turn=1
	var actor=0
	var route=[Vector2i(1,0),Vector2i(2,0),Vector2i(2,1)]
	var duration=1.0
	var elapsed=0.0
	var deltas=[[0.0,-10.0,20.0],[0.0,0.0,0.0],[360.0,-5.0,5.0]]
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var script=load("res://ui/sfx.gd") if ResourceLoader.exists("res://ui/sfx.gd") else null
	_check(script!=null,"central SFX component exists")
	if script!=null:
		sound=script.new();root.add_child(sound);await process_frame;sound.played.connect(func(kind):events.append(kind))
		await _selection()
		_rotation()
		_effects()
		_defeats()
		_resources()
		sound.queue_free();await process_frame
	await _connections()
	await create_timer(0.08).timeout
	print("SFX: %d checks / %d failures" % [checks,failures]);quit(0 if failures==0 else 1)
func _key(code: Key=KEY_ENTER) -> InputEventKey:
	var event=InputEventKey.new();event.keycode=code;event.pressed=true;return event
## REQ-054-S01
func _selection() -> void:
	sound._play("select")
	_check(events==[],"selection is excluded from playback even when requested directly")
## REQ-055-S01、REQ-055-S02
func _rotation() -> void:
	var alternating=["ring_rotate1","ring_rotate2","ring_rotate1","ring_rotate2","ring_rotate1","ring_rotate2"]
	for count in [1,3]:
		events.clear();sound.reset_battle();var motion=Motion.new();motion.route=motion.route.slice(0,count)
		# 発音は経路に従い、全輪の回転量がゼロでも同じ2拍になる。
		motion.deltas=motion.deltas.map(func(_delta):return [0.0,0.0,0.0])
		var times=[];var record=func(_kind):times.append(motion.elapsed)
		sound.played.connect(record)
		var first_frame=1.0/60
		var expected_times=[first_frame,0.5] if count==1 else [first_frame,1.0/6,1.0/3,0.5,2.0/3,5.0/6]
		var no_early=true
		sound.movement_tick(motion);no_early=events.is_empty()
		for index in range(expected_times.size()):
			if index>0:
				motion.elapsed=expected_times[index]-0.00001;sound.movement_tick(motion);no_early=no_early and events.size()==index
			motion.elapsed=expected_times[index];sound.movement_tick(motion);sound.movement_tick(motion)
		_check(events==alternating.slice(0,count*2),"one or three real steps produce exactly two alternating sounds per cell, even without rotation")
		var at_last=events.duplicate();motion.elapsed=1.0;sound.movement_tick(motion)
		_check(no_early and times==expected_times and times.front()==first_frame and events==at_last,"first advancing frame requests sound, then half-step grid stays ordered without a late cue or movement wait")
		sound.played.disconnect(record)
	events.clear();sound.reset_battle();var motion=Motion.new();motion.elapsed=0.5;sound.movement_tick(motion);var at_pause=events.duplicate();sound.suspend();sound.movement_tick(motion)
	_check(events==at_pause,"pause and resume at unchanged movement time do not replay past sounds")
	events.clear();sound.reset_battle();motion=Motion.new();motion.duration=0;sound.movement_tick(motion)
	motion=Motion.new();motion.route=[];sound.movement_tick(motion)
	motion=Motion.new();motion.owner=null;motion.elapsed=1;sound.movement_tick(motion)
	_check(events==[],"omitted movement, zero steps and cancelled movement stay silent")
	sound.reset_battle();motion=Motion.new();motion.elapsed=1;sound.movement_tick(motion)
	_check(events==alternating,"fast updates preserve all six ordered cues without adding a wait")
## REQ-056-S01、REQ-056-S02
func _effects() -> void:
	events.clear();sound.reset_battle();var owner=RefCounted.new()
	sound.effect(owner,1,"DAMAGE",0);sound.effect(owner,2,"HEAL",0);sound.effect(owner,3,"GUARD",1);sound.effect(owner,4,"PUSH",1)
	_check(events==[],"zero actual HP change and utility outcomes are silent")
	sound.effect(owner,5,"DAMAGE",0.25);sound.effect(owner,5,"DAMAGE",0.25)
	_check(events==["attack"],"fractional actual damage has one sound and repeat feedback is silent")
	sound.effect(owner,6,"HEAL",0.25);sound.effect(owner,6,"HEAL",0.25)
	_check(events==["attack","heal"],"actual capped healing uses one distinct sound")
	sound.effect(owner,7,"DAMAGE",1);_check(events==["attack","heal","attack"],"a new identical action is not confused with repeat feedback")
	sound.reset_battle();sound.effect(owner,1,"DAMAGE",1);_check(events.size()==4,"a new battle may reuse its first history number")
## REQ-058-S01、REQ-058-S02
func _defeats() -> void:
	_check(sound.has_method("advance_defeats"),"defeat audio owns a nonblocking delay and envelope")
	if not sound.has_method("advance_defeats"):return
	sound.set_process(false);events.clear();sound.reset_battle();var owner=RefCounted.new()
	var delay=sound.T.SFX_DEFEAT_DELAY_SECONDS;var hold=sound.T.SFX_DEFEAT_HOLD_SECONDS;var fade=sound.T.SFX_DEFEAT_FADE_SECONDS
	sound.effect(owner,10,"DAMAGE",0.25,true);sound.effect(owner,10,"DAMAGE",0.25,true)
	sound.advance_defeats(delay-0.00001)
	_check(events==["attack"],"lethal hit starts unchanged attack immediately, with one delayed death")
	sound.advance_defeats(0.00001+hold+fade/4);var voice=sound.defeat_voices.filter(func(p):return p.stream!=null)[0]
	_check(events==["attack","defeated"] and voice.volume_db==sound.T.SFX_VOLUME_DB.defeated,"death starts once after its single delay; late frame still preserves initial gain")
	sound.advance_defeats(hold);var before=voice.volume_db;sound.advance_defeats(fade/2)
	_check(before==sound.T.SFX_VOLUME_DB.defeated and voice.volume_db<before and voice.stream!=null,"attack portion remains intact before a continuous quieter tail")
	sound.effect(owner,11,"DAMAGE",0.25,true);sound.advance_defeats(delay)
	_check(events==["attack","defeated","attack","defeated"] and sound.defeat_voices.filter(func(p):return p.stream!=null).size()==2,"another turn can start a death without cutting the earlier tail")
	sound.effect(owner,10,"DAMAGE",0.25,true);sound.advance_defeats(hold+fade)
	_check(events.count("defeated")==2 and sound.defeat_voices.all(func(p):return p.stream==null),"old death does not repeat after later feedback; both envelopes finish")
	events.clear();sound.reset_battle()
	sound.effect(owner,1,"DAMAGE",0,true);sound.effect(owner,2,"DAMAGE",1,false);sound.effect(owner,3,"HEAL",1,true);sound.effect(owner,4,"GUARD",1,true);sound.advance_defeats(delay+hold+fade)
	_check(events==["attack","heal"],"zero loss, nonlethal damage, healing and utility never schedule death")
	sound.effect(owner,5,"DAMAGE",1,true);sound.suspend();sound.advance_defeats(delay+hold+fade)
	sound.effect(owner,6,"DAMAGE",1,true);sound.reset_battle();sound.advance_defeats(delay+hold+fade)
	_check(events.count("defeated")==0 and sound.defeat_voices.all(func(p):return p.stream==null),"stop and battle reset clear pending or sounding deaths")
	sound.set_process(true)
## REQ-057-S01
func _resources() -> void:
	_check(sound.streams.keys()==["ring_rotate1","ring_rotate2","attack","heal","defeated"] and FileAccess.file_exists("res://assets/sfx/select.ogg"),"only the movement pair, unchanged effects and defeat source play; selection original remains")
	_check(sound.streams.values().all(func(stream):return stream is AudioStreamOggVorbis and stream.get_length()>0 and not stream.loop),"all active original Ogg streams decode without looping")
	_check(sound.players.size()==2 and sound.players.values().all(func(p):return p.max_polyphony==1 and p.bus=="Master") and sound.defeat_voices.size()==sound.T.SFX_DEFEAT_MAX_VOICES and sound.defeat_voices.all(func(p):return p.max_polyphony==1 and p.bus=="Master"),"bounded lanes use the existing Master volume")
	for key in ["ring_rotate1","ring_rotate2","attack","heal"]:
		sound._play(key)
		var lane="effect" if key in ["attack","heal"] else "ring_rotate"
		_check(sound.players[lane].stream==sound.streams[key] and sound.players[lane].volume_db==sound.T.SFX_VOLUME_DB[key],"stream and configured gain connected: "+key)
	events.clear();sound.enabled=false;sound._play("attack");_check(events==[],"disabled audio does not emit or play a request");sound.enabled=true
## REQ-054-S01、REQ-055-S01、REQ-056-S01、REQ-058-S01
func _connections() -> void:
	var game=load("res://tests/fixture_main.gd").new();var folder="res://artifacts/runtime/sfx-test-"+str(Time.get_ticks_usec());game.save_path=folder+"/unused.json";game.settings_path=folder+"/settings.json";root.add_child(game);await process_frame
	var audio=game.get("sfx");_check(audio!=null,"real UI owns the central SFX component")
	if audio==null:game.queue_free();await process_frame;return
	var actual=[];audio.played.connect(func(kind):actual.append(kind))
	game._start_battle();game._cell_input(Vector2i(4,4));_check(actual==[],"accepted route selection is silent")
	game._cell_input(Vector2i(9,9));_check(actual==[],"invalid route does not beep")
	game._cell_input(Vector2i(4,4));_check(actual==[],"unchanged route click does not beep")
	await process_frame;await process_frame
	game._cell_input(Vector2i(5,4));game._cell_input(Vector2i(5,4),true);game._choose_battle_skill(game.C.DAMAGE);game._cell_input(Vector2i(6,4));game._confirm_plan();game._movement_tick(game.T.MOVEMENT_MAX_SECONDS+game.T.MOVEMENT_ATTACK_BEAT_SECONDS)
	_check(actual==["ring_rotate1","ring_rotate2","ring_rotate1","ring_rotate2","attack"],"real planned move reaches two steps with four alternating cues then actual damage without selection pips")
	var after=game.battle.units.duplicate(true);game._feedback();_check(actual.size()==5 and game.battle.units==after,"repeat effect display neither sounds nor changes HP")
	game._restart();game._start_battle();game.battle.units[1].pos=Vector2i(4,5);game.battle.units[1].hp=game.battle.units[1].max_hp-1
	game.battle.path_click(Vector2i(4,4));game.battle.commit_path();game.battle.choose_skill(game.C.HEAL);_check(game.battle.act(1),"fixture performs legal capped healing")
	game._feedback();_check(actual.back()=="heal" and game.battle.last_effect.actual>0,"real healing feedback reaches audio using actual gain")
	if audio.has_method("advance_defeats"):
		game._restart();game._start_battle();audio.set_process(false);actual.clear();game.battle.units[2].pos=Vector2i(5,4);game.battle.units[2].hp=0.25
		game.battle.path_click(Vector2i(4,4));game.battle.commit_path();game.battle.choose_skill(game.C.DAMAGE);game.battle.act(2);game._feedback();game._after_action();audio.advance_defeats(game.T.SFX_DEFEAT_DELAY_SECONDS)
		_check(actual==["attack","defeated"] and game.battle.units[2].hp==0 and game.battle.at(Vector2i(5,4))==-1,"real lethal feedback reaches delayed audio after next-turn transition without model waits")
		audio.set_process(true)
	game._restart();game._open_build_choice("class_name");await process_frame
	var dialog=game.build_dialog;actual.clear();dialog.navigate(_key(KEY_DOWN));_check(actual==[],"accepted keyboard candidate selection is silent")
	var locked=dialog.rows.filter(func(row):return not row.selectable)[0];_check(not dialog.select_candidate(locked.id) and actual==[],"locked preview selection remains silent")
	game._close_aux();game._build();await process_frame;_check(game.build_open and not FileAccess.file_exists(game.save_path) and not FileAccess.file_exists(game.settings_path),"returns normal BUILD without game or settings writes")
	game.queue_free();await process_frame
func _check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",note)
