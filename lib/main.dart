import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ExpensesStore store = await ExpensesStore.create();
  runApp(ExpensesApp(store: store));
}

const List<String> kMonths = <String>[
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

class ExpenseItem {
  ExpenseItem({
    this.item = '',
    this.amount = 0,
    this.paid = 0,
    this.isDone = false,
    this.isEditing = true,
  });

  String item;
  double amount;
  double paid;
  bool isDone;
  bool isEditing;

  double get remaining {
    final double value = amount - paid;
    return value < 0 ? 0 : value;
  }

  factory ExpenseItem.fromMap(Map<dynamic, dynamic> map) {
    return ExpenseItem(
      item: (map['item'] ?? '') as String,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      paid: (map['paid'] as num?)?.toDouble() ?? 0,
      isDone: (map['isDone'] ?? false) as bool,
      isEditing: (map['isEditing'] ?? true) as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'item': item,
      'amount': amount,
      'paid': paid,
      'isDone': isDone,
      'isEditing': isEditing,
    };
  }
}

class ExpensesStore {
  ExpensesStore._(this._box);

  static const String _boxName = 'expenses_box';
  static const String _themeModeKey = '__theme_mode__';

  final Box<dynamic>? _box;
  final Map<String, List<ExpenseItem>> _itemsByMonth = <String, List<ExpenseItem>>{};

  static Future<ExpensesStore> create() async {
    await Hive.initFlutter();
    final Box<dynamic> box = await Hive.openBox<dynamic>(_boxName);
    return ExpensesStore._(box);
  }

  factory ExpensesStore.memory() {
    return ExpensesStore._(null);
  }

  List<ExpenseItem> itemsForMonth(String month) {
    return _itemsByMonth.putIfAbsent(month, () {
      if (_box == null) {
        return <ExpenseItem>[ExpenseItem()];
      }
      final dynamic rawRows = _box.get(month);
      if (rawRows is List) {
        final List<ExpenseItem> restored = rawRows
            .whereType<Map>()
            .map((Map<dynamic, dynamic> row) => ExpenseItem.fromMap(row))
            .toList();
        if (restored.isNotEmpty) {
          return restored;
        }
      }
      return <ExpenseItem>[ExpenseItem()];
    });
  }

  void addRow(String month) {
    itemsForMonth(month).add(ExpenseItem());
    persistMonth(month);
  }

  void removeRow(String month, int index) {
    final List<ExpenseItem> rows = itemsForMonth(month);
    if (rows.length == 1) {
      rows[0] = ExpenseItem();
      persistMonth(month);
      return;
    }
    rows.removeAt(index);
    persistMonth(month);
  }

  void persistMonth(String month) {
    if (_box == null) {
      return;
    }
    final List<Map<String, dynamic>> serialized = itemsForMonth(
      month,
    ).map((ExpenseItem row) => row.toMap()).toList();
    unawaited(_box.put(month, serialized));
  }

  ThemeMode loadThemeMode() {
    if (_box == null) {
      return ThemeMode.light;
    }
    final String? value = _box.get(_themeModeKey) as String?;
    if (value == ThemeMode.dark.name) {
      return ThemeMode.dark;
    }
    return ThemeMode.light;
  }

  void saveThemeMode(ThemeMode mode) {
    if (_box == null) {
      return;
    }
    unawaited(_box.put(_themeModeKey, mode.name));
  }
}

class ExpensesApp extends StatefulWidget {
  const ExpensesApp({super.key, required this.store});

  final ExpensesStore store;

  @override
  State<ExpensesApp> createState() => _ExpensesAppState();
}

class _ExpensesAppState extends State<ExpensesApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.store.loadThemeMode();
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
      widget.store.saveThemeMode(_themeMode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'المصروفات',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: ExpensesHomePage(
        store: widget.store,
        themeMode: _themeMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class ExpensesHomePage extends StatelessWidget {
  const ExpensesHomePage({
    super.key,
    required this.store,
    required this.themeMode,
    required this.onToggleTheme,
  });

  final ExpensesStore store;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ExpenseLogoIcon(size: 26),
            SizedBox(width: 12),
            Text('المصروفات - الشهور'),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: themeMode == ThemeMode.dark ? 'الوضع الفاتح' : 'الوضع الداكن',
            onPressed: onToggleTheme,
            icon: Icon(themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const int crossAxisCount = 3;
            const int rowCount = 4;
            const double spacing = 10;
            const double ratio = 1.4;

            final double gridWidth = constraints.maxWidth;
            final double itemWidth =
                (gridWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;
            final double itemHeight = itemWidth / ratio;
            final double gridHeight = (itemHeight * rowCount) + (spacing * (rowCount - 1));

            return Center(
              child: SizedBox(
                height: gridHeight,
                child: GridView.builder(
                  itemCount: kMonths.length,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: ratio,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    final String month = kMonths[index];
                    final ColorScheme colorScheme = Theme.of(context).colorScheme;
                    final bool isDark = Theme.of(context).brightness == Brightness.dark;
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MonthDetailsPage(month: month, store: store),
                          ),
                        );
                      },
                      child: Card(
                        elevation: isDark ? 0 : 1,
                        color: isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isDark
                                ? colorScheme.outlineVariant
                                : colorScheme.outline.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            month,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ExpenseLogoIcon extends StatelessWidget {
  const ExpenseLogoIcon({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: size * 0.62,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          Positioned(
            right: -size * 0.12,
            bottom: -size * 0.12,
            child: Container(
              width: size * 0.52,
              height: size * 0.52,
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.surface, width: 1.6),
              ),
              child: Icon(
                Icons.calculate_rounded,
                size: size * 0.3,
                color: colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MonthDetailsPage extends StatefulWidget {
  const MonthDetailsPage({super.key, required this.month, required this.store});

  final String month;
  final ExpensesStore store;

  @override
  State<MonthDetailsPage> createState() => _MonthDetailsPageState();
}

class _MonthDetailsPageState extends State<MonthDetailsPage> {
  TextStyle _rowTextStyle(ExpenseItem row) {
    return TextStyle(
      decoration: row.isDone ? TextDecoration.lineThrough : TextDecoration.none,
      color: row.isDone ? Colors.red.shade700 : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ExpenseItem> rows = widget.store.itemsForMonth(widget.month);
    final Iterable<ExpenseItem> activeRows = rows.where((ExpenseItem e) => !e.isDone);
    final double totalAmount = activeRows.fold<double>(
      0,
      (double sum, ExpenseItem e) => sum + e.amount,
    );
    final double totalPaid = activeRows.fold<double>(
      0,
      (double sum, ExpenseItem e) => sum + e.paid,
    );
    final double totalRemaining = activeRows.fold<double>(
      0,
      (double sum, ExpenseItem e) => sum + e.remaining,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const ExpenseLogoIcon(size: 24),
            const SizedBox(width: 8),
            Text(widget.month),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: DataTable(
                  columns: const <DataColumn>[
                    DataColumn(label: Text('تم')),
                    DataColumn(label: Text('الرقم')),
                    DataColumn(label: Text('البند')),
                    DataColumn(label: Text('المبلغ')),
                    DataColumn(label: Text('المدفوع')),
                    DataColumn(label: Text('المتبقي')),
                    DataColumn(label: Text('')),
                  ],
                  rows: List<DataRow>.generate(rows.length, (int index) {
                    final ExpenseItem row = rows[index];
                    final TextStyle rowStyle = _rowTextStyle(row);
                    return DataRow(
                      color: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
                        if (row.isDone) {
                          return Colors.red.withValues(alpha: 0.12);
                        }
                        return null;
                      }),
                      cells: <DataCell>[
                        DataCell(
                          Checkbox(
                            value: row.isDone,
                            onChanged: (bool? value) {
                              setState(() {
                                row.isDone = value ?? false;
                              });
                              widget.store.persistMonth(widget.month);
                            },
                          ),
                        ),
                        DataCell(Text('${index + 1}', style: rowStyle)),
                        DataCell(
                          SizedBox(
                            width: 180,
                            child: TextFormField(
                              initialValue: row.item,
                              enabled: row.isEditing,
                              style: rowStyle,
                              decoration: const InputDecoration(
                                hintText: 'اسم البند',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (String value) {
                                row.item = value;
                                widget.store.persistMonth(widget.month);
                              },
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 120,
                            child: TextFormField(
                              initialValue: row.amount == 0 ? '' : row.amount.toString(),
                              enabled: row.isEditing,
                              style: rowStyle,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                hintText: '0',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (String value) {
                                setState(() {
                                  row.amount = double.tryParse(value) ?? 0;
                                });
                                widget.store.persistMonth(widget.month);
                              },
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 120,
                            child: TextFormField(
                              initialValue: row.paid == 0 ? '' : row.paid.toString(),
                              enabled: row.isEditing,
                              style: rowStyle,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                hintText: '0',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (String value) {
                                setState(() {
                                  row.paid = double.tryParse(value) ?? 0;
                                });
                                widget.store.persistMonth(widget.month);
                              },
                            ),
                          ),
                        ),
                        DataCell(Text(row.remaining.toStringAsFixed(2), style: rowStyle)),
                        DataCell(
                          Row(
                            children: <Widget>[
                              IconButton(
                                tooltip: row.isEditing ? 'حفظ التعديل' : 'تعديل صف',
                                onPressed: () {
                                  setState(() {
                                    row.isEditing = !row.isEditing;
                                  });
                                  widget.store.persistMonth(widget.month);
                                },
                                icon: Icon(
                                  row.isEditing ? Icons.check_circle_outline : Icons.edit_outlined,
                                ),
                              ),
                              IconButton(
                                tooltip: 'حذف صف',
                                onPressed: () {
                                  setState(() {
                                    widget.store.removeRow(widget.month, index);
                                  });
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest),
            child: Wrap(
              spacing: 20,
              runSpacing: 6,
              children: <Widget>[
                Text('المجموع: ${totalAmount.toStringAsFixed(2)}'),
                Text('المدفوع: ${totalPaid.toStringAsFixed(2)}'),
                Text('المتبقي: ${totalRemaining.toStringAsFixed(2)}'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            widget.store.addRow(widget.month);
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('إضافة صف'),
      ),
    );
  }
}
