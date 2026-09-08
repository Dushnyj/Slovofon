import '../motion/app_motion.dart';
import '../motion/motion_tooltip.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as md;

import '../../app/localization/app_strings.dart';
import '../../app/theme/app_color_tokens.dart';
import '../icons/app_icons.dart';

/// Read-only GitHub-flavoured Markdown, rendered using native Flutter widgets.
/// No HTML engine, image loader, file access or executable links are involved.
class ReleaseNotes extends StatefulWidget {
  const ReleaseNotes({
    required this.data,
    required this.maxWidth,
    required this.onOpenLink,
    super.key,
  });

  final String data;
  final double maxWidth;
  final ValueChanged<Uri> onOpenLink;

  @override
  State<ReleaseNotes> createState() => _ReleaseNotesState();
}

class _ReleaseNotesState extends State<ReleaseNotes> {
  static const _maximumLength = 64000;
  late List<md.Node> _nodes;
  bool _truncated = false;

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(ReleaseNotes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _parse();
  }

  void _parse() {
    _truncated = widget.data.length > _maximumLength;
    final source = _truncated
        ? widget.data.substring(0, _maximumLength)
        : widget.data;
    _nodes = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    ).parse(source);
  }

  @override
  Widget build(BuildContext context) {
    final renderer = _NotesRenderer(context, widget.onOpenLink);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        renderer.blocks(_nodes, widget.maxWidth),
        if (_truncated) Text(context.strings.updateNotesTruncated),
      ],
    );
  }
}

