import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../data/providers.dart';

/// Thumbnail of an asset by id. The server builds the path (`asLinkToPreview(id, "image200x200")`).
class AssetPreview extends ConsumerWidget {
  const AssetPreview({super.key, required this.assetId});
  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      color: scheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, size: 16),
    );
    final path = ref.watch(assetPreviewPathProvider(assetId));
    final headers = ref.watch(authHeadersProvider).value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: path.when(
        loading: () => Container(color: scheme.surfaceContainerHigh),
        error: (_, _) => placeholder,
        data: (p) => p == null || headers == null
            ? placeholder
            : Image.network(
                ref.watch(apiClientProvider).absolute(p),
                headers: headers,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}
