import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import crypto from 'node:crypto';

const sender = fs.readFileSync('integrations/apps-script/folego-row-ack-addon.gs','utf8');
const runtime = fs.readFileSync('integrations/apps-script/FolegoSync.gs','utf8');

function environment({mutateBeforeSend=false,wrongIdentity=false}={}) {
  const id='event:aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const business=Array(20).fill('');
  business[0]=id;business[3]='Synthetic only';business[4]=20;
  business[5]='Despesa'; business[6]='Teste';business[7]='Conta';
  business[8]='Confirmado';business[9]='Fôlego App';business[19]='PULLED';
  const headers=Array(36).fill('');
  headers[1]='ID';headers[4]='Descrição';headers[5]='Valor';
  headers[6]='Tipo';headers[7]='Categoria';
  headers[8]='Conta / cartão';headers[9]='Status';
  let flushed=0;
  let sent=0;
  const values=()=>[...business];
  const fullRow=()=>{const row=Array(36).fill('');business.forEach((v,i)=>row[i+1]=String(v));return row;};
  const sheet={
    getRange(r,c,h,w){
      if(r===4&&c===1&&h===1&&w===36)return{getDisplayValues:()=>[headers]};
      if(r===5&&c===1&&h===1&&w===36)return{getDisplayValues:()=>[fullRow()]};
      if(r===5&&c===2&&h===1&&w===20)return{getValues:()=>{
        if(mutateBeforeSend)business[6]='Changed by user';
        if(wrongIdentity)business[0]='event:bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
        return [values()];
      }};
      throw Error('unexpected range '+[r,c,h,w]);
    },
  };
  const script={
    SpreadsheetApp:{flush:()=>{flushed++;}},
    Utilities:{
      DigestAlgorithm:{SHA_256:'sha256'},Charset:{UTF_8:'utf8'},
      computeDigest(a,v){assert.equal(a,'sha256');return[...crypto.createHash('sha256').update(v).digest()];}
    },
    UrlFetchApp:{
      fetch(_,o){
        sent++;
        const payload=JSON.parse(o.payload);
        assert.equal(payload.action,'pull_ack');
        assert.equal(payload.rows.length,1);
        assert.deepEqual(Object.keys(payload.rows[0]).sort(),['id','sha256','updated_at'].sort());
        return {getResponseCode:()=>200,getContentText:()=>JSON.stringify({ok:true,results:[{id,status:'applied'}]})};
      },
    },
  };
  vm.runInNewContext(runtime+'\n'+sender,script);
  const fingerprint=script._folegoSyncHash_(values());
  const call=()=>script.folegoEnviarAckAposGravacao_({
    sheet,endpoint:'https://example.test/functions/v1/sheet-row-ack',
    spreadsheetId:'synthetic',token:'placeholder',
    applied:[{rowNumber:5,id,updated_at:'2026-10-14T10:00:00.000Z',
      expected_bu_sha256:fingerprint}],
  });
  return {call,get sent(){return sent},get flushed(){return flushed}};
}

test('ACK is sent only after second post-flush B:U fingerprint matches',()=>{
  const e=environment();const outcome=e.call();
  assert.equal(e.sent,1);assert.ok(e.flushed>0);
  assert.equal(outcome[0].status,'applied');
});
test('edit between first and second readback prevents outbound receipt',()=>{
  const e=environment({mutateBeforeSend:true});
  assert.equal(e.call().length,0);
  assert.equal(e.sent,0);
});
test('identity changed at final readback cannot be acknowledged',()=>{
  const e=environment({wrongIdentity:true});
  assert.equal(e.call().length,0);
  assert.equal(e.sent,0);
});
