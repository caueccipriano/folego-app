/**
 * FÔLEGO — Mercado Pago E-mail Intake V3.5.3 (incremental add-on)
 * Install alongside existing Código.gs V3.5.2. Never replace Código.gs.
 * No new financial transactions are created by this module.
 * Gmail messages are read, parsed, reconciled against the existing ledger,
 * and recorded in Entrada Automacao as Processado (linked) or RevisaoEmail (isolated review).
 * Setup: authorize Gmail REST (gmail.readonly) and opt-in time trigger ONLY after dry-run review.
 */
var FMP_EMAIL_V353 = Object.freeze({
  QUERY: 'newer_than:14d {subject:"Seu Pix foi enviado" subject:"Pix recebido" subject:"Seu Pix foi recebido" subject:"Seu dinheiro já está disponível"}',
  MAX_PAGES: 4,
  PAGE_SIZE: 25,
  MAX_MESSAGES: 100,
  SHEET_STATUS_LINKED: 'Processado',
  SHEET_STATUS_REVIEW: 'RevisaoEmail'
});

function fmpEmlNormalizeV353_(str) {
  return String(str || '').replace(/\s+/g, ' ').trim();
}

function fmpEmlAllowedSenderV353_(sender) {
  // Sender whitelist reduces noise; it is NOT financial proof/authentication.
  var emailMatch = String(sender || '').match(/<?([a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+)>?/);
  var addr = emailMatch ? emailMatch[1].toLowerCase() : '';
  return /@(?:mercadopago\.com(?:\.br)?|mercadolivre\.com(?:\.br)?)$/.test(addr);
}

function fmpEmlAmountV353_(raw) {
  var normalized = fmpEmlNormalizeV353_(raw);
  if (!/^\d{1,3}(?:\.\d{3})*(?:,\d{1,2})?$|^\d+(?:,\d{1,2})?$/.test(normalized)) return null;
  var value = Number(normalized.replace(/\./g, '').replace(',', '.'));
  return isFinite(value) && value > 0 ? Math.round(value * 100) / 100 : null;
}

function fmpEmlDateV353_(text, fallback) {
  var norm = fmpEmlNormalizeV353_(text).toLowerCase();
  var months = {janeiro:1,fevereiro:2,marco:3,'março':3,abril:4,maio:5,junho:6,julho:7,agosto:8,setembro:9,outubro:10,novembro:11,dezembro:12};
  var match = norm.match(/(\d{1,2})\s+de\s+(janeiro|fevereiro|março|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro)\s+de\s+(\d{4}),?\s+[àa]s\s+(\d{1,2}):(\d{2})(?::(\d{2}))?/);
  if (match && typeof Utilities !== 'undefined' && Utilities.parseDate) {
    var localTime = [match[1].padStart(2,'0'),String(months[match[2]]).padStart(2,'0'),match[3]].join('/') + ' ' +
      [match[4].padStart(2,'0'),match[5],(match[6] || '00')].join(':');
    try {return Utilities.parseDate(localTime, CFG_V3.TZ, 'dd/MM/yyyy HH:mm:ss');} catch (_) {}
  }
  return fallback;
}

function fmpEmlParseV353_(subject, plainBody, receivedDate) {
  var clean = fmpEmlNormalizeV353_(plainBody);
  var head = clean.slice(0, 850);
  var subj = fmpEmlNormalizeV353_(subject);
  if (/(?:recusad[oa]|cancelad[oa]|não (?:foi|conclu|realiz)|nao (?:foi|conclu|realiz)|falhou|promoção|promocao)/i.test(subj + ' ' + head.slice(0,180))) return null;
  var outgoing = /(?:seu|o)\s+pix\s+de\s+R\$\s*([\d.,]+)\s+foi\s+enviado\b/i.exec(head);
  var incoming = /(?:seu|o)\s+pix\s+de\s+R\$\s*([\d.,]+)\s+foi\s+recebido\b/i.exec(head) ||
    /(?:voc[eê]\s+recebeu|pix\s+recebido)\s+(?:um\s+pix\s+de\s+)?R\$\s*([\d.,]+)/i.exec(head);
  if (!!incoming === !!outgoing) return null;
  var dir = outgoing ? 'out' : 'in';
  var value = fmpEmlAmountV353_((outgoing || incoming)[1]);
  if (value === null) return null;
  var date = fmpEmlDateV353_(head, receivedDate instanceof Date && isFinite(receivedDate.getTime()) ? receivedDate : new Date());
  var excerpt = head.replace(/https?:\/\/\S+/gi, '[link]').slice(0, 440);
  var recipient = '';
  if (dir === 'out') {
    var after = head.substring((outgoing.index || 0) + outgoing[0].length);
    // First meaningful line in plain email is recipient. Already whitespace-normalized.
    var match = after.match(/(?:\d{4},\s*[àa]s\s*\d{2}:\d{2}(?::\d{2})?\.?\s*)(.{3,100}?)\s+(?:CPF\/CNPJ:|Ita[uú]|Ag[eê]ncia:)/i);
    if (match) recipient = fmpEmlNormalizeV353_(match[1]).slice(0, 100);
  }
  return { direction: dir, amount: value, date: date,
    description: dir === 'out' ? 'Comprovante de PIX enviado — Mercado Pago' : 'Comprovante de PIX recebido — Mercado Pago',
    recipient: recipient, excerpt: excerpt, subject: subj,
    providerTransactionId: (clean.match(/\b(E\d{8}\d{4}[a-zA-Z0-9]{20,64})\b/) || clean.match(/(?:identificador|id da transa[cç][aã]o|c[oó]digo da opera[cç][aã]o)\s*:?\s*([a-zA-Z0-9-]{12,80})/i) || [,''])[1] };
}

/** No writes. Returned summary intentionally excludes senders, raw content, and identifiers. */
function folegoEmailMercadoPagoDryRunV353() {
  return folegoScanEmailMercadoPagoV353_(true);
}

/** Run manually only after dry-run and explicit Gmail OAuth approval. */
function folegoCapturarEmailsMercadoPagoV353() {
  return folegoScanEmailMercadoPagoV353_(false);
}

function folegoScanEmailMercadoPagoV353_(dryRun) {
  if (typeof CFG_V3 === 'undefined' || typeof appendInputLogV3_ !== 'function' ||
      typeof findInputByHashV3_ !== 'function' || typeof findMercadoPagoExistingV352_ !== 'function' ||
      typeof sha256V3_ !== 'function' || typeof updateInputLogV3_ !== 'function' || typeof _folegoSyncApi_ !== 'function') {
    throw new Error('Código.gs V3.5.2 obrigatório: integração abortada, sem gravações.');
  }
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) return {ok:false, reason:'Outra execução está em andamento'};
  try {
    var ss = SpreadsheetApp.openById(CFG_V3.SPREADSHEET_ID);
    var batch = fmpEmlRestListV353_();
    var threads = [{getMessages:function(){return batch.messages;}}];
    var summary = {ok:true,dryRun:!!dryRun,scanned:0,relevant:0,alreadySeen:0,linked:0,review:0,writes:0,truncated:batch.truncated};
    var count = 0;
    for (var t=0; t<threads.length && count<FMP_EMAIL_V353.MAX_MESSAGES; t++) {
      var messages = threads[t].getMessages();
      for (var j=0; j<messages.length && count<FMP_EMAIL_V353.MAX_MESSAGES; j++) {
        count++;
        summary.scanned++;
        var msg = messages[j];
        if (!fmpEmlAllowedSenderV353_(msg.getFrom()) || !fmpEmlAuthenticatedV353_(msg)) continue;
        var rec = fmpEmlParseV353_(msg.getSubject(), msg.getPlainBody(), msg.getDate());
        if (!rec) continue;
        summary.relevant++;
        // A stable Gmail-message fingerprint avoids repeated imports and does not expose mailbox IDs.
        var fp = sha256V3_('mercadopago-email:v353:'+(rec.providerTransactionId || msg.getId()));
        var priorInput = findInputByHashV3_(ss,fp,0);
        if (priorInput && (priorInput.status === FMP_EMAIL_V353.SHEET_STATUS_LINKED || priorInput.status === FMP_EMAIL_V353.SHEET_STATUS_REVIEW)) { summary.alreadySeen++; continue; }
        var mp = {isMercadoPagoEvent:true,mpDirection:rec.direction,value:rec.amount,eventDate:rec.date};
        var matched = findMercadoPagoExistingV352_(ss,mp) || {};
        // Existing matcher is only a hint. Backend reconciliation independently verifies
        // counterparties, dates, identifiers and cross-source duplicates.
        rec.linkedLaunchId = matched.ambiguous ? '' : (matched.launchId || '');
        // Server reconciliation is authoritative in BOTH modes. No ledger writes.
        var delivery = fmpEmlDeliverV353_(rec,fp,dryRun);
        var decision = delivery && delivery.receipts && delivery.receipts[0];
        if (!decision || decision.status === 'invalid') throw new Error('Comprovante não aceito pela triagem segura.');
        matched = {launchId:decision.linked_launch_id || '',ambiguous:decision.review_status !== 'linked'};
        var status = decision.review_status === 'linked' ? FMP_EMAIL_V353.SHEET_STATUS_LINKED : FMP_EMAIL_V353.SHEET_STATUS_REVIEW;
        if (status === FMP_EMAIL_V353.SHEET_STATUS_LINKED) summary.linked++; else summary.review++;
        if (dryRun) continue;
        var safe = {app:'MercadoPago', origem:'MercadoPagoEmail',
          titulo:rec.subject, corpo:rec.description+' | R$ '+rec.amount.toFixed(2).replace('.',',')+(rec.recipient?' | Destinatário: '+rec.recipient:''),
          datahora:Utilities.formatDate(rec.date,CFG_V3.TZ,'dd/MM/yyyy HH:mm:ss'),
          canal:'gmail', id_email_hash:fp};
        var now = new Date();
        var row = priorInput && priorInput.row ? priorInput.row : appendInputLogV3_(ss,safe,now,fp,CFG_V3.INPUT_STATUS.RECEIVED);
        if (status === FMP_EMAIL_V353.SHEET_STATUS_REVIEW) fmpEmlPrepareReviewValidationV353_(ss,row);
        updateInputLogV3_(ss,row,{eventDate:rec.date,status:status,
          parserResult:matched.ambiguous ? 'EMAIL MERCADO PAGO: revisão humana obrigatória ('+String(decision.review_reason || 'sem correspondência inequívoca')+'). Sem gravação financeira.' :
            matched.launchId ? 'EMAIL MERCADO PAGO: comprovante conciliado com lançamento existente '+matched.launchId+'; não lançar novamente.' :
            'EMAIL MERCADO PAGO: comprovante capturado, sem correspondência exata; validar destinatário, categoria e possíveis transferências. Sem gravação financeira.',
          launchId:matched.launchId || '',attempts:1,processedAt:now,error:''});
        summary.writes++;
      }
    }
    return summary;
  } catch (err) {
    // Do not expose response payloads, mailbox content or credentials in logs.
    throw new Error('Captura Gmail interrompida com segurança; verificar autorização e disponibilidade. Nenhum lançamento financeiro criado.');
  } finally {lock.releaseLock();}
}

