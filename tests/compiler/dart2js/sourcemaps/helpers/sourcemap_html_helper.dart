// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Helper for creating HTML visualization of the source map information
/// generated by a [SourceMapProcessor].

library sourcemap.html.helper;

import 'dart:convert';
import 'dart:math' as Math;

import 'package:compiler/src/io/source_file.dart';
import 'package:compiler/src/io/source_information.dart';
import 'package:compiler/src/js/js.dart' as js;

import 'colors.dart';
import 'sourcemap_helper.dart';
import 'sourcemap_html_templates.dart';
import 'html_parts.dart';

/// Truncate [input] to [length], adding '...' if truncated.
String truncate(String input, int length) {
  if (input.length > length) {
    return '${input.substring(0, length - 3)}...';
  }
  return input;
}

const int HUE_COUNT = 24;

/// Returns the [index]th color for visualization.
HSV toColor(int index) {
  double h = 360.0 * (index % HUE_COUNT) / HUE_COUNT;
  double v = 1.0;
  double s = 0.5;
  return new HSV(h, s, v);
}

/// Return the CSS color value for the [index]th color.
String toColorCss(int index) {
  return toColor(index).toCss;
}

/// Return the CSS color value for the [index]th span.
String toPattern(int index) {
  /// Use gradient on spans to visually identify consecutive spans mapped to the
  /// same source location.
  HSV startColor = toColor(index);
  HSV endColor = new HSV(startColor.h, startColor.s + 0.4, startColor.v - 0.2);
  return 'linear-gradient(to right, ${startColor.toCss}, ${endColor.toCss})';
}

/// Return the html for the [index] line number. If [width] is provided, shorter
/// line numbers will be prefixed with spaces to match the width.
String lineNumber(int index,
    {int width, bool useNbsp: false, String className}) {
  if (className == null) {
    className = 'lineNumber';
  }
  String text = '${index + 1}';
  String padding = useNbsp ? '&nbsp;' : ' ';
  if (width != null && text.length < width) {
    text = (padding * (width - text.length)) + text;
  }
  return '<span class="$className">$text$padding</span>';
}

/// Return the html escaped [text].
String escape(String text) {
  return const HtmlEscape().convert(text);
}

/// Information needed to generate HTML for a single [SourceMapInfo].
class SourceMapHtmlInfo {
  final SourceMapInfo sourceMapInfo;
  final CodeProcessor codeProcessor;
  final SourceLocationCollection sourceLocationCollection;

  SourceMapHtmlInfo(
      this.sourceMapInfo, this.codeProcessor, this.sourceLocationCollection);

  String toString() {
    return sourceMapInfo.toString();
  }
}

/// A collection of source locations.
///
/// Used to index source locations for visualization and linking.
class SourceLocationCollection {
  List<SourceLocation> sourceLocations = [];
  Map<SourceLocation, int> sourceLocationIndexMap;

  SourceLocationCollection([SourceLocationCollection parent])
      : sourceLocationIndexMap =
            parent == null ? {} : parent.sourceLocationIndexMap;

  int registerSourceLocation(SourceLocation sourceLocation) {
    return sourceLocationIndexMap.putIfAbsent(sourceLocation, () {
      sourceLocations.add(sourceLocation);
      return sourceLocationIndexMap.length;
    });
  }

  int getIndex(SourceLocation sourceLocation) {
    return sourceLocationIndexMap[sourceLocation];
  }
}

abstract class CssColorScheme {
  String singleLocationToCssColor(int id);

  String multiLocationToCssColor(List<int> ids);

  bool get showLocationAsSpan;
}

class CustomColorScheme implements CssColorScheme {
  final bool showLocationAsSpan;
  final Function single;
  final Function multi;

  CustomColorScheme(
      {this.showLocationAsSpan: false,
      String this.single(int id),
      String this.multi(List<int> ids)});

  String singleLocationToCssColor(int id) => single != null ? single(id) : null;

  String multiLocationToCssColor(List<int> ids) =>
      multi != null ? multi(ids) : null;
}

class PatternCssColorScheme implements CssColorScheme {
  const PatternCssColorScheme();

  bool get showLocationAsSpan => true;

  String singleLocationToCssColor(int index) {
    return "background:${toPattern(index)};";
  }

