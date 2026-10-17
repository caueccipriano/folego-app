import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/notifications/notification_models.dart';

void main() {
  test('todos os quatro tons preservam fatos, datas e valores', () {
    const original = 'Sua fatura de R\$ 260,40 vence amanhã.';
    const styles = ['welcoming', 'normal', 'firm', 'aggressive'];
    final outputs = styles.map((s) => applyNotificationTone(original, s)).toList();
    expect(outputs.toSet().length, styles.length);
    for (final output in outputs) {
      expect(output, contains(original));
      expect(output, contains('R\$ 260,40'));
      expect(output, contains('amanhã'));
    }
    expect(outputs[0], startsWith('Vamos cuidar disso com calma.'));
    expect(outputs[1], original);
    expect(outputs[2], startsWith('Atenção: confira'));
    expect(outputs[3], contains('Porra'));
  });

  test('prévia global usa exatamente o mesmo renderizador de tom', () {
    for (final tone in ['welcoming', 'normal', 'firm', 'aggressive']) {
      expect(notificationTonePreview(tone),
          applyNotificationTone('Sua fatura vence amanhã.', tone));
    }
  });

  test('tela tem um seletor global sem label flutuante sobre divisória', () {
    final ui = File('lib/features/profile/notification_settings_screen.dart')
        .readAsStringSync();
    expect(ui, contains("title: 'tom das notificações'"));
    expect(ui, contains('_toneSection(prefs)'));
    expect(ui, contains("key: const ValueKey('notification-tone-preview')"));
    expect(ui, contains('notificationTonePreview(prefs.reminderStyle)'));
    expect(ui, contains('isExpanded: true'));
    expect(ui, isNot(contains("InputDecoration(labelText: 'tom dos avisos')")));
    expect(ui, contains('activeTrackColor: FolegoColorTokens.of(context).acao'));
  });

  test('dispatcher aplica o estilo escolhido a todos os tipos de alerta', () {
    final dispatcher = File('../supabase/functions/folego-push-dispatch/index.ts')
        .readAsStringSync();
    final shared = File('../supabase/functions/folego-push-dispatch/notification_tone.ts')
        .readAsStringSync();
    final daily = File('../supabase/migrations/20261009124552_habit_commitment.sql')
        .readAsStringSync();
    expect(dispatcher, contains('formatPushByTone(candidate.kind, candidate.title, candidate.body, style)'));
    expect(dispatcher, contains('select("user_id,space_id,reminder_style")'));
    expect(dispatcher, contains('recordDelivery(outgoing)'));
    expect(dispatcher, contains('tone_query_failed'));
    expect(shared, contains('reminderStyle === "aggressive"'));
    expect(shared, contains('reminderStyle === "firm"'));
    expect(shared, contains('reminderStyle === "welcoming"'));
    // Revisão diária e segunda chamada já são estilizadas no SQL,
    // para evitar empilhar o mesmo tom duas vezes na entrega do push.
    expect(shared, contains('kind === "dailySummary"'));
    expect(daily, contains('case pref.reminder_style'));
    expect(daily, contains('if is_followup then'));
  });

  test('contrato de lembretes agendados respeita todas as preferências', () {
    final source = File('lib/core/notifications/notification_models.dart')
        .readAsStringSync();
    expect(source, contains('reminderStyle: preferences.reminderStyle'));
    expect(source, contains('return applyNotificationTone('));
  });
}