/// Only explicit, absolute web links can leave this read-only document.
/// Credentials, control characters and platform-specific schemes are rejected.
Uri? releaseNotesWebUri(String? value) {
  if (value == null ||
      value.length > 4096 ||
      RegExp(r'[\x00-\x20\x7f\\]').hasMatch(value)) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

class _NotesRenderer {
  _NotesRenderer(this.context, this.onOpenLink);

  final BuildContext context;
  final ValueChanged<Uri> onOpenLink;
  ThemeData get theme => Theme.of(context);
  ColorScheme get colors => theme.colorScheme;
  TextStyle get body => theme.textTheme.bodyMedium!.copyWith(
    color: colors.onSurface,
    height: 1.5,
  );

  Widget blocks(List<md.Node> nodes, double width, [int depth = 0]) {
    if (depth > 24) return Text(nodes.map((n) => n.textContent).join(' '));
    final widgets = <Widget>[];
    final inlineNodes = <md.Node>[];
    void flushInline() {
      if (inlineNodes.isEmpty) return;
      widgets.add(paragraph(List.of(inlineNodes), width));
      inlineNodes.clear();
    }

    for (final node in nodes) {
      if (node is md.Element &&
          const {
            'h1',
            'h2',
            'h3',
            'h4',
            'h5',
            'h6',
            'p',
            'li',
            'ul',
            'ol',
            'blockquote',
            'pre',
            'table',
            'hr',
          }.contains(node.tag)) {
        flushInline();
        widgets.add(block(node, width, depth));
      } else {
        // Tight nested lists omit the <p> around their leading inline content.
        // Keep bold text and links together rather than making separate blocks.
        inlineNodes.add(node);
      }
    }
    flushInline();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < widgets.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          widgets[index],
        ],
      ],
    );
  }

  Widget block(md.Node node, double width, int depth) {
    if (node is! md.Element) return paragraph([node], width);
    final children = node.children ?? const <md.Node>[];
    switch (node.tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        final size = switch (node.tag) {
          'h1' => 22.0,
          'h2' => 18.0,
          _ => 16.0,
        };
        return Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: paragraph(
              children,
              width,
              style: body.copyWith(fontSize: size, fontWeight: FontWeight.w700),
            ),
          ),
        );
      case 'ul':
      case 'ol':
        var number = int.tryParse(node.attributes['start'] ?? '') ?? 1;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in children)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        node.tag == 'ol' ? '${number++}.' : '•',
                        style: body,
                      ),
                    ),
                    Expanded(
                      child: block(item, math.max(24, width - 24), depth + 1),
                    ),
                  ],
                ),
              ),
          ],
        );
      case 'li':
        if (children.any(
          (n) => n is md.Element && ['p', 'ul', 'ol'].contains(n.tag),
        )) {
          return blocks(children, width, depth + 1);
        }
        return paragraph(children, width);
      case 'blockquote':
        return quote(children, width, depth);
      case 'pre':
        return Container(
          width: width,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          // Wrap instead of horizontal scrolling: usable with a phone or remote.
          child: Text(
            node.textContent.trimRight(),
            style: body.copyWith(fontFamily: 'monospace'),
          ),
        );
      case 'table':
        return table(children, width, depth);
      case 'hr':
        return Divider(color: colors.outlineVariant);
      case 'p':
        return paragraph(children, width);
      default:
        return paragraph([node], width);
    }
  }

  Widget quote(List<md.Node> nodes, double width, int depth) {
    final children = List<md.Node>.of(nodes);
    String? kind;
    // Read only the first plain-text marker of the first paragraph; never
    // interpret markers inside a code fence, list item or ordinary sentence.
    if (children.isNotEmpty && children.first is md.Element) {
      final first = children.first as md.Element;
      if (first.tag == 'p' && first.children?.firstOrNull is md.Text) {
        final text = first.children!.first as md.Text;
        final marker = RegExp(
          r'^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\](?:\n|$)',
        ).firstMatch(text.text);
        if (marker != null) {
          kind = marker.group(1);
          final rest = <md.Node>[
            if (text.text.length > marker.end)
              md.Text(text.text.substring(marker.end)),
            ...first.children!.skip(1),
          ];
          children.removeAt(0);
          if (rest.isNotEmpty) children.insert(0, md.Element('p', rest));
        }
      }
    }
    final tokens = theme.extension<AppColorTokens>();
    final accent = switch (kind) {
      'NOTE' => tokens?.info ?? colors.primary,
      'TIP' => tokens?.success ?? colors.primary,
      'WARNING' => tokens?.warning ?? colors.error,
      'CAUTION' => colors.error,
      'IMPORTANT' => colors.primary,
      _ => colors.outline,
    };
    return Container(
      key: kind == null ? null : ValueKey('release-note-alert-$kind'),
      width: width,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kind != null) ...[
            Row(
              children: [
                AppIcon(
                  kind == 'WARNING' || kind == 'CAUTION'
                      ? AppIconAssets.systemWarning
                      : AppIconAssets.systemInfo,
                  size: 18,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.strings.updateNotesAlert(kind),
                    style: body.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          blocks(children, math.max(24, width - 29), depth + 1),
        ],
      ),
    );
  }

  Widget table(List<md.Node> groups, double width, int depth) {
    final rows = <md.Element>[];
    for (final group in groups.whereType<md.Element>()) {
      rows.addAll(
        (group.children ?? []).whereType<md.Element>().where(
          (n) => n.tag == 'tr',
        ),
      );
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    final columns = rows.map((r) => r.children?.length ?? 0).reduce(math.max);
    if (columns == 0) return const SizedBox.shrink();
    // GFM tables remain readable on phones and do not introduce a horizontal
    // focus trap. Flexible cells wrap; no intrinsic-width DataTable is used.
    return Table(
      border: TableBorder.all(color: colors.outlineVariant),
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        for (final row in rows)
          TableRow(
            children: [
              for (var i = 0; i < columns; i++)
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: i >= (row.children?.length ?? 0)
                      ? const SizedBox.shrink()
                      : paragraph(
                          (row.children![i] as md.Element).children ?? [],
                          math.max(12, width / columns - 12),
                          style: body.copyWith(
                            fontWeight:
                                (row.children![i] as md.Element).tag == 'th'
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                ),
            ],
          ),
      ],
    );
  }

  Widget paragraph(List<md.Node> nodes, double width, {TextStyle? style}) =>
      Text.rich(
        TextSpan(children: spans(nodes, width, style ?? body)),
        style: style ?? body,
      );

  List<InlineSpan> spans(
    List<md.Node> nodes,
    double width,
    TextStyle style, [
    int depth = 0,
  ]) {
    if (depth > 24) {
      return [TextSpan(text: nodes.map((n) => n.textContent).join(' '))];
    }
    return [
      for (final node in nodes)
        if (node is md.Text)
          TextSpan(text: node.text.replaceAll('\n', ' '), style: style)
        else if (node is md.Element)
          inline(node, width, style, depth),
    ];
  }

  InlineSpan inline(md.Element node, double width, TextStyle style, int depth) {
    final children = node.children ?? const <md.Node>[];
    switch (node.tag) {
      case 'br':
        return const TextSpan(text: '\n');
      case 'strong':
        style = style.copyWith(fontWeight: FontWeight.w700);
      case 'em':
        style = style.copyWith(fontStyle: FontStyle.italic);
      case 'del':
        style = style.copyWith(decoration: TextDecoration.lineThrough);
      case 'code':
        return TextSpan(
          text: node.textContent,
          style: style.copyWith(
            fontFamily: 'monospace',
            backgroundColor: colors.surfaceContainerHighest,
          ),
        );
      case 'img':
        // Alt text only: release metadata cannot trigger remote/local requests.
        return TextSpan(
          text: node.attributes['alt'] ?? '',
          style: style.copyWith(fontStyle: FontStyle.italic),
        );
      case 'input':
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Semantics(
            checked: node.attributes.containsKey('checked'),
            child: Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                border: Border.all(color: colors.onSurfaceVariant, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: node.attributes.containsKey('checked')
                  ? AppIcon(
                      AppIconAssets.systemCheck,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    )
                  : null,
            ),
          ),
        );
      case 'a':
        final uri = releaseNotesWebUri(node.attributes['href']);
        if (uri != null) {
          return WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: _NotesLink(
                uri: uri,
                onOpen: onOpenLink,
                child: Text.rich(
                  TextSpan(
                    children: spans(
                      children,
                      width,
                      style.copyWith(
                        color: colors.primary,
                        decoration: TextDecoration.underline,
                      ),
                      depth + 1,
                    ),
                  ),
                  style: style,
                  // WidgetSpan already applies the paragraph's text scale to
                  // embedded widgets. Its child must not apply it twice.
                  textScaler: TextScaler.noScaling,
                ),
              ),
            ),
          );
        }
    }
    return TextSpan(children: spans(children, width, style, depth + 1));
  }
}

class _NotesLink extends StatefulWidget {
  const _NotesLink({
    required this.uri,
    required this.onOpen,
    required this.child,
  });
  final Uri uri;
  final ValueChanged<Uri> onOpen;
  final Widget child;

  @override
  State<_NotesLink> createState() => _NotesLinkState();
}

class _NotesLinkState extends State<_NotesLink> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      link: true,
      child: AppTooltip(
        message: widget.uri.toString(),
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          },
          child: InkWell(
            hoverDuration: AppMotion.of(context).duration(
              full: const Duration(milliseconds: 50),
              reduced: const Duration(milliseconds: 40),
            ),
            onTap: () => widget.onOpen(widget.uri),
            onFocusChange: (focused) {
              setState(() => _focused = focused);
              if (focused) {
                unawaited(Scrollable.ensureVisible(context, alignment: .5));
              }
            },
            borderRadius: BorderRadius.circular(3),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: _focused ? colors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
