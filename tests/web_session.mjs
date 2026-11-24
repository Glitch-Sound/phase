// REQ-062-S02: エンジン初期化前の永続化禁止を起動シェル境界で確かめる。
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
assert.ok(fs.existsSync('web/session.html'), 'session-only export shell exists');
const html=fs.readFileSync('web/session.html','utf8');
const code=html.match(/<script id="phase-start">([\s\S]*?)<\/script>/)?.[1];
assert.ok(code, 'startup script exists');
let config,started=0;
const status={textContent:'',hidden:false};
const forbidden=new Proxy({}, {get(){throw Error('persistent browser storage must not be used');}});
class Engine {
  constructor(value){config=value;}
  async startGame(){started++;}
}
const substituted=code.replace('$GODOT_CONFIG', JSON.stringify({persistentPaths:['/userfs'],serviceWorker:'old-worker.js',executable:'index'}));
vm.runInNewContext(substituted,{Engine,document:{getElementById:()=>status},console,localStorage:forbidden,indexedDB:forbidden,navigator:{serviceWorker:forbidden}});
await new Promise(resolve=>setImmediate(resolve));
assert.equal(started,1);
assert.equal(JSON.stringify(config.persistentPaths),'[]');
assert.equal(config.serviceWorker,'');
const preset=fs.readFileSync('export_presets.cfg','utf8');
assert.match(preset,/platform="Web"/);
// REQ-062-S04: the deliverable preset, rather than an editor toggle, enables demo policy.
assert.match(preset,/name="Web Demo"/);
assert.match(preset,/custom_features="demo"/);
assert.match(preset,/html\/custom_html_shell="res:\/\/web\/session.html"/);
assert.match(preset,/progressive_web_app\/enabled=false/);
assert.match(preset,/exclude_filter="[^"]*artifacts\/\*/);
console.log('WEB SESSION SHELL: PASS');
