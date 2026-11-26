// REQ-064-S01: 実際のWeb配布物を、ソースとは独立したPCKの索引から検査する。
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
const folder=process.argv[2]??'artifacts/runtime/web';
const pack=fs.readFileSync(path.join(folder,'index.pck'));
assert.equal(pack.toString('ascii',0,4),'GDPC');
assert.equal(pack.readUInt32LE(4),4,'known PCK directory layout');
const base=Number(pack.readBigUInt64LE(24));
let cursor=Number(pack.readBigUInt64LE(32));
const count=pack.readUInt32LE(cursor);cursor+=4;
const files=new Map();
for(let i=0;i<count;i++){
  const length=pack.readUInt32LE(cursor);cursor+=4;
  const name=pack.toString('utf8',cursor,cursor+length).replace(/\0+$/,'');cursor+=length;
  const offset=Number(pack.readBigUInt64LE(cursor)),size=Number(pack.readBigUInt64LE(cursor+8));cursor+=36;
  assert.ok(!files.has(name),'unique archive path');
  files.set(name,pack.subarray(base+offset,base+offset+size));
}
const documents=['assets/godot/LICENSE.txt','assets/godot/COPYRIGHT.txt','assets/godot/NOTICE.md','assets/lucide/LICENSE','assets/lucide/NOTICE.md','assets/fonts/OFL.txt','assets/fonts/NOTICE.md','assets/licenses/NOTICE.md','assets/licenses/MIT.txt'];
for(const file of documents){
  assert.ok(files.has(file),'packed original: '+file);
  assert.deepEqual(files.get(file),fs.readFileSync(file),'unchanged complete original: '+file);
}
const sounds=[...files.keys()].filter(x=>x.startsWith('assets/sfx/')&&x.endsWith('.ogg.import')).sort();
assert.deepEqual(sounds,['attack','defeated','heal','ring_rotate1','ring_rotate2'].map(x=>'assets/sfx/'+x+'.ogg.import').sort());
assert.ok([...files.keys()].every(x=>!x.includes('select.ogg')&&!x.includes('ring_rotate.ogg')));
for(const name of ['attack','defeated','heal','ring_rotate1','ring_rotate2'])assert.equal([...files.keys()].filter(x=>x.startsWith('.godot/imported/'+name+'.ogg-')&&x.endsWith('.oggvorbisstr')).length,1);
const html=fs.readFileSync(path.join(folder,'index.html'),'utf8');
assert.ok(html.includes('phase-font-license')&&html.includes('SIL OPEN FONT LICENSE'));
const originals=['3cb4495c0b98dfbe4b663cbf2b6836473572339beb66d902367893162a70be0e','ad3c35ad0facf487c618204bd98db543034fc95224eadc7f08c7a9ff38d5b3b5','01d4f63e525941e06ce74f5187dad030d20a8d52a07ce365ae4e94af97a3b1f5'];
for(const name of ['index.png','index.icon.png','index.apple-touch-icon.png']){
  const image=fs.readFileSync(path.join(folder,name));
  assert.ok(!originals.includes(crypto.createHash('sha256').update(image).digest('hex')),'no default Godot image: '+name);
}
assert.deepEqual(fs.readFileSync(path.join(folder,'index.png')),fs.readFileSync('assets/branding/phase-lockup.png'),'splash is the approved PHASE lockup');
assert.deepEqual(fs.readFileSync(path.join(folder,'index.icon.png')),fs.readFileSync('assets/branding/phase-mark.png'),'favicon is the approved rings-only mark');
assert.ok(html.includes('href="index.icon.png"')&&html.includes('href="index.apple-touch-icon.png"'));
assert.ok(html.includes('<img src="index.png" alt="PHASE" width="676" height="184">'),'loading screen uses the configured lockup with preserved aspect');
console.log('WEB LICENSES: PASS / '+documents.length+' complete originals / '+sounds.length+' sounds / PHASE images');

// REQ-065-S01: ソースの許諾範囲をPCK検査と分けて確認する。
const scope=fs.readFileSync('assets/licenses/NOTICE.md','utf8');
const expectedUtilities=['ui/panel_probe.gd','scripts/lint.mjs'];
const declaredUtilities=[...scope.matchAll(/^- `([^`]+)`$/gm)].map(x=>x[1]);
assert.deepEqual(declaredUtilities,expectedUtilities,'MIT permission covers only the two listed original utilities');
assert.ok(scope.includes('他のPHASE自作ファイルの権利は留保する'));
assert.ok(!fs.existsSync('LICENSE'),'no project-wide MIT license');
const readme=fs.readFileSync('README.md','utf8');
for(const file of expectedUtilities){
  const source=fs.readFileSync(file,'utf8');
  assert.ok(source.includes('SPDX-License-Identifier: MIT')&&source.includes('Copyright (c) 2026 PHASE contributors'));
  assert.ok(readme.includes('`'+file+'`'),'README identifies the exact licensed source path');
}
const terms=fs.readFileSync('assets/godot/LICENSE.txt','utf8').split('Permission is hereby granted')[1];
assert.equal(fs.readFileSync('assets/licenses/MIT.txt','utf8'),'MIT License\n\nCopyright (c) 2026 PHASE contributors\n\nPermission is hereby granted'+terms,'standard MIT terms are complete');
console.log('LICENSE SCOPE: PASS / exactly two original utilities');
