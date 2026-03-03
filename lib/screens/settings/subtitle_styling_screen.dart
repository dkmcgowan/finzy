import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finzy/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../i18n/strings.g.dart';
import '../../services/settings_service.dart';
import '../../widgets/focused_scroll_scaffold.dart';
import '../../widgets/color_picker.dart';

class SubtitleStylingScreen extends StatefulWidget {
  const SubtitleStylingScreen({super.key});

  @override
  State<SubtitleStylingScreen> createState() => _SubtitleStylingScreenState();
}

class _StylingSliderSection extends StatefulWidget {
  final String label;
  final int value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String Function(int)? valueFormatter;

  const _StylingSliderSection({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.onChangeEnd,
    this.valueFormatter,
  });

  @override
  State<_StylingSliderSection> createState() => _StylingSliderSectionState();
}

class _StylingSliderSectionState extends State<_StylingSliderSection> {
  late final FocusNode _sliderFocusNode;

  @override
  void initState() {
    super.initState();
    _sliderFocusNode = FocusNode(onKeyEvent: _handleSliderKey);
  }

  KeyEventResult _handleSliderKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      node.focusInDirection(
        key == LogicalKeyboardKey.arrowUp ? TraversalDirection.up : TraversalDirection.down,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      final step = (widget.max - widget.min) / widget.divisions;
      final current = widget.value.toDouble();
      final newValue = (key == LogicalKeyboardKey.arrowLeft ? current - step : current + step)
          .clamp(widget.min, widget.max);
      if (newValue != current) {
        widget.onChanged(newValue);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _sliderFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formattedValue = widget.valueFormatter?.call(widget.value) ?? widget.value.toString();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(widget.label), Text(formattedValue)]),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                widget.valueFormatter?.call(widget.min.toInt()) ?? widget.min.toInt().toString(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Expanded(
                child: Slider(
                  focusNode: _sliderFocusNode,
                  value: widget.value.toDouble(),
                  min: widget.min,
                  max: widget.max,
                  divisions: widget.divisions,
                  label: formattedValue,
                  onChanged: widget.onChanged,
                  onChangeEnd: widget.onChangeEnd,
                ),
              ),
              Text(
                widget.valueFormatter?.call(widget.max.toInt()) ?? widget.max.toInt().toString(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Composable widget for color picker tiles
class _ColorSettingTile extends StatelessWidget {
  final String label;
  final String currentColor;
  final VoidCallback onTap;
  final Color Function(String) hexToColor;

  const _ColorSettingTile({
    required this.label,
    required this.currentColor,
    required this.onTap,
    required this.hexToColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: hexToColor(currentColor),
          border: const Border.fromBorderSide(BorderSide(color: Colors.grey)),
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
      ),
      title: Text(label),
      subtitle: Text(currentColor),
      trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
      onTap: onTap,
    );
  }
}

class _SubtitleStylingScreenState extends State<SubtitleStylingScreen> {
  late SettingsService _settingsService;
  bool _isLoading = true;
  final _contentKey = GlobalKey();

  int _fontSize = 55;
  String _textColor = '#FFFFFF';
  int _borderSize = 3;
  String _borderColor = '#000000';
  String _backgroundColor = '#000000';
  int _backgroundOpacity = 0;
  int _subtitlePosition = 100;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _focusFirstItem() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final contentContext = _contentKey.currentContext;
      if (contentContext == null) return;
      final scope = FocusScope.of(contentContext);
      final firstChild = scope.traversalDescendants.cast<FocusNode?>().firstWhere(
        (node) => node!.canRequestFocus && node.context != null,
        orElse: () => null,
      );
      firstChild?.requestFocus();
    });
  }