/** Explicit opt-in; do not run this during code publication. */
function folegoInstalarCapturaEmailV353() {
  var name = 'folegoCapturarEmailsMercadoPagoV353';
  var existing = ScriptApp.getProjectTriggers().filter(function(t){ return t.getHandlerFunction() === name; });
  if (existing.length) return {installed:false,alreadyInstalled:true,triggerCount:existing.length};
  ScriptApp.newTrigger(name).timeBased().everyMinutes(5).create();
  return {installed:true,alreadyInstalled:false};
}

/** Gmail's first Authentication-Results header is generated by the receiving server.
 * Sender whitelist alone is insufficient; require aligned passing DMARC.
 * If unavailable, reject the receipt instead of trusting unverified mail.
 */
function fmpEmlAuthenticatedV353_(msg) {
  var header = String(msg.getHeader('Authentication-Results') || '').replace(/\r?\n[ \t]+/g,' ');
  return /^mx\.google\.com[;\s]/i.test(header.trim()) &&
    /\bdmarc=pass\b/i.test(header) &&
    /\bheader\.from=(?:mercadopago\.com(?:\.br)?|mercadolivre\.com(?:\.br)?)(?:[;\s]|$)/i.test(header);
}

/** Reuse the existing server-scoped spreadsheet integration credential.
 * Endpoint independently reconciles every receipt and never creates financial events.
 */