  String multiLocationToCssColor(List<int> indices) {
    StringBuffer sb = new StringBuffer();
    double delta = 100.0 / (indices.length);
    double position = 0.0;

    void addColor(String color) {
      sb.write(', ${color} ${position.toInt()}%');
      position += delta;
      sb.write(', ${color} ${position.toInt()}%');
    }

    for (int index in indices) {
      addColor('${toColorCss(index)}');
    }
    return 'background: linear-gradient(to right${sb}); '
        'background-size: 10px 10px;';
  }
}

class SingleColorScheme implements CssColorScheme {
  const SingleColorScheme();

  bool get showLocationAsSpan => false;

  String singleLocationToCssColor(int index) {
    return "background:${toColorCss(index)};";
  }

  String multiLocationToCssColor(List<int> indices) {
    StringBuffer sb = new StringBuffer();
    double delta = 100.0 / (indices.length);
    double position = 0.0;

    void addColor(String color) {
      sb.write(', ${color} ${position.toInt()}%');
      position += delta;
      sb.write(', ${color} ${position.toInt()}%');
    }

    for (int index in indices) {
      addColor('${toColorCss(index)}');
    }
    return 'background: linear-gradient(to bottom${sb}); '
        'background-size: 10px 3px;';
  }
}

/// Processor that computes the HTML representation of a block of JavaScript
/// code and collects the source locations mapped in the code.
class CodeProcessor {
  int lineIndex = 0;
  final String name;
  int currentJsSourceOffset = 0;
  final SourceLocationCollection collection;
  final Map<int, List<SourceLocation>> codeLocations = {};
  final CssColorScheme colorScheme;

  CodeProcessor(this.name, this.collection,
      {this.colorScheme: const PatternCssColorScheme()});

  void addSourceLocation(int targetOffset, SourceLocation sourceLocation) {
    codeLocations.putIfAbsent(targetOffset, () => []).add(sourceLocation);
    collection.registerSourceLocation(sourceLocation);
  }

  String convertToHtml(String text) {
    List<Annotation> annotations = <Annotation>[];
    codeLocations.forEach((int codeOffset, List<SourceLocation> locations) {
      for (SourceLocation location in locations) {
        if (location != null) {
          annotations.add(new Annotation(
              collection.getIndex(location), codeOffset, location.shortText));
        }
      }
    });
    return convertAnnotatedCodeToHtml(text, annotations,
        colorScheme: colorScheme,
        elementScheme: new HighlightLinkScheme(name),
        windowSize: 3);
  }
}

class ElementScheme {
  const ElementScheme();

  String getName(int id, Set<int> ids) => null;
  String getHref(int id, Set<int> ids) => null;
  String onClick(int id, Set<int> ids) => null;
  String onMouseOver(int id, Set<int> ids) => null;
  String onMouseOut(int id, Set<int> ids) => null;
}

class HighlightLinkScheme implements ElementScheme {
  final String name;

  HighlightLinkScheme(this.name);

  @override
  String getName(int id, Set<int> indices) {
    return 'js$id';
  }

  @override
  String getHref(int id, Set<int> indices) {
    return "#${id}";
  }

  @override
  String onClick(int id, Set<int> indices) {
    return "show(\'$name\');";
  }

  @override
  String onMouseOut(int id, Set<int> indices) {
    return "highlight([]);";
  }

  @override
  String onMouseOver(int id, Set<int> indices) {
    String onmouseover = indices.map((i) => '\'$i\'').join(',');
    return "highlight([${onmouseover}]);";
  }
}

String convertAnnotatedCodeToHtml(String code, Iterable<Annotation> annotations,
    {CssColorScheme colorScheme: const SingleColorScheme(),
    ElementScheme elementScheme: const ElementScheme(),
    int windowSize}) {
  StringBuffer htmlBuffer = new StringBuffer();
  List<CodeLine> lines = convertAnnotatedCodeToCodeLines(code, annotations,
      windowSize: windowSize);
  int lineNoWidth;
  if (lines.isNotEmpty) {
    lineNoWidth = '${lines.last.lineNo + 1}'.length;
  }
  HtmlPrintContext context = new HtmlPrintContext(
      lineNoWidth: lineNoWidth,
      getAnnotationData: createAnnotationDataFunction(
          colorScheme: colorScheme, elementScheme: elementScheme));
  for (CodeLine line in lines) {
    line.printHtmlOn(htmlBuffer, context);
  }
  return htmlBuffer.toString();
}

