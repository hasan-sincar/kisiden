import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import '../utils/translations.dart';
import '../utils/theme_colors.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const sections = _faqSections;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          tr('faq_title'),
          style: LocalFonts.poppins(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('faq_intro'),
                    style: LocalFonts.poppins(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...sections.map((section) => _FaqSectionCard(section: section)),
        ],
      ),
    );
  }
}

class _FaqSectionCard extends StatelessWidget {
  const _FaqSectionCard({required this.section});

  final _FaqSectionData section;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        iconColor: section.color,
        collapsedIconColor: section.color,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: section.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(section.icon, color: section.color, size: 20),
        ),
        title: Text(
          tr(section.titleKey),
          style: LocalFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        children: section.items
            .map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  title: Text(
                    tr(item.questionKey),
                    style: LocalFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        tr(item.answerKey),
                        style: LocalFonts.poppins(
                          fontSize: 12.8,
                          color: Colors.black87,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _FaqSectionData {
  const _FaqSectionData({
    required this.titleKey,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String titleKey;
  final IconData icon;
  final Color color;
  final List<_FaqItemData> items;
}

class _FaqItemData {
  const _FaqItemData({required this.questionKey, required this.answerKey});

  final String questionKey;
  final String answerKey;
}

const List<_FaqSectionData> _faqSections = [
  _FaqSectionData(
    titleKey: 'faq_section_account',
    icon: Icons.person_outline,
    color: Color(0xFF0F766E),
    items: [
      _FaqItemData(
        questionKey: 'faq_q_account_missing_info',
        answerKey: 'faq_a_account_missing_info',
      ),
      _FaqItemData(
        questionKey: 'faq_q_account_language',
        answerKey: 'faq_a_account_language',
      ),
      _FaqItemData(
        questionKey: 'faq_q_account_delete',
        answerKey: 'faq_a_account_delete',
      ),
    ],
  ),
  _FaqSectionData(
    titleKey: 'faq_section_listing',
    icon: Icons.add_box_outlined,
    color: Color(0xFF1D4ED8),
    items: [
      _FaqItemData(
        questionKey: 'faq_q_listing_category_required',
        answerKey: 'faq_a_listing_category_required',
      ),
      _FaqItemData(
        questionKey: 'faq_q_listing_approval',
        answerKey: 'faq_a_listing_approval',
      ),
      _FaqItemData(
        questionKey: 'faq_q_listing_not_live',
        answerKey: 'faq_a_listing_not_live',
      ),
      _FaqItemData(
        questionKey: 'faq_q_listing_limit',
        answerKey: 'faq_a_listing_limit',
      ),
    ],
  ),
  _FaqSectionData(
    titleKey: 'faq_section_approval',
    icon: Icons.rule_folder_outlined,
    color: Color(0xFFB45309),
    items: [
      _FaqItemData(
        questionKey: 'faq_q_approval_rejected_reason',
        answerKey: 'faq_a_approval_rejected_reason',
      ),
      _FaqItemData(
        questionKey: 'faq_q_approval_edit_request',
        answerKey: 'faq_a_approval_edit_request',
      ),
      _FaqItemData(
        questionKey: 'faq_q_approval_passive_deleted',
        answerKey: 'faq_a_approval_passive_deleted',
      ),
    ],
  ),
  _FaqSectionData(
    titleKey: 'faq_section_messages',
    icon: Icons.chat_bubble_outline,
    color: Color(0xFF7C3AED),
    items: [
      _FaqItemData(
        questionKey: 'faq_q_messages_cant_contact',
        answerKey: 'faq_a_messages_cant_contact',
      ),
      _FaqItemData(
        questionKey: 'faq_q_messages_offer_status',
        answerKey: 'faq_a_messages_offer_status',
      ),
      _FaqItemData(
        questionKey: 'faq_q_messages_trade_manage',
        answerKey: 'faq_a_messages_trade_manage',
      ),
    ],
  ),
  _FaqSectionData(
    titleKey: 'faq_section_notifications',
    icon: Icons.notifications_active_outlined,
    color: Color(0xFFBE123C),
    items: [
      _FaqItemData(
        questionKey: 'faq_q_notifications_count_diff',
        answerKey: 'faq_a_notifications_count_diff',
      ),
      _FaqItemData(
        questionKey: 'faq_q_notifications_alarm',
        answerKey: 'faq_a_notifications_alarm',
      ),
      _FaqItemData(
        questionKey: 'faq_q_notifications_mark_read_clear',
        answerKey: 'faq_a_notifications_mark_read_clear',
      ),
    ],
  ),
  _FaqSectionData(
    titleKey: 'faq_section_payments',
    icon: Icons.workspace_premium_outlined,
    color: Color(0xFF0E7490),
    items: [
      _FaqItemData(
        questionKey: 'faq_q_payments_pro_not_active',
        answerKey: 'faq_a_payments_pro_not_active',
      ),
      _FaqItemData(
        questionKey: 'faq_q_payments_remaining_time',
        answerKey: 'faq_a_payments_remaining_time',
      ),
      _FaqItemData(
        questionKey: 'faq_q_payments_showcase_right',
        answerKey: 'faq_a_payments_showcase_right',
      ),
    ],
  ),
  _FaqSectionData(
    titleKey: 'faq_section_safety',
    icon: Icons.shield_outlined,
    color: Color(0xFF374151),
    items: [
      _FaqItemData(
        questionKey: 'faq_q_safety_block_user',
        answerKey: 'faq_a_safety_block_user',
      ),
      _FaqItemData(
        questionKey: 'faq_q_safety_report_result',
        answerKey: 'faq_a_safety_report_result',
      ),
      _FaqItemData(
        questionKey: 'faq_q_safety_sms_wait',
        answerKey: 'faq_a_safety_sms_wait',
      ),
    ],
  ),
];