function fmpEmlDeliverV353_(rec,hash,dryRun) {
  if (typeof _folegoSyncApi_ !== 'function') throw new Error('Sincronizador seguro obrigatório.');
  return _folegoSyncApi_({action:'capture_receipts',dry_run:!!dryRun,receipts:[{
    source_kind:'gmail',source_hash:hash,provider:'MercadoPago',
    direction:rec.direction,amount:rec.amount,counterparty:rec.recipient || null,
    description:rec.description,occurred_at:rec.date.toISOString(),
    provider_transaction_id:rec.providerTransactionId || null,
    linked_launch_id:rec.linkedLaunchId || null
  }]});
}

/** Pure Apps Script QA: no Gmail/Sheets/backend reads or writes. */
function folegoEmailMercadoPagoTestesV353() {
  var passed = [], date = new Date('2026-10-16T10:32:17Z');
  function check(name,value) {if (!value) throw new Error('QA falhou: '+name); passed.push(name);}
  var claro = fmpEmlParseV353_('Seu Pix foi enviado','Seu Pix de R$ 56,01 foi enviado Sexta-feira, 16 de outubro de 2026, às 07:32:17. CLARO S A CPF/CNPJ: xx',date);
  check('Claro exact amount',claro.amount===56.01 && claro.direction==='out');
  check('São Paulo timestamp',claro.date.toISOString()==='2026-10-16T10:32:17.000Z');
  check('Claro recipient',claro.recipient==='CLARO S A');
  var moto = fmpEmlParseV353_('Seu Pix foi enviado','Seu Pix de R$ 635 foi enviado Quinta-feira, 15 de outubro de 2026, às 19:07:31. Jeferson Felipe da Silva CPF/CNPJ: xx',date);
  check('Motortech amount not modified',moto.amount===635 && moto.amount!==634.20);
  check('Incoming Kindle',fmpEmlParseV353_('Pix recebido','Seu Pix de R$ 370,12 foi recebido',date).direction==='in');
  check('Own transfer receipt stays unconfirmed',fmpEmlParseV353_('Seu Pix foi enviado','Seu Pix de R$ 0,01 foi enviado',date).amount===0.01);
  check('Rejected ignored',fmpEmlParseV353_('Pix recusado','Seu Pix de R$ 56,01 foi enviado',date)===null);
  check('Promotion ignored',fmpEmlParseV353_('Promoção','Você ganhou R$ 50',date)===null);
  check('Spoof sender rejected',!fmpEmlAllowedSenderV353_('x@mercadopago.com.br.attacker.io'));
  check('DMARC failure rejected',!fmpEmlAuthenticatedV353_({getHeader:function(){return 'mx.google.com; dmarc=fail header.from=mercadopago.com.br';}}));
  check('Review isolated from financial reprocessor',FMP_EMAIL_V353.SHEET_STATUS_REVIEW==='RevisaoEmail');
  return {ok:true,version:'V3.5.3',tests:passed.length,passed:passed,writes:0};
}

