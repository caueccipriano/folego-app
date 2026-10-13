/** Category assignments only. Existing comments and monetary values are never written. */
function folegoCategoriesInstall() {
  const p=PropertiesService.getScriptProperties();
  const ss=SpreadsheetApp.openById(FOLEGO_SYNC_CONFIG.spreadsheetId);
  const state=_folegoSyncApi_({action:'classification_state'});
  if (!Array.isArray(state.categories)||!Array.isArray(state.rows)) throw new Error('Protocolo de categorias indisponível');
  _folegoCategoriesPrepare_(ss,state.categories);
  p.setProperty('FOLEGO_CATEGORIES_INSTALLED','true');
  folegoCategoriesRun();
  console.log('Categorias instaladas no ciclo existente de 5 minutos; comentários preservados.');
}
function folegoCategoriesRun() {
  const lock=LockService.getScriptLock();if(!lock.tryLock(5000))return;
  try{_folegoCategoriesCycle_(SpreadsheetApp.openById(FOLEGO_SYNC_CONFIG.spreadsheetId));}finally{lock.releaseLock();}
}
function _folegoCategoriesPrepare_(ss,categories) {
  const sh=ss.getSheetByName('Lancamentos');
  if(sh.getMaxColumns()<36)sh.insertColumnsAfter(sh.getMaxColumns(),36-sh.getMaxColumns());
  sh.getRange('AA4:AJ4').setValues([['Evento ID','Versão base','Categoria ID base','Categoria H base','Grupo base','Subcategoria base','Caminho base','Escolha base','Escolha categoria Fôlego','Estado da categoria']]);
  sh.hideColumns(27,8);sh.showColumns(35,2);
  sh.setColumnWidth(35,300);sh.setColumnWidth(36,250);
  sh.getRange('AI4:AJ4').setBackground('#e7e8de').setFontWeight('bold').setWrap(true);
  sh.getRange(5,35,sh.getMaxRows()-4,2).setFontFamily('Roboto').setFontSize(10).setWrap(true);
  sh.getRange('AI4').setNote('Escolha o caminho completo. H continua compatível com os relatórios. Em conflito, a edição local é preservada; a versão do app fica na nota desta célula. Para descartar a edição local, apague AI e aguarde o ciclo.');
  let cat=ss.getSheetByName('Catálogo Fôlego');if(!cat)cat=ss.insertSheet('Catálogo Fôlego');
  if(cat.getMaxColumns()<12)cat.insertColumnsAfter(cat.getMaxColumns(),12-cat.getMaxColumns());
  const sorted=categories.slice().sort((a,b)=>a.kind.localeCompare(b.kind)||a.path.localeCompare(b.path)||a.id.localeCompare(b.id));
  const selectable=sorted.filter(c=>c.active&&c.is_selectable&&c.category_role==='economic');
  const rows=sorted.map(c=>{const p=c.path.split(' > ');return[c.id,c.system_key||'',p[0],p.slice(1).join(' > '),c.path,c.kind,c.is_selectable?'Sim':'Não',c.sheet_category,c.active?'Sim':'Não',c.category_role];});
  if(cat.getMaxRows()<rows.length+3)cat.insertRowsAfter(cat.getMaxRows(),rows.length+3-cat.getMaxRows());
  cat.getRange(4,1,Math.max(1,cat.getLastRow()-3),12).clearContent();
  cat.getRange(4,1,rows.length,10).setValues(rows);
  cat.getRange('K3:L3').setValues([['Escolhas atuais','Categorias H atuais']]);
  const paths=[...new Set(selectable.map(c=>c.path))];
  const legacy=[...new Set(selectable.map(c=>c.sheet_category).filter(x=>!['Compras online','Mercado Livre','Giovani','Pagamento de boleto'].includes(x)).concat(['A classificar','Pagamento de cartão','Transferências','Investimentos','Cofrinho','Estorno','Reembolso','Saque','Depósito']))].sort();
  cat.getRange(4,11,paths.length,1).setValues(paths.map(x=>[x]));cat.getRange(4,12,legacy.length,1).setValues(legacy.map(x=>[x]));
  cat.getRange('A2').setValue('Catálogo automático · '+new Date().toISOString()+'. Edite categorias dos lançamentos em Lancamentos; IDs e caminhos históricos preservados.');
  sh.getRange(5,35,sh.getMaxRows()-4,1).setDataValidation(SpreadsheetApp.newDataValidation().requireValueInRange(cat.getRange(4,11,paths.length,1),true).setAllowInvalid(true).build());
  sh.getRange(5,8,sh.getMaxRows()-4,1).setDataValidation(SpreadsheetApp.newDataValidation().requireValueInRange(cat.getRange(4,12,legacy.length,1),true).setAllowInvalid(true).build());
  sh.getRange('H4').setNote('Categoria compatível com os relatórios. Edição sincroniza se houver correspondência única; use Escolha categoria Fôlego para categorias ambíguas. Histórico é preservado.');
}
function _folegoCategoriesLocal_(sh,row){const r=sh.getRange(row,8,1,28).getValues()[0];return[r[0],r[16],r[17],r[18],r[27]].map(x=>String(x||''));}
function _folegoCategoriesPresentation_(remote,cats){const c=cats.find(c=>c.id===remote.category_id);const path=c?c.path:'A classificar';const parts=path.split(' > ');return[c?c.sheet_category:'A classificar',parts[0],parts.slice(1).join(' > '),path,path];}
function _folegoCategoriesIntent_(local,base,kind,cats){
  const changed=local.map((v,i)=>v!==base[i]);
  const allowed=cats.filter(c=>c.active&&c.is_selectable&&c.category_role==='economic'&&c.kind===kind);
  let found;
  if(changed[4])found=allowed.filter(c=>c.path===local[4]);
  else if(changed[1]||changed[2]||changed[3]){const path=changed[3]?local[3]:[local[1],local[2]].filter(Boolean).join(' > ');found=allowed.filter(c=>c.path===path);}
  else found=allowed.filter(c=>c.sheet_category===local[0]);
  if(found.length!==1)return{error:found.length?'Categoria ambígua: use o caminho completo':'Categoria inválida ou não selecionável'};
  const c=found[0];
  if(changed[4]&&changed[0]&&local[0]!==c.sheet_category)return{error:'Edições incompatíveis em H e na escolha completa'};
  return{category:c};
}
function _folegoCategoriesCycle_(ss,api){
  api=api||_folegoSyncApi_;
  const state=api({action:'classification_state'});const cats=state.categories||[];
  _folegoCategoriesPrepare_(ss,cats);
  const sh=ss.getSheetByName('Lancamentos');const count=Math.max(0,sh.getLastRow()-4);if(!count)return;
  const values=sh.getRange(5,2,count,35).getValues();
  const ids=values.map(r=>String(r[0]||'').trim());
  const duplicateIds=new Set(ids.filter((id,i)=>id&&ids.indexOf(id)!==i));
  const remoteMap=new Map();const duplicateRemote=new Set();
  (state.rows||[]).forEach(e=>{if(remoteMap.has(e.sheet_id))duplicateRemote.add(e.sheet_id);remoteMap.set(e.sheet_id,e);});
  let synced=0,conflicts=0,pushed=0;
  for(let i=0;i<count;i++){
    const row=i+5,id=ids[i];if(!id)continue;
    const remote=remoteMap.get(id);if(!remote){if(values[i][25])sh.getRange(row,36).setValue('CONFLITO: evento ausente ou não confirmado');continue;}
    if(duplicateIds.has(id)||duplicateRemote.has(id)){sh.getRange(row,36).setValue('CONFLITO: ID duplicado');conflicts++;continue;}
    const data=values[i],local=[data[6],data[22],data[23],data[24],data[33]].map(x=>String(x||'')),tech=data.slice(25,33).map(x=>String(x||''));
    const presentation=_folegoCategoriesPresentation_(remote,cats);
    const report=(message)=>{sh.getRange(row,36).setValue(message);sh.getRange(row,35).setNote('Fôlego: '+presentation[3]+' · versão '+remote.updated_at+'. Edição local preservada. Apague AI para aceitar a versão do app.');conflicts++;};
    if(!tech[0]){
      if(!_folegoCategoriesSame_(local,_folegoCategoriesLocal_(sh,row)))continue;
      // Establish a base without interpreting or reclassifying historical purchases.
      sh.getRange(row,27,1,8).setValues([[remote.id,remote.updated_at,remote.category_id||'',...local]]);
      if(local[0]!==presentation[0]||(local[3]&&local[3]!==presentation[3]))report('CONFLITO BASE: conferir categorias');
      else sh.getRange(row,36).setValue('Sincronizado');
      continue;
    }
    if(tech[0]!==remote.id){report('CONFLITO: vínculo de evento alterado');continue;}
    const base=tech.slice(3),changed=!_folegoCategoriesSame_(local,base);
    const previousStatus=String(values[i][34]||'');
    if(previousStatus.startsWith('CONFLITO BASE')&&!changed){const c=cats.find(c=>c.id===remote.category_id);if(local[3]===presentation[3]&&c&&local[0]===c.name&&_folegoCategoriesSame_(local,_folegoCategoriesLocal_(sh,row))){_folegoCategoriesAccept_(sh,row,remote,presentation);synced++;continue;}if(!local[4]&&_folegoCategoriesSame_(local,_folegoCategoriesLocal_(sh,row))){const draft=local[3]||local[0];sh.getRange(row,35).setValue(draft);sh.getRange(row,34).setValue(draft);}conflicts++;continue;}
    const kind=['income','benefit_credit','reimbursement'].includes(remote.event_type)?'income':'expense';
    if(changed){
      // Clearing an existing selection explicitly discards the draft; no remote write.
      if(local[4]===''&&base[4]!==''){if(_folegoCategoriesSame_(local,_folegoCategoriesLocal_(sh,row))){_folegoCategoriesAccept_(sh,row,remote,presentation);synced++;}continue;}
      const intent=_folegoCategoriesIntent_(local,base,kind,cats);
      if(intent.error){report('PENDENTE: '+intent.error);continue;}
      const result=(api({action:'classification_push',rows:[{event_id:remote.id,category_id:intent.category.id,expected_category_id:tech[2]||null,expected_updated_at:tech[1]}]}).results||[])[0]||{};
      if(!['updated','unchanged'].includes(result.status)){report('CONFLITO/PENDENTE: '+String(result.status||'sem resposta'));continue;}
      if(!_folegoCategoriesSame_(local,_folegoCategoriesLocal_(sh,row))){sh.getRange(row,36).setValue('PENDENTE: nova edição durante ciclo');continue;}
      const applied={...remote,category_id:result.category_id,updated_at:result.updated_at};
      _folegoCategoriesAccept_(sh,row,applied,_folegoCategoriesPresentation_(applied,cats));synced++;if(result.status==='updated')pushed++;
    }else{
      if(!_folegoCategoriesSame_(local,_folegoCategoriesLocal_(sh,row)))continue;
      if(remote.updated_at!==tech[1]||local[4]!==presentation[4])_folegoCategoriesAccept_(sh,row,remote,presentation);
      synced++;
    }
  }
  PropertiesService.getScriptProperties().setProperty('FOLEGO_CATEGORIES_LAST_RUN',new Date().toISOString());
  console.log(JSON.stringify({categories:cats.length,synced,conflicts,pushed}));
}
function _folegoCategoriesSame_(a,b){return JSON.stringify(a)===JSON.stringify(b);}
function _folegoCategoriesAccept_(sh,row,remote,p){
  const before=sh.getRange(row,2,1,33).getValues()[0];
  const oldBusiness=before.slice(0,19);oldBusiness[6]=before[28];
  const onlyCategoryChanged=String(before[21]||'')===_folegoSyncHash_(oldBusiness);
  sh.getRange(row,8).setValue(p[0]);sh.getRange(row,24,1,3).setValues([[p[1],p[2],p[3]]]);sh.getRange(row,35).setValue(p[4]).clearNote();
  sh.getRange(row,27,1,8).setValues([[remote.id,remote.updated_at,remote.category_id||'',...p]]);
  sh.getRange(row,36).setValue('Sincronizado');
  // A category-only edit must not echo into the legacy description/amount protocol.
  const business=sh.getRange(row,2,1,19).getValues()[0];
  if(onlyCategoryChanged)sh.getRange(row,21,1,3).setValues([['CATEGORY SYNC',new Date(),_folegoSyncHash_(business)]]);
}
function _folegoCategoriesHasPending_(sh,row){
  if(sh.getMaxColumns()<36)return false;
  const tech=sh.getRange(row,27,1,8).getValues()[0].map(x=>String(x||''));
  return !!tech[0]&&(!_folegoCategoriesSame_(_folegoCategoriesLocal_(sh,row),tech.slice(3))||/CONFLITO|PENDENTE/.test(String(sh.getRange(row,36).getValue()||'')));
}
function folegoCategoriesSelfTest(){
  const cats=[{id:'a',path:'Casa > Água',sheet_category:'Água',kind:'expense',active:true,is_selectable:true,category_role:'economic'}, {id:'b',path:'Casa > Internet',sheet_category:'Internet/Telefone',kind:'expense',active:true,is_selectable:true,category_role:'economic'}, {id:'c',path:'Casa > Celular',sheet_category:'Internet/Telefone',kind:'expense',active:true,is_selectable:true,category_role:'economic'}, {id:'d',path:'Compras > Marketplace',sheet_category:'Mercado Livre',kind:'expense',active:true,is_selectable:false,category_role:'economic'}];
  const base=['Água','Casa','Água','Casa > Água','Casa > Água'];
  const check=(ok,label)=>{if(!ok)throw new Error('FAIL: '+label);console.log('PASS: '+label);};
  check(_folegoCategoriesIntent_(['Água','Casa','Água','Casa > Água','Casa > Internet'],base,'expense',cats).category.id==='b','caminho identifica ID estável');
  check(!!_folegoCategoriesIntent_(['Internet/Telefone',...base.slice(1)],base,'expense',cats).error,'rótulo ambíguo não presumido');
  check(!!_folegoCategoriesIntent_([...base.slice(0,4),'Compras > Marketplace'],base,'expense',cats).error,'canal obsoleto rejeitado');
  check(!!_folegoCategoriesIntent_([...base.slice(0,4),'Casa > Internet'],base,'income',cats).error,'tipo incompatível rejeitado');
  check(_folegoCategoriesSame_(base,base.slice()),'comparação da edição local');
  console.log('Testes isolados concluídos; nenhum lançamento fictício criado.');
}
