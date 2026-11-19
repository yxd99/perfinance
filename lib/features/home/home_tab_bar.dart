import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:perfinance/core/theme/app_colors.dart';

/// Una sección de la barra inferior.
class HomeTab {
  const HomeTab({required this.label, required this.icon, required this.selectedIcon});

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Secciones del shell, en orden. El «+» va entre la segunda y la tercera.
const homeTabs = <HomeTab>[
  HomeTab(label: 'Mes', icon: CupertinoIcons.chart_pie, selectedIcon: CupertinoIcons.chart_pie_fill),
  HomeTab(label: 'Egresos', icon: CupertinoIcons.square_list, selectedIcon: CupertinoIcons.square_list_fill),
  HomeTab(
    label: 'Deudas',
    icon: CupertinoIcons.money_dollar_circle,
    selectedIcon: CupertinoIcons.money_dollar_circle_fill,
  ),
  HomeTab(label: 'Más', icon: CupertinoIcons.ellipsis_circle, selectedIcon: CupertinoIcons.ellipsis_circle_fill),
];

/// Índice de «Más» en [homeTabs]; lleva el contador de cambios sin subir.
const moreTabIndex = 3;

/// Barra inferior estilo iOS: cuatro secciones y un «+» central para registrar
/// un egreso. Es presentacional: el estado lo maneja quien la usa.
class HomeTabBar extends StatelessWidget {
  const HomeTabBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.onAdd,
    this.pendingCount = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  /// Cambios locales sin subir; se muestran como insignia en «Más».
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Las secciones pesan 2 y el botón de egreso 3: así entra su texto.
    Widget tab(int i) => Expanded(
          flex: 2,
          child: _TabItem(
            tab: homeTabs[i],
            selected: i == currentIndex,
            badgeCount: i == moreTabIndex ? pendingCount : 0,
            onTap: () => onSelect(i),
          ),
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.canvas,
        border: Border(top: BorderSide(color: c.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              tab(0),
              tab(1),
              Expanded(flex: 3, child: _AddButton(onPressed: onAdd)),
              tab(2),
              tab(3),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final HomeTab tab;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.accent : c.textMuted;
    Widget icon = Icon(selected ? tab.selectedIcon : tab.icon, size: 26, color: color);
    if (badgeCount > 0) {
      icon = Badge(
        label: Text('$badgeCount'),
        backgroundColor: c.danger,
        textColor: c.onDanger,
        child: icon,
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      label: badgeCount > 0 ? '${tab.label}, $badgeCount cambios sin subir' : tab.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(height: 2),
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const shape = StadiumBorder();
    // Pastilla «+ Egreso»: dice qué registra, así no se confunde con el
    // «Nueva deuda» de Deudas. Con letra grande se achica en vez de cortarse.
    return Center(
      child: Semantics(
        button: true,
        label: 'Registrar egreso',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: shape,
              shadows: [BoxShadow(color: c.shadow, offset: const Offset(0, 3), blurRadius: 10)],
            ),
            child: Material(
              color: c.accent,
              shape: shape,
              child: InkWell(
                customBorder: shape,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onPressed();
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.plus, size: 20, color: c.onAccent),
                          const SizedBox(width: 4),
                          Text(
                            'Egreso',
                            maxLines: 1,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: c.onAccent,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