  Future<void> _loadSettings() async {
    _settingsService = await SettingsService.getInstance();

    if (!mounted) return;
    setState(() {
      _fontSize = _settingsService.getSubtitleFontSize();
      _textColor = _settingsService.getSubtitleTextColor();
      _borderSize = _settingsService.getSubtitleBorderSize();
      _borderColor = _settingsService.getSubtitleBorderColor();
      _backgroundColor = _settingsService.getSubtitleBackgroundColor();
      _backgroundOpacity = _settingsService.getSubtitleBackgroundOpacity();
      _subtitlePosition = _settingsService.getSubtitlePosition();
      _isLoading = false;
    });
    _focusFirstItem();
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  String _colorToHex(Color color) {
    return '#${((color.r * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0')}${((color.g * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0')}${((color.b * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  void _showColorPicker(String title, String currentColor, Function(String) onColorSelected) {
    Color pickerColor = _hexToColor(currentColor);
    final saveFocusNode = FocusNode();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: HsvColorPicker(
                initialColor: pickerColor,
                onColorChanged: (color) => setDialogState(() => pickerColor = color),
                onConfirm: () => saveFocusNode.requestFocus(),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(t.common.cancel)),
                TextButton(
                  focusNode: saveFocusNode,
                  onPressed: () {
                    onColorSelected(_colorToHex(pickerColor));
                    Navigator.pop(dialogContext);
                  },
                  child: Text(t.common.save),
                ),
              ],
            );
          },
        );
      },
    ).then((_) => saveFocusNode.dispose());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return FocusedScrollScaffold(
        title: Text(t.screens.subtitleStyling),
        slivers: const [SliverFillRemaining(child: Center(child: CircularProgressIndicator()))],
      );
    }

    return FocusedScrollScaffold(
      title: Text(t.screens.subtitleStyling),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(delegate: SliverChildListDelegate([_buildStylingCard(), const SizedBox(height: 24)])),
        ),
      ],
    );
  }

  Widget _buildStylingCard() {
    return Card(
      key: _contentKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              t.subtitlingStyling.stylingOptions,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          // Font Size Slider
          _StylingSliderSection(
              label: t.subtitlingStyling.fontSize,
              value: _fontSize,
              min: 10,
              max: 80,
              divisions: 70,
              onChanged: (value) {
                setState(() {
                  _fontSize = value.toInt();
                });
              },
              onChangeEnd: (value) {
                _settingsService.setSubtitleFontSize(_fontSize);
              },
            ),
          const Divider(),
          // Subtitle Position Slider
          _StylingSliderSection(
              label: t.subtitlingStyling.position,
              value: _subtitlePosition,
              min: 0,
              max: 100,
              divisions: 20,
              valueFormatter: (value) {
                if (value == 0) return 'Top';
                if (value == 100) return 'Bottom';
                return '$value%';
              },
              onChanged: (value) {
                setState(() {
                  _subtitlePosition = value.toInt();
                });
              },
              onChangeEnd: (value) {
                _settingsService.setSubtitlePosition(_subtitlePosition);
              },
            ),
          const Divider(),
          // Text Color
          _ColorSettingTile(
            label: t.subtitlingStyling.textColor,
            currentColor: _textColor,
            hexToColor: _hexToColor,
            onTap: () {
              void onColorSelected(String color) {
                setState(() => _textColor = color);
                _settingsService.setSubtitleTextColor(color);
              }

              _showColorPicker(t.subtitlingStyling.textColor, _textColor, onColorSelected);
            },
          ),
          const Divider(),
          // Border Size Slider
          _StylingSliderSection(
              label: t.subtitlingStyling.borderSize,
              value: _borderSize,
              min: 0,
              max: 5,
              divisions: 5,
              onChanged: (value) {
                setState(() {
                  _borderSize = value.toInt();
                });
              },
              onChangeEnd: (value) {
                _settingsService.setSubtitleBorderSize(_borderSize);
              },
            ),
          const Divider(),
          // Border Color
          _ColorSettingTile(
            label: t.subtitlingStyling.borderColor,
            currentColor: _borderColor,
            hexToColor: _hexToColor,
            onTap: () {
              void onColorSelected(String color) {
                setState(() => _borderColor = color);
                _settingsService.setSubtitleBorderColor(color);
              }

              _showColorPicker(t.subtitlingStyling.borderColor, _borderColor, onColorSelected);
            },
          ),
          const Divider(),
          // Background Opacity Slider
          _StylingSliderSection(
              label: t.subtitlingStyling.backgroundOpacity,
              value: _backgroundOpacity,
              min: 0,
              max: 100,
              divisions: 20,
              valueFormatter: (value) => '$value%',
              onChanged: (value) {
                setState(() {
                  _backgroundOpacity = value.toInt();
                });
              },
              onChangeEnd: (value) {
                _settingsService.setSubtitleBackgroundOpacity(_backgroundOpacity);
              },
            ),
          const Divider(),
          // Background Color
          _ColorSettingTile(
            label: t.subtitlingStyling.backgroundColor,
            currentColor: _backgroundColor,
            hexToColor: _hexToColor,
            onTap: () {
              void onColorSelected(String color) {
                setState(() => _backgroundColor = color);
                _settingsService.setSubtitleBackgroundColor(color);
              }

              _showColorPicker(t.subtitlingStyling.backgroundColor, _backgroundColor, onColorSelected);
            },
          ),
        ],
      ),
    );
  }
}
