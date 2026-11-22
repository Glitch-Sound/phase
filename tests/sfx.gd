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
## REQ-054-S01、REQ-054-S02
func _selection() -> void:
	sound._play("select")
	_check(events==[],"old select asset stays excluded even when requested directly")
	_check(sound.has_method("bind_buttons"),"central audio observes actual button input")
	if not sound.has_method("bind_buttons"):return
	var ui=Control.new();ui.size=Vector2(1920,1080);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(ui);sound.bind_buttons(ui);sound.bind_buttons(ui)
	var button=Button.new();button.text="STATIC";button.position=Vector2(40,40);button.size=Vector2(160,50);ui.add_child(button);sound.bind_buttons(ui);var operations=[];button.pressed.connect(func():operations.append(true))
	await process_frame;events.clear();var held=await _hold(button,false,false,operations)
	_check(held.sounds==["button"] and held.operations==0 and events==["button"] and operations.size()==1,"mouse down sounds while held; release operates once without a second pip")
	events.clear();button.grab_focus();held=await _hold(button,true,false,operations)
	_check(held.sounds==["button"] and held.operations==1 and events==["button"] and operations.size()==2,"key down sounds while held; repeats are silent and release operates once")
	events.clear();held=await _hold(button,false,true,operations)
	_check(held.sounds==["button"] and events==["button"] and operations.size()==2,"outside release cancels the operation but keeps only its early down sound")
	events.clear();button.grab_focus();var hover=InputEventMouseMotion.new();hover.position=button.get_global_rect().get_center();root.push_input(hover,true);await _press_key(KEY_TAB);button.pressed.emit();button.button_down.emit();await process_frame
	_check(events==[],"hover, focus and an internal pressed notification without activation stay silent")
	button.disabled=true;await _click(button.get_global_rect().get_center());_check(events==[],"disabled button has no pip");button.disabled=false
	var check=CheckButton.new();check.position=Vector2(250,40);check.size=Vector2(160,50);ui.add_child(check);await process_frame
	check.button_pressed=true;await process_frame;_check(events==[],"internal toggle update stays silent")
	held=await _hold(check);_check(held.sounds==["button"] and events==["button"] and not check.button_pressed,"user toggle has one early pip and keeps native toggle behavior")
	events.clear();var dynamic=Button.new();dynamic.position=Vector2(40,120);dynamic.size=Vector2(160,50);dynamic.text="DYNAMIC";ui.add_child(dynamic)
	dynamic.pressed.connect(func():dynamic.queue_free();sound.reset_battle())
	await process_frame;held=await _hold(dynamic);_check(held.sounds==["button"] and events==["button"] and not is_instance_valid(dynamic),"new candidate and screen transition neither lose nor double its pip")
	events.clear();var previous=root.gui_embed_subwindows;root.gui_embed_subwindows=true
	var option=OptionButton.new();option.position=Vector2(450,40);option.size=Vector2(180,50);option.add_item("A");option.add_item("B");ui.add_child(option);await process_frame
	option.select(1);option.get_popup().id_pressed.emit(1);await process_frame;_check(events==[],"internal option selection and notification stay silent")
	option.grab_focus();await _press_key(KEY_ENTER);await _press_key(KEY_UP)
	root.push_input(_key(),true);var at_confirmation=events.duplicate();await process_frame
	var release=_key();release.pressed=false;root.push_input(release,true);await process_frame
	_check(at_confirmation==["button","button"] and events==at_confirmation,"dropdown opening and actual confirmation each have one pip; arrow focus is silent")
	events.clear();sound.enabled=false;button.grab_focus();await _press_key(KEY_SPACE);_check(events==[],"disabled SFX flag suppresses a valid button press");sound.enabled=true
	ui.queue_free();await process_frame;root.gui_embed_subwindows=previous;events.clear()
func _hold(button: BaseButton,keyboard: bool=false,outside: bool=false,operations: Array=[]) -> Dictionary:
	var position=button.get_global_rect().get_center()
	if keyboard:button.grab_focus();root.push_input(_key(),true)
	else:
		var down=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.button_mask=MOUSE_BUTTON_MASK_LEFT;down.position=position;down.global_position=position;root.push_input(down,true)
	await process_frame;await process_frame
	if keyboard:
		var repeat=_key();repeat.echo=true;root.push_input(repeat,true);await process_frame
	var result={"sounds":events.duplicate(),"operations":operations.size()}
	if keyboard:
		var up=_key();up.pressed=false;root.push_input(up,true)
	else:
		if outside:
			position=Vector2(10,10);var motion=InputEventMouseMotion.new();motion.position=position;motion.global_position=position;root.push_input(motion,true)
		var up=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.position=position;up.global_position=position;root.push_input(up,true)
	await process_frame;return result
func _click(position: Vector2) -> void:
	for down in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;event.pressed=down;event.position=position;event.global_position=position;root.push_input(event,true);await process_frame
func _press_key(code: Key) -> void:
	for down in [true,false]:
		var event=InputEventKey.new();event.keycode=code;event.pressed=down;root.push_input(event,true);await process_frame
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
	_check(sound.streams.keys()==["ring_rotate1","ring_rotate2","attack","heal","defeated","button"] and FileAccess.file_exists("res://assets/sfx/select.ogg"),"only the original combat sources and generated button stream play; select original remains")
	_check(sound.streams.values().all(func(stream):return stream.get_length()>0 and ((stream is AudioStreamOggVorbis and not stream.loop) or (stream is AudioStreamWAV and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED))),"all active original and generated streams decode without looping")
	_check(sound.players.size()==3 and sound.players.values().all(func(p):return p.max_polyphony==1 and p.bus=="Master") and sound.defeat_voices.size()==sound.T.SFX_DEFEAT_MAX_VOICES and sound.defeat_voices.all(func(p):return p.max_polyphony==1 and p.bus=="Master"),"bounded lanes use the existing Master volume")
	if sound.streams.has("button"):
		var tone=sound.streams.button;var samples=tone.data.size()/2;var crossings=0;var peak=0;var first_peak=0;var last_peak=0
		for index in range(samples):
			var value=absi(tone.data.decode_s16(index*2));peak=maxi(peak,value)
			if index<sound.T.SFX_BUTTON_SAMPLE_RATE*sound.T.SFX_BUTTON_ATTACK_SECONDS/4:first_peak=maxi(first_peak,value)
			if index>=samples-sound.T.SFX_BUTTON_SAMPLE_RATE*sound.T.SFX_BUTTON_RELEASE_SECONDS/4:last_peak=maxi(last_peak,value)
		for index in range(1,samples):
			if tone.data.decode_s16((index-1)*2)<0 and tone.data.decode_s16(index*2)>=0:crossings+=1
		_check(tone is AudioStreamWAV and tone.format==AudioStreamWAV.FORMAT_16_BITS and not tone.stereo and tone.mix_rate==sound.T.SFX_BUTTON_SAMPLE_RATE and samples==roundi(sound.T.SFX_BUTTON_SAMPLE_RATE*sound.T.SFX_BUTTON_SECONDS) and tone.data.decode_s16(0)==0 and tone.data.decode_s16((samples-1)*2)==0 and crossings==floori(sound.T.SFX_BUTTON_FREQUENCY*sound.T.SFX_BUTTON_SECONDS) and first_peak<peak/2 and last_peak<peak/2,"generated mono sine has configured length and frequency, zero endpoints and reusable PCM")
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
