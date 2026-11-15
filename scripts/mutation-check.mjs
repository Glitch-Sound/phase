import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
const file='game/phase_math.gd';
const original=fs.readFileSync(file,'utf8');
const mutations=[
 ['GEAR direction','var gear=-1.5*float(u.gear[3])','var gear=1.5*float(u.gear[3])'],
 ['Resistance division','power/=1.0+resistance*sync(target,2).factor','power*=1.0+resistance*sync(target,2).factor'],
 ['Singularity tolerance','absf(wrapf(s.x-c.x,-180,180))>0.0000001','absf(wrapf(s.x-c.x,-180,180))>3.0'],
 ['Pair interference','var wave=clampf(0.7*triple+0.2*(pairs[0]+pairs[1]+pairs[2])/3.0+0.1*maxf(pairs[0],maxf(pairs[1],pairs[2])),0,1)','var wave=triple']
];
const results=[];
try {
 for(const [name,from,to] of mutations) {
  if(!original.includes(from)) throw Error('Missing mutation anchor: '+name);
  fs.writeFileSync(file,original.replace(from,to));
  const run=spawnSync('godot',['--headless','--path','.','--script','tests/run.gd','--log-file',path.resolve('artifacts/runtime/mutant.log')],{encoding:'utf8',timeout:20000});
  const output=(run.stdout||'')+(run.stderr||'');
  const caught=/FAIL:/.test(output);
  results.push({name,caught,exit:run.status,failures:output.split('\n').filter(x=>x.includes('FAIL:'))});
  console.log(name+': '+(caught?'DETECTED':'MISSED'));
 }
} finally {fs.writeFileSync(file,original);}
fs.writeFileSync('artifacts/mutation-results.json',JSON.stringify(results,null,2)+'\n');
if(results.some(x=>!x.caught)) process.exit(1);
