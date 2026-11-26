// SPDX-License-Identifier: MIT
// Copyright (c) 2026 PHASE contributors
// Scope: assets/licenses/NOTICE.md; license: assets/licenses/MIT.txt
import fs from 'node:fs';
import path from 'node:path';
let errors=[];
for(const dir of ['game','ui']) {
 for(const file of fs.readdirSync(dir).filter(x=>x.endsWith('.gd'))) {
  const name=path.join(dir,file), lines=fs.readFileSync(name,'utf8').split('\n');
  for(let i=0;i<lines.length;i++) {
   const match=lines[i].match(/^(?:static )?func ([a-zA-Z]\w*)\((.*)\)\s*->\s*(\w+):/);
   if(!match) continue;
   let j=i-1,docs=[];while(j>=0&&lines[j].startsWith('##')) docs.unshift(lines[j--]);
   if(!docs.length) {errors.push(name+':'+(i+1)+' missing API documentation');continue;}
   const comment=docs.join('\n');
   for(const arg of match[2].split(',').filter(Boolean)) {
    const argName=arg.trim().split(':')[0];
    if(!comment.includes(argName)) errors.push(name+':'+(i+1)+' undocumented argument '+argName);
   }
   if(match[3]!=='void'&&!comment.includes('戻り値')) errors.push(name+':'+(i+1)+' undocumented return');
  }
  if(/REQ-\d/.test(lines.join('\n'))) errors.push(name+' contains scenario IDs outside tests');
 }
}
if(errors.length) {console.error(errors.join('\n'));process.exit(1);}
console.log('GDScript public documentation: OK');
