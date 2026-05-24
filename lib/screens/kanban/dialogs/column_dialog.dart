import 'package:flutter/material.dart';

/// Диалог создания новой колонки канбана.
Future<Map<String, dynamic>?> showColumnDialog(BuildContext context) {
  final nameCtrl = TextEditingController();
  final keyCtrl = TextEditingController();
  Color pickedColor = Colors.blue;

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Новая колонка'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(
                labelText: 'Ключ статуса',
                helperText: 'напр. reviewing, blocked',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Цвет: '),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final color = await _pickColor(ctx);
                    if (color != null) setDialogState(() => pickedColor = color);
                  },
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: pickedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty || keyCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, {
                'name': nameCtrl.text.trim(),
                'statusKey': keyCtrl.text.trim(),
                'colorValue': '#${pickedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
              });
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    ),
  );
}

Future<Color?> _pickColor(BuildContext context) {
  const colors = [
    Colors.blue, Colors.green, Colors.orange, Colors.red,
    Colors.purple, Colors.teal, Colors.brown, Colors.indigo,
  ];
  return showDialog<Color>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Выберите цвет'),
      children: colors.map((clr) => SimpleDialogOption(
        onPressed: () => Navigator.pop(ctx, clr),
        child: Row(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: clr,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(_colorName(clr)),
          ],
        ),
      )).toList(),
    ),
  );
}

String _colorName(Color c) {
  if (c == Colors.blue) return 'Синий';
  if (c == Colors.green) return 'Зелёный';
  if (c == Colors.orange) return 'Оранжевый';
  if (c == Colors.red) return 'Красный';
  if (c == Colors.purple) return 'Фиолетовый';
  if (c == Colors.teal) return 'Бирюзовый';
  if (c == Colors.brown) return 'Коричневый';
  if (c == Colors.indigo) return 'Индиго';
  return 'Другой';
}