List<CodeLine> convertAnnotatedCodeToCodeLines(
    String code, Iterable<Annotation> annotations,
    {int startLine, int endLine, int windowSize, Uri uri}) {
  List<CodeLine> lines = <CodeLine>[];
  CodeLine currentLine;
  final List<Annotation> currentAnnotations = <Annotation>[];
  int offset = 0;
  int lineIndex = 0;
  int firstLine;
  int lastLine;

  void addCode(String code) {
    if (currentLine != null) {
      currentLine.codeBuffer.write(code);
      currentLine.codeParts
          .add(new CodePart(currentAnnotations.toList(), code));
      currentAnnotations.clear();
    }
  }

  void addAnnotations(List<Annotation> annotations) {
    currentAnnotations.addAll(annotations);
    if (currentLine != null) {
      currentLine.annotations.addAll(annotations);
    }
  }

  void beginLine(int currentOffset) {
    lines
        .add(currentLine = new CodeLine(lines.length, currentOffset, uri: uri));
  }

  void endCurrentLocation() {
    if (currentAnnotations.isNotEmpty) {
      addCode('');
    }
  }

  void addSubstring(int until, {bool isFirst: false, bool isLast: false}) {
    if (until <= offset) return;
    if (offset >= code.length) return;

    String substring = code.substring(offset, until);
    bool first = true;

    if (isLast) {
      lastLine = lineIndex;
    }
    int localOffset = 0;
    if (isFirst) {
      beginLine(offset + localOffset);
    }
    for (String line in substring.split('\n')) {
      if (!first) {
        endCurrentLocation();
        lineIndex++;
        beginLine(offset + localOffset);
      }
      addCode(line);
      first = false;
      localOffset += line.length + 1;
    }
    if (isFirst) {
      firstLine = lineIndex;
    }
    offset = until;
  }

  void insertAnnotations(List<Annotation> annotations) {
    endCurrentLocation();
    addAnnotations(annotations);
    if (annotations.last == null) {
      endCurrentLocation();
    }
  }

  Map<int, List<Annotation>> annotationMap = <int, List<Annotation>>{};
  for (Annotation annotation in annotations) {
    annotationMap
        .putIfAbsent(annotation.codeOffset, () => <Annotation>[])
        .add(annotation);
  }

  bool first = true;
  for (int codeOffset in annotationMap.keys.toList()..sort()) {
    List<Annotation> annotationList = annotationMap[codeOffset];
    addSubstring(codeOffset, isFirst: first);
    insertAnnotations(annotationList);
    first = false;
  }

  addSubstring(code.length, isFirst: first, isLast: true);
  endCurrentLocation();

  int start = startLine ?? 0;
  int end = endLine ?? lines.length - 1;
  if (lastLine == 0) lastLine = firstLine;
  if (windowSize != null) {
    start = Math.max(firstLine - windowSize, start);
    end = Math.min(lastLine + windowSize, end);
  }
  return lines.sublist(start, end);
}

/// Computes the HTML representation for a collection of JavaScript code blocks.
String computeJsHtml(Iterable<SourceMapHtmlInfo> infoList) {
  StringBuffer jsCodeBuffer = new StringBuffer();
  for (SourceMapHtmlInfo info in infoList) {
    String name = info.sourceMapInfo.name;
    String html = info.codeProcessor.convertToHtml(info.sourceMapInfo.code);
    String onclick = 'show(\'$name\');';
    jsCodeBuffer
        .write('<h3 onclick="$onclick">JS code for: ${escape(name)}</h3>\n');
    jsCodeBuffer.write('''
<pre>
$html
</pre>
''');
  }
  return jsCodeBuffer.toString();
}

/// Computes the HTML representation of the source mapping information for a
/// collection of JavaScript code blocks.
String computeJsTraceHtml(Iterable<SourceMapHtmlInfo> infoList) {
  StringBuffer jsTraceBuffer = new StringBuffer();
  for (SourceMapHtmlInfo info in infoList) {
    String name = info.sourceMapInfo.name;
    String jsTrace = computeJsTraceHtmlPart(
        info.sourceMapInfo.codePoints, info.sourceLocationCollection);
    jsTraceBuffer.write('''
<div name="$name" class="js-trace-buffer" style="display:none;">
<h3>Trace for: ${escape(name)}</h3>
$jsTrace
</div>
''');
  }
  return jsTraceBuffer.toString();
}

