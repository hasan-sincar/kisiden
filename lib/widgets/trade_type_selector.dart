import 'package:flutter/material.dart';

import '../data/trade_types.dart';
import '../utils/local_fonts.dart';
import '../utils/translations.dart';

class TradeTypeSelector extends StatelessWidget {
  const TradeTypeSelector({
    super.key,
    required this.selectedTypes,
    required this.onTypeToggled,
    this.showHeading = true,
  });

  final Set<String> selectedTypes;
  final ValueChanged<String> onTypeToggled;
  final bool showHeading;

  Future<void> _showTradeTypeDialog(BuildContext context) async {
    final dialogSelectedTypes = Set<String>.from(selectedTypes);
    if (dialogSelectedTypes.contains(allTradeTypesId)) {
      dialogSelectedTypes
        ..clear()
        ..add(allTradeTypesId);
    }

    void toggleType(String typeId, void Function(void Function()) setState) {
      setState(() {
        if (dialogSelectedTypes.contains(typeId)) {
          dialogSelectedTypes.remove(typeId);
        } else if (typeId == allTradeTypesId) {
          dialogSelectedTypes
            ..clear()
            ..add(allTradeTypesId);
        } else {
          dialogSelectedTypes
            ..remove(allTradeTypesId)
            ..add(typeId);
        }
      });
    }

    Widget buildTypeOption(
      TradeType type,
      void Function(void Function()) setDialogState,
    ) {
      final isSelected = dialogSelectedTypes.contains(type.id);
      return Material(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => toggleType(type.id, setDialogState),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (_) => toggleType(type.id, setDialogState),
                ),
                Expanded(
                  child: Text(
                    tr(type.labelKey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: LocalFonts.poppins(
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tr('desired_trade_types')),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('desired_trade_types_hint'),
                    style: LocalFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      for (var index = 0; index < tradeTypes.length; index += 2)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: index + 2 < tradeTypes.length ? 8 : 0,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: buildTypeOption(
                                  tradeTypes[index],
                                  setDialogState,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: index + 1 < tradeTypes.length
                                    ? buildTypeOption(
                                        tradeTypes[index + 1],
                                        setDialogState,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(tr('confirm')),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    for (final type in tradeTypes) {
      if (selectedTypes.contains(type.id) !=
          dialogSelectedTypes.contains(type.id)) {
        onTypeToggled(type.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleSelection = selectedTypes.contains(allTradeTypesId)
        ? <String>{allTradeTypesId}
        : selectedTypes;
    final selectedLabels = tradeTypes
        .where((type) => visibleSelection.contains(type.id))
        .map((type) => tr(type.labelKey))
        .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading) ...[
          Text(
            tr('desired_trade_types'),
            style: LocalFonts.poppins(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            tr('desired_trade_types_hint'),
            style: LocalFonts.poppins(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _showTradeTypeDialog(context),
            style: OutlinedButton.styleFrom(
              alignment: AlignmentDirectional.centerStart,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selectedLabels.isEmpty
                        ? tr('choose_trade_types')
                        : selectedLabels,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LocalFonts.poppins(
                      fontSize: 13,
                      color: selectedLabels.isEmpty
                          ? Colors.grey[700]
                          : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.expand_more, color: Colors.grey[700]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
