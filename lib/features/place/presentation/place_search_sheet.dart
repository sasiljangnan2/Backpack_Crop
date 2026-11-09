import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../data/place_models.dart';

/// 장소 검색 결과. [place]가 null이면 지도에 없이 글자로만 적은 장소
typedef PlacePick = ({String text, Place? place});

/// BP-SC-002 장소 입력 · BP-AI-002 위치 직접 입력.
/// 공용 검색 서버 정책상 글자를 칠 때마다 찾지 않고, 검색 버튼(엔터)을 눌렀을 때만 찾는다
Future<PlacePick?> showPlaceSearch(
  BuildContext context, {
  String? tripId,
  String? initialQuery,
  double? nearLat,
  double? nearLng,
  bool allowTextOnly = true,
  String title = '장소 검색',
}) => showAppSheet<PlacePick>(
  context,
  title: title,
  child: _PlaceSearch(
    tripId: tripId,
    initialQuery: initialQuery,
    nearLat: nearLat,
    nearLng: nearLng,
    allowTextOnly: allowTextOnly,
  ),
);

class _PlaceSearch extends StatefulWidget {
  const _PlaceSearch({
    this.tripId,
    this.initialQuery,
    this.nearLat,
    this.nearLng,
    required this.allowTextOnly,
  });

  final String? tripId;
  final String? initialQuery;
  final double? nearLat;
  final double? nearLng;
  final bool allowTextOnly;

  @override
  State<_PlaceSearch> createState() => _PlaceSearchState();
}

class _PlaceSearchState extends State<_PlaceSearch> {
  late final _query = TextEditingController(text: widget.initialQuery);
  List<Place>? _results;
  bool _searching = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if ((widget.initialQuery ?? '').trim().isNotEmpty) {
      _search();
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await services.places.search(
        q,
        tripId: widget.nearLat == null ? widget.tripId : null,
        lat: widget.nearLat,
        lng: widget.nearLng,
      );
      if (mounted) {
        setState(() => _results = results);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final text = _query.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _query,
          autofocus: (widget.initialQuery ?? '').isEmpty,
          textInputAction: TextInputAction.search,
          maxLength: 100,
          decoration: InputDecoration(
            hintText: '예: 구로몬 시장, 黒門市場',
            counterText: '',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: '검색',
                    onPressed: _search,
                    icon: const Icon(Icons.arrow_forward),
                  ),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 8),
        if (_error != null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '장소를 찾지 못했어요. 인터넷 연결을 확인하거나 이름을 그대로 써 주세요.',
              style: TextStyle(color: AppColors.error, fontSize: 13),
            ),
          )
        else if (results != null && results.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '검색 결과가 없어요. 현지 이름(예: 黒門市場)이나 영어로 찾아보세요.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          )
        else if (results != null)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .45,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: results.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final place = results[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(place.category.icon, color: AppColors.primary),
                  title: Text(
                    place.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: place.address.isEmpty
                      ? null
                      : Text(
                          place.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                  trailing: Text(
                    place.category.label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  onTap: () => Navigator.pop<PlacePick>(context, (
                    text: place.name,
                    place: place,
                  )),
                );
              },
            ),
          ),
        if (widget.allowTextOnly && text.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () =>
                Navigator.pop<PlacePick>(context, (text: text, place: null)),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.muted,
              alignment: Alignment.centerLeft,
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text("'$text' 이름만 쓰기 (지도에는 안 보여요)"),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          (results ?? const []).any((p) => p.fromGoogle)
              ? '장소 검색: Google'
              : '장소 검색: Google · OpenStreetMap',
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }
}