/// Computes the HTML information for the [info].
SourceMapHtmlInfo createHtmlInfo(
    SourceLocationCollection collection, SourceMapInfo info) {
  String name = info.name;
  SourceLocationCollection subcollection =
      new SourceLocationCollection(collection);
  CodeProcessor codeProcessor = new CodeProcessor(name, subcollection);
  for (js.Node node in info.nodeMap.nodes) {
    info.nodeMap[node]
        .forEach((int targetOffset, List<SourceLocation> sourceLocations) {
      for (SourceLocation sourceLocation in sourceLocations) {
        codeProcessor.addSourceLocation(targetOffset, sourceLocation);
      }
    });
  }
  return new SourceMapHtmlInfo(info, codeProcessor, subcollection);
}

/// Outputs a HTML file in [jsMapHtmlUri] containing an interactive
/// visualization of the source mapping information in [infoList] computed
/// with the [sourceMapProcessor].
void createTraceSourceMapHtml(Uri jsMapHtmlUri,
    SourceMapProcessor sourceMapProcessor, Iterable<SourceMapInfo> infoList) {
  SourceFileManager sourceFileManager = sourceMapProcessor.sourceFileManager;
  SourceLocationCollection collection = new SourceLocationCollection();
  List<SourceMapHtmlInfo> htmlInfoList = <SourceMapHtmlInfo>[];
  for (SourceMapInfo info in infoList) {
    htmlInfoList.add(createHtmlInfo(collection, info));
  }

  String jsCode = computeJsHtml(htmlInfoList);
  String dartCode = computeDartHtml(sourceFileManager, htmlInfoList);

  String jsTraceHtml = computeJsTraceHtml(htmlInfoList);
  outputJsDartTrace(jsMapHtmlUri, jsCode, dartCode, jsTraceHtml);
  print('Trace source map html generated: $jsMapHtmlUri');
}

/// Computes the HTML representation for the Dart code snippets referenced in
/// [infoList].
String computeDartHtml(
    SourceFileManager sourceFileManager, Iterable<SourceMapHtmlInfo> infoList) {
  StringBuffer dartCodeBuffer = new StringBuffer();
  for (SourceMapHtmlInfo info in infoList) {
    dartCodeBuffer.write(computeDartHtmlPart(info.sourceMapInfo.name,
        sourceFileManager, info.sourceLocationCollection));
  }
  return dartCodeBuffer.toString();
}