/** Gmail REST GET only. Manifest MUST use gmail.readonly, never mail.google.com.
 * OAuth token stays exclusively in the request header and is never logged.
 */
function fmpEmlRestGetV353_(path) {
  if (!/^(?:messages(?:\?|\/[a-zA-Z0-9_-]+\?))/.test(path)) throw new Error('Gmail read path inválido.');
  var response = UrlFetchApp.fetch('https://gmail.googleapis.com/gmail/v1/users/me/'+path,{
    method:'get',headers:{Authorization:'Bearer '+ScriptApp.getOAuthToken()},muteHttpExceptions:true});
  var code = response.getResponseCode();
  if (code!==200) throw new Error('Gmail leitura indisponível (HTTP '+code+').');
  var data;
  try { data=JSON.parse(response.getContentText()); } catch (_) {throw new Error('Resposta Gmail inválida.');}
  if (!data || data.error) throw new Error('Resposta Gmail inválida.');
  return data;
}

function fmpEmlRestListV353_() {
  var items=[],pageToken='',pages=0;
  do {
    var page=fmpEmlRestGetV353_('messages?maxResults='+FMP_EMAIL_V353.PAGE_SIZE+'&q='+encodeURIComponent(FMP_EMAIL_V353.QUERY)+(pageToken?'&pageToken='+encodeURIComponent(pageToken):''));
    var rows=page.messages || [];
    if (!Array.isArray(rows)) throw new Error('Lista Gmail inválida.');
    for(var i=0;i<rows.length && items.length<FMP_EMAIL_V353.MAX_MESSAGES;i++) {
      if (!rows[i] || !/^[a-zA-Z0-9_-]+$/.test(rows[i].id || '')) throw new Error('Identificador Gmail inválido.');
      items.push(fmpEmlRestMessageV353_(fmpEmlRestGetV353_('messages/'+encodeURIComponent(rows[i].id)+'?format=full')));
    }
    pageToken=String(page.nextPageToken || '');pages++;
  } while(pageToken && pages<FMP_EMAIL_V353.MAX_PAGES && items.length<FMP_EMAIL_V353.MAX_MESSAGES);
  return {messages:items,truncated:!!pageToken};
}

