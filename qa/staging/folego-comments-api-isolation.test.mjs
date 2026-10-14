import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { stripTypeScriptTypes } from 'node:module';

// Execute the notes_push branch taken directly from the deployed sheet-sync
// Edge source, never the live endpoint. All 2 users/spaces are synthetic.
const original = fs.readFileSync('supabase/functions/sheet-sync/index.ts', 'utf8');
const from = original.indexOf('if (action === "notes_push") {');
const to = original.indexOf('if (action === "notes_pull") {', from);
assert.ok(from > 0 && to > from, 'notes_push branch must be found');
const realBranch = original.slice(from,to);
const runner = stripTypeScriptTypes(
  'async function runNotesPush(body, supabase, spaceId) { ' +
  'const action = "notes_push";' +
  'const json = (status,payload)=>({code:status,...payload});\n' +
  realBranch + '\n}; globalThis.notesPushForTest=runNotesPush;',
  {mode:'strip'},
);
const context={Set,Number,Math,Array,JSON,String,Error,Object,Date};
vm.runInNewContext(runner,context);
const execute=context.notesPushForTest;
const SPACE_A='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const SPACE_B='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const TARGET='aaaaaaaa-2222-4222-8222-aaaaaaaaaaaa';

function fixture() {
  const store=new Map();const writes=[];let counter=0;
  const key=(spaceId,targetType,targetId)=>[spaceId,targetType,targetId].join(':');
  const createClient=()=>({
    from(table) {
      assert.equal(table,'financial_notes');
      const where=[];
      const query={
        select(){return this;},
        eq(name,value){where.push([name,value]);return this;},
        async maybeSingle(){
          const record=[...store.values()].find(r=>where.every(([n,v])=>r[n]===v));
          return {data:record?{...record}:null,error:null};
        },
        insert(record){
          return { select(){
            return { async single(){
              const id=key(record.space_id,record.target_type,record.target_id);
              if(store.has(id))return {data:null,error:{code:'23505'}};
              counter++;
              const saved={...record,id:'note-'+counter,revision:1,
                updated_at:'2026-10-14T12:00:00.000Z'};
              store.set(id,saved);writes.push({kind:'insert',id});
              return {data:{revision:saved.revision,updated_at:saved.updated_at},error:null};
            }};
          }};
        },
        update(patch) {
          const filters=[];
          return {
            eq(name,value){filters.push([name,value]);return this;},
            select(){return this;},
            async maybeSingle(){
              const found=[...store.values()].find(r=>filters.every(([n,v])=>r[n]===v));
              if(!found)return {data:null,error:null};
              Object.assign(found,patch);
              found.revision++;
              writes.push({kind:'update',id:found.id});
              return {data:{revision:found.revision,updated_at:'2026-10-14T12:05:00.000Z'},error:null};
            },
          };
        },
      };
      return query;
    },
  });
  const push=(space,rows)=>execute({rows},createClient(),space);
  const get=(space=SPACE_A)=>store.get(key(space,'event',TARGET));
  return {push,get,writes,store};
}
const item=(content,revision=0,targetId=TARGET)=>({
  target_type:'event',target_id:targetId,content,revision,
});

test('first sheet note is inserted; repeated identical note stays unchanged',async()=>{
  const f=fixture();
  const created=await f.push(SPACE_A,[item('Synthetic note A')]);
  assert.equal(created.results[0].status,'inserted');
  const duplicate=await f.push(SPACE_A,[item('Synthetic note A',0)]);
  assert.equal(duplicate.results[0].status,'unchanged');
  assert.equal(f.get().content,'Synthetic note A');
  assert.equal(f.writes.length,1);
});

test('stale revision cannot overwrite a concurrently edited note',async()=>{
  const f=fixture();await f.push(SPACE_A,[item('Original')]);
  const applied=await f.push(SPACE_A,[item('Newer in sheet',1)]);
  assert.equal(applied.results[0].status,'updated');
  const stale=await f.push(SPACE_A,[item('Stale local text',1)]);
  assert.equal(stale.results[0].status,'conflict_revision');
  assert.equal(f.get().content,'Newer in sheet');
  assert.equal(f.writes.length,2);
});

test('two isolated spaces cannot see or change each other via notes_push',async()=>{
  const f=fixture();
  await f.push(SPACE_A,[item('Private A')]);
  const other=await f.push(SPACE_B,[item('Private B')]);
  assert.equal(other.results[0].status,'inserted');
  assert.equal(f.get(SPACE_A).content,'Private A');
  assert.equal(f.get(SPACE_B).content,'Private B');
  assert.equal(f.writes.length,2);
});

test('malformed note and inappropriate target UUID are ignored',async()=>{
  const f=fixture();
  const response=await f.push(SPACE_A,[
    item('unvalidated',0,'no'),
    item('x'.repeat(4001)),
    item('Not an existing revision',2),
  ]);
  assert.equal(response.results[0].status,'invalid_note');
  assert.equal(response.results[1].status,'invalid_note');
  assert.equal(response.results[2].status,'conflict_missing');
  assert.equal(f.writes.length,0);
});

test('simultaneous push retries cannot cause two successful writes for one revision',async()=>{
  const f=fixture();await f.push(SPACE_A,[item('Original')]);
  const [a,b]=await Promise.all([
    f.push(SPACE_A,[item('Edit one',1)]),
    f.push(SPACE_A,[item('Edit two',1)]),
  ]);
  const statuses=[a.results[0].status,b.results[0].status].sort();
  assert.deepEqual(statuses,['conflict_revision','updated']);
  assert.equal(f.get().revision,2);
  assert.equal(f.writes.length,2);
});
