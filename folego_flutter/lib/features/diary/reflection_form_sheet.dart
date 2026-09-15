import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/reflection_visuals.dart';
import '../../data/models/transaction_reflection.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_diary.dart';

class ReflectionFormSheet extends StatefulWidget {
  const ReflectionFormSheet({
    super.key,
    required this.repository,
    required this.spaceId,
    required this.entry,
  });

  final FolegoRepository repository;
  final String spaceId;
  final DiaryEntry entry;

  @override
  State<ReflectionFormSheet> createState() => _ReflectionFormSheetState();
}

class _ReflectionFormSheetState extends State<ReflectionFormSheet> {
  late final TextEditingController _note;
  ReflectionType? _type;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.entry.reflection?.type;
    _note = TextEditingController(text: widget.entry.reflection?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final type = _type;
    if (type == null) {
      setState(() => _error = 'escolha uma reflexão para continuar');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.upsertReflection(
        spaceId: widget.spaceId,
        eventId: widget.entry.eventId,
        type: type,
        note: _note.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _delete() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.deleteReflection(
        spaceId: widget.spaceId,
        eventId: widget.entry.eventId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: AppColors.surface(brightness),
      borderRadius: BorderRadius.circular(28),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.entry.reflection == null
                          ? 'refletir sobre este gasto'
                          : 'editar reflexão',
                      style: AppTypography.section(context, fontSize: 18),
                    ),
                  ),
                  IconButton(
                    tooltip: 'fechar',
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(AppIcons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.entry.displayDescription,
                style: AppTypography.body(
                  context,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText(brightness),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'como esse gasto se encaixa pra você?',
                style: AppTypography.body(
                  context,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ReflectionType.values.map((type) {
                  final selected = _type == type;
                  final foreground = ReflectionVisuals.foreground(type, brightness);
                  return ChoiceChip(
                    selected: selected,
                    avatar: Icon(
                      ReflectionVisuals.icon(type),
                      size: 16,
                      color: foreground,
                    ),
                    label: Text(type.label),
                    selectedColor: ReflectionVisuals.background(type, brightness),
                    side: BorderSide(
                      color: selected
                          ? ReflectionVisuals.border(type, brightness)
                          : AppColors.border(brightness),
                    ),
                    onSelected: (_) => setState(() {
                      _type = type;
                      _error = null;
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                maxLength: 300,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'nota opcional',
                  hintText: 'quer lembrar alguma coisa sobre esse gasto?',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: AppTypography.body(
                    context,
                    fontSize: 11,
                    color: AppColors.expenseText(brightness),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.lime,
                  foregroundColor: AppColors.iconOnLime,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.entry.reflection == null
                            ? 'salvar reflexão'
                            : 'salvar alterações',
                      ),
              ),
              if (widget.entry.reflection != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _saving ? null : _delete,
                  child: const Text('remover reflexão'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