function fmpEmlRestMessageV353_(raw) {
  if (!raw || !raw.id || !raw.payload || !/^\d+$/.test(String(raw.internalDate || ''))) throw new Error('Mensagem Gmail incompleta.');
  var headers=raw.payload.headers || [];
  function header(name) {
    // First server-inserted Authentication-Results header wins; do not trust later copies.
    for(var i=0;i<headers.length;i++) if(String(headers[i].name).toLowerCase()===name.toLowerCase()) return String(headers[i].value || '');
    return '';
  }
  return {getId:function(){return raw.id;},getFrom:function(){return header('From');},
    getSubject:function(){return header('Subject');},getHeader:header,
    getDate:function(){return new Date(Number(raw.internalDate));},
    getPlainBody:function(){return fmpEmlMimeTextV353_(raw.payload);}};
}

function fmpEmlMimeTextV353_(root) {
  var plain=[],html=[],nodes=0;
  function walk(part,depth) {
    if (!part || depth>12 || ++nodes>120) throw new Error('Estrutura MIME excessiva.');
    if (part.filename || /attachment/i.test((part.headers || []).filter(function(h){return String(h.name).toLowerCase()==='content-disposition';}).map(function(h){return h.value;}).join(' '))) return;
    var type=String(part.mimeType || '').toLowerCase(), data=part.body && part.body.data;
    if (data && (type==='text/plain' || type==='text/html')) {
      if (data.length>1000000) throw new Error('Comprovante excede limite seguro.');
      var bytes=Utilities.base64DecodeWebSafe(data);
      var contentType=(part.headers || []).filter(function(h){return String(h.name).toLowerCase()==='content-type';}).map(function(h){return h.value;}).join(' ');
      var charset=(contentType.match(/charset=["']?([a-zA-Z0-9_-]+)/i) || [,'UTF-8'])[1];
      var decoded=Utilities.newBlob(bytes).getDataAsString(charset);
      if(type==='text/plain')plain.push(decoded);else html.push(decoded);
    }
    (part.parts || []).forEach(function(p){walk(p,depth+1);});
  }
  walk(root,0);
  if (plain.length) return plain.join('\n');
  return html.join('\n').replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,' ').replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi,' ')
    .replace(/<[^>]*>/g,' ').replace(/&#(x[0-9a-f]+|\d+);/gi,function(_,n){var c=n[0].toLowerCase()==='x'?parseInt(n.slice(1),16):parseInt(n,10);return c>0 && c<=65535?String.fromCharCode(c):' ';})
    .replace(/&(?:nbsp|amp|lt|gt|quot|apos);/gi,function(entity){return {'&nbsp;':' ','&amp;':'&','&lt;':'<','&gt;':'>','&quot;':'"','&apos;':"'"}[entity.toLowerCase()];});
}

/** Extend only this receipt's status cell, copying all validation options.
 * Existing rows, trigger statuses and dropdown source ranges remain untouched.
 */
function fmpEmlPrepareReviewValidationV353_(ss,row) {
  if (!row || row<1 || Math.floor(row)!==row) throw new Error('Linha de captura inválida.');
  var cell=ss.getSheetByName(CFG_V3.SHEETS.INPUT).getRange(row,11);
  var rule=cell.getDataValidation();
  if (!rule) return; // Unrestricted cell already accepts isolated review status.
  if (rule.getCriteriaType()!==SpreadsheetApp.DataValidationCriteria.VALUE_IN_LIST) {
    throw new Error('Validação de status incompatível; revisão preservada no backend.');
  }
  var args=rule.getCriteriaValues();
  var options=(args[0] || []).slice();
  if (options.indexOf(FMP_EMAIL_V353.SHEET_STATUS_REVIEW)>=0) return;
  options.push(FMP_EMAIL_V353.SHEET_STATUS_REVIEW);
  cell.setDataValidation(rule.copy().requireValueInList(options,args.length>1?args[1]:true).build());
}