/// Computes the HTML representation for the Dart code snippets in [collection].
String computeDartHtmlPart(String name, SourceFileManager sourceFileManager,
    SourceLocationCollection collection,
    {bool showAsBlock: false}) {
  const int windowSize = 3;
  StringBuffer dartCodeBuffer = new StringBuffer();
  Map<Uri, Map<int, List<SourceLocation>>> sourceLocationMap = {};
  collection.sourceLocations.forEach((SourceLocation sourceLocation) {
    if (sourceLocation.sourceUri == null || sourceLocation.line == null) return;
    Map<int, List<SourceLocation>> uriMap =
        sourceLocationMap.putIfAbsent(sourceLocation.sourceUri, () => {});
    List<SourceLocation> lineList =
        uriMap.putIfAbsent(sourceLocation.line - 1, () => []);
    lineList.add(sourceLocation);
  });
  sourceLocationMap.forEach((Uri uri, Map<int, List<SourceLocation>> uriMap) {
    SourceFile sourceFile = sourceFileManager.getSourceFile(uri);
    if (sourceFile == null) {
      print('No source file for $uri');
      return;
    }
    StringBuffer codeBuffer = new StringBuffer();

    int firstLineIndex;
    int lastLineIndex;
    List<int> lineIndices = uriMap.keys.toList()..sort();
    int lineNoWidth;
    if (lineIndices.isNotEmpty) {
      lineNoWidth = '${lineIndices.last + windowSize + 1}'.length;
    }

    void flush() {
      if (firstLineIndex != null && lastLineIndex != null) {
        dartCodeBuffer.write('<h4>${uri.pathSegments.last}, '
            '${firstLineIndex - windowSize + 1}-'
            '${lastLineIndex + windowSize + 1}'
            '</h4>\n');
        dartCodeBuffer.write('<pre>\n');
        dartCodeBuffer.write('<p class="line">');
        for (int line = firstLineIndex - windowSize;
            line < firstLineIndex;
            line++) {
          if (line >= 0) {
            dartCodeBuffer.write('</p><p class="line">');
            dartCodeBuffer.write(lineNumber(line, width: lineNoWidth));
            dartCodeBuffer.write(sourceFile.kernelSource.getTextLine(line + 1));
          }
        }
        dartCodeBuffer.write(codeBuffer);
        for (int line = lastLineIndex + 1;
            line <= lastLineIndex + windowSize;
            line++) {
          if (line < sourceFile.lines) {
            dartCodeBuffer.write('</p><p class="line">');
            dartCodeBuffer.write(lineNumber(line, width: lineNoWidth));
            dartCodeBuffer.write(sourceFile.kernelSource.getTextLine(line + 1));
          }
        }
        dartCodeBuffer.write('</p>');
        dartCodeBuffer.write('</pre>\n');
        firstLineIndex = null;
        lastLineIndex = null;
      }
      codeBuffer.clear();
    }

    lineIndices.forEach((int lineIndex) {
      List<SourceLocation> locations = uriMap[lineIndex];
      if (lastLineIndex != null && lastLineIndex + windowSize * 4 < lineIndex) {
        flush();
      }
      if (firstLineIndex == null) {
        firstLineIndex = lineIndex;
      } else {
        for (int line = lastLineIndex + 1; line < lineIndex; line++) {
          codeBuffer.write('</p><p class="line">');
          codeBuffer.write(lineNumber(line, width: lineNoWidth));
          codeBuffer.write(sourceFile.kernelSource.getTextLine(line + 1));
        }
      }
      String line = sourceFile.kernelSource.getTextLine(lineIndex + 1);
      locations.sort((a, b) => a.offset.compareTo(b.offset));
      for (int i = 0; i < locations.length; i++) {
        SourceLocation sourceLocation = locations[i];
        int index = collection.getIndex(sourceLocation);
        int start = sourceLocation.column - 1;
        int end = line.length;
        if (i + 1 < locations.length) {
          end = locations[i + 1].column - 1;
        }
        if (i == 0) {
          codeBuffer.write('</p><p class="line">');
          codeBuffer.write(lineNumber(lineIndex, width: lineNoWidth));
          codeBuffer.write(line.substring(0, start));
        }
        codeBuffer
            .write('<a name="${index}" style="background:${toPattern(index)};" '
                'title="[${lineIndex + 1},${start + 1}]" '
                'onmouseover="highlight(\'$index\');" '
                'onmouseout="highlight();">');
        codeBuffer.write(line.substring(start, end));
        codeBuffer.write('</a>');
      }
      lastLineIndex = lineIndex;
    });

    flush();
  });
  String display = showAsBlock ? 'block' : 'none';
  return '''
<div name="$name" class="dart-buffer" style="display:$display;">
<h3>Dart code for: ${escape(name)}</h3>
${dartCodeBuffer}
</div>''';
}

/// Computes a HTML visualization of the [codePoints].
String computeJsTraceHtmlPart(
    List<CodePoint> codePoints, SourceLocationCollection collection) {
  StringBuffer buffer = new StringBuffer();
  buffer.write('<table style="width:100%;">');
  buffer.write('<tr><th>Node kind</th><th>JS code @ offset</th>'
      '<th>Dart code @ mapped location</th><th>file:position:name</th></tr>');
  codePoints.forEach((CodePoint codePoint) {
    String jsCode = truncate(codePoint.jsCode, 50);
    if (codePoint.sourceLocation != null) {
      int index = collection.getIndex(codePoint.sourceLocation);
      if (index != null) {
        String style = '';
        if (!codePoint.isMissing) {
          style = 'style="background:${toColorCss(index)};" ';
        }
        buffer.write('<tr $style'
            'name="trace$index" '
            'onmouseover="highlight([${index}]);"'
            'onmouseout="highlight([]);">');
      } else {
        buffer.write('<tr>');
        print('${codePoint.sourceLocation} not found in ');
        collection.sourceLocationIndexMap.keys
            .where((l) => l.sourceUri == codePoint.sourceLocation.sourceUri)
            .forEach((l) => print(' $l'));
      }
    } else {
      buffer.write('<tr>');
    }
    buffer.write('<td>${codePoint.kind}</td>');
    buffer.write('<td class="code">${jsCode}</td>');
    if (codePoint.sourceLocation == null) {
      //buffer.write('<td></td>');
    } else {
      String dartCode = truncate(codePoint.dartCode, 50);
      buffer.write('<td class="code">${dartCode}</td>');
      buffer.write('<td>${escape(codePoint.sourceLocation.shortText)}</td>');
    }
    buffer.write('</tr>');
  });
  buffer.write('</table>');

  return buffer.toString();
}
