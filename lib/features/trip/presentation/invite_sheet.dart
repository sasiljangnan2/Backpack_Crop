import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../data/trip_models.dart';

/// BP-HM-002 초대 코드 공유
class InviteCodeCard extends StatelessWidget {
  const InviteCodeCard({super.key, required this.trip});

  final TripDetail trip;

  String get _formatted =>
      '${trip.inviteCode.substring(0, 4)}-${trip.inviteCode.substring(4)}';

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: trip.inviteCode));
    if (context.mounted) {
      showSnack(context, '초대 코드를 복사했어요.');
    }
  }

  Future<void> _share() => SharePlus.instance.share(
    ShareParams(
      text:
          '[Backpack] ${trip.name} 여행에 초대해요!\n'
          'Backpack 앱 → 여행 목록 → 코드로 참여에서 아래 코드를 입력하세요.\n\n'
          '초대 코드: ${trip.inviteCode}',
      subject: '${trip.name} 여행 초대',
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            '함께 갈 친구에게 초대 코드를 보내 주세요',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          SelectableText(
            _formatted,
            style: const TextStyle(
              fontSize: 30,
              letterSpacing: 4,
              color: AppColors.primaryText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copy(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('복사'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _share,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: const Text('공유'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showInviteSheet(BuildContext context, TripDetail trip) =>
    showAppSheet<void>(
      context,
      title: '친구 초대',
      child: InviteCodeCard(trip: trip),
    );
