import 'package:flutter/material.dart';

import '../theme/poema_colors.dart';

/// The 1px gold rule under every app bar.
class LineaOro extends StatelessWidget implements PreferredSizeWidget {
  const LineaOro({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(1);

  @override
  Widget build(BuildContext context) =>
      Container(color: context.colores.oro, height: 1);
}
