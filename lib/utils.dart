import 'dart:developer';
import 'dart:math' as dart_math;
import 'package:flutter/rendering.dart';
import 'package:flutter/src/widgets/actions.dart';

class SelectionComponents {
  Rect baseCaret;
  Rect extentCaret;
  List<Rect> selectionRects;
  int baseOffset;
  int extentOffset;
  SelectionComponents(this.baseCaret, this.extentCaret, this.baseOffset,
      this.extentOffset, this.selectionRects);
}

class SelectionAction {
  late List<SelectionComponents> selectionComponents;
  bool isDelete;
  SelectionAction(
      List<SelectionComponents> inSelectionComponents, this.isDelete) {
    selectionComponents = [...inSelectionComponents];
  }
}

class SelectionActionStack {
  SelectionAction emptySel = SelectionAction([], false);
  List<SelectionAction> _selectionActions = [];
  int _index = -1;
  SelectionActionStack();

  SelectionAction get curr => _selectionActions[_index];
  void push(SelectionAction selectionAction) {
    cutStack();
    _selectionActions.add(selectionAction);
    _index += 1;
  }

  SelectionAction undo() {
    log("Undo $_index");
    _index -= 1;
    return (_index != -1) ? _selectionActions[_index] : emptySel;
  }

  SelectionAction redo() {
    log("Redo ${_index + 1}");
    _index += 1;
    return _selectionActions[_index];
  }

  bool anymoreUndo() {
    return _index >= 0;
  }

  bool anymoreRedo() {
    return _index < _selectionActions.length - 1;
  }

  printStackLens() {
    log('stack element lengths: ');
    for (final selcomps in _selectionActions) {
      log(selcomps.selectionComponents.length.toString());
    }
  }

  void cutStack() {
    List<SelectionAction> _newSelectionActions = [];
    for (int i = 0; i <= _index; i++) {
      _newSelectionActions.add(_selectionActions[i]);
    }
    _selectionActions = _newSelectionActions;
  }

  void clear() {
    _selectionActions = [];
  }
}

class Utils {
  static const caretProximityThres = 5;
  static const barProximityThres = 2;
  static List getCaretRectsAndOffsets(
      TextSelection selection, RenderParagraph renderParagraph) {
    final caretExtentOffset =
        renderParagraph.getOffsetForCaret(selection.extent, Rect.zero);
    final caretHeight =
        1.5 * (renderParagraph.getFullHeightForCaret(selection.extent)!);
    final caretBaseOffset =
        renderParagraph.getOffsetForCaret(selection.base, Rect.zero);
    return [
      Rect.fromLTWH(caretBaseOffset.dx - 1, caretBaseOffset.dy, 2, caretHeight),
      Rect.fromLTWH(
          caretExtentOffset.dx - 1, caretExtentOffset.dy, 2, caretHeight),
      selection.baseOffset,
      selection.extentOffset
    ];
  }

  static TextSelection getSelectedWord(
      Offset localPosition, RenderParagraph renderParagraph, String text) {
    List<String> words = text.split(' ');
    int _baseOffset = 0;
    int _extentOffset = text.length;
    int fingerPoint =
        renderParagraph.getPositionForOffset(localPosition).offset;
    log(fingerPoint.toString());
    for (final word in words) {
      if (_baseOffset + word.length > fingerPoint) {
        _extentOffset = _baseOffset + word.length;
        break;
      }
      _baseOffset += (word.length + 1);
    }
    return TextSelection(baseOffset: _baseOffset, extentOffset: _extentOffset);
  }

  static List getCloseSelectionIndex(Offset localPosition,
      RenderParagraph renderParagraph, List<SelectionComponents> selections) {
    int fingerPoint =
        renderParagraph.getPositionForOffset(localPosition).offset;
    log('fingerpoint: ' + fingerPoint.toString());
    int selectionIndex = -1;
    bool editingBaseCaret = false;
    for (final sel in selections) {
      log('selection vals: ' +
          sel.baseOffset.toString() +
          ', ' +
          sel.extentOffset.toString());
      if ((sel.baseOffset - fingerPoint).abs() < caretProximityThres) {
        selectionIndex = selections.indexOf(sel);
        editingBaseCaret = true;
        log('close to base caret');
      } else if ((sel.extentOffset - fingerPoint).abs() < caretProximityThres) {
        selectionIndex = selections.indexOf(sel);
        log('close to extent caret');
      }
    }
    return [selectionIndex, editingBaseCaret];
  }


  static List getCloseSelectionBarIndex(Offset localPosition,
      RenderParagraph renderParagraph, List<SelectionComponents> selections) {
    int fingerPoint =
        renderParagraph.getPositionForOffset(localPosition).offset;
    log('fingerpoint: ' + fingerPoint.toString());
    int selectionIndex = -1;
    bool editingBaseCaret = false;
    for (final sel in selections) {
      log('selection vals: ' +
          sel.baseOffset.toString() +
          ', ' +
          sel.extentOffset.toString());
      if ((sel.baseOffset - fingerPoint).abs() < barProximityThres) {
        selectionIndex = selections.indexOf(sel);
        editingBaseCaret = true;
        log('close to base caret');
      } else if ((sel.extentOffset - fingerPoint).abs() < barProximityThres) {
        selectionIndex = selections.indexOf(sel);
        log('close to extent caret');
      }
    }
    return [selectionIndex, editingBaseCaret];
  }

  static TextSelection getNewTextSelection(SelectionComponents editingSelection,
      int fingerPoint, bool isEditingBaseCaret) {
    late TextSelection newTextSelection;
    if (isEditingBaseCaret) {
      newTextSelection = TextSelection(
          baseOffset: dart_math.min(fingerPoint, editingSelection.extentOffset),
          extentOffset:
              dart_math.max(fingerPoint, editingSelection.extentOffset));
    } else {
      newTextSelection = TextSelection(
          baseOffset: dart_math.min(editingSelection.baseOffset, fingerPoint),
          extentOffset:
              dart_math.max(editingSelection.baseOffset, fingerPoint));
    }
    return newTextSelection;
  }

  static List<Rect> computeRectsForSelection(
      TextSelection textSelection, RenderParagraph renderParagraph) {
    final textBoxes = renderParagraph.getBoxesForSelection(textSelection);
    return textBoxes.map((e) => e.toRect()).toList();
  }

  static SelectionComponents getSelectionComponent(
      TextSelection textSelection, RenderParagraph renderParagraph) {
    final selectionRects =
        computeRectsForSelection(textSelection, renderParagraph);
    List caretOffsets =
        Utils.getCaretRectsAndOffsets(textSelection, renderParagraph);
    SelectionComponents selection = SelectionComponents(caretOffsets[0],
        caretOffsets[1], caretOffsets[2], caretOffsets[3], selectionRects);
    return selection;
  }

  static List<SelectionComponents> collapseSelections(
      List<SelectionComponents> selections, RenderParagraph renderParagraph) {
    List<SelectionComponents> sels = [];
    int L = selections.length;
    for (int i = 0; i < L; i++) {
      bool droppable = false;
      for (int j = i + 1; j < L; j++) {
        if ((selections[j].baseOffset < selections[i].baseOffset &&
                selections[i].baseOffset < selections[j].extentOffset) ||
            (selections[j].baseOffset < selections[i].extentOffset &&
                selections[i].extentOffset < selections[j].extentOffset)) {
          log('debug branch: 1');
          int newBaseOffset =
              dart_math.min(selections[i].baseOffset, selections[j].baseOffset);
          int newExtentOffset = dart_math.max(
              selections[i].extentOffset, selections[j].extentOffset);
          selections[j] = getSelectionComponent(
              getNewTextSelection(selections[j], newBaseOffset, true),
              renderParagraph);
          selections[j] = getSelectionComponent(
              getNewTextSelection(selections[j], newExtentOffset, false),
              renderParagraph);
          droppable = true;
          break;
        } else if (selections[j].baseOffset > selections[i].baseOffset &&
            selections[i].extentOffset > selections[j].extentOffset) {
          selections.removeAt(j);
          L -= 1;
        }
      }
      if (droppable) {
        continue;
      }
      sels.add(selections[i]);
    }
    return sels;
  }
}

class SelectionPainter extends CustomPainter {
  SelectionPainter({
    required Color color,
    required List<Rect> rects,
    bool fill = true,
  })  : _rects = rects,
        _fill = fill,
        _paint = Paint()..color = color;

  final bool _fill;
  final List<Rect> _rects;
  final Paint _paint;

  @override
  void paint(Canvas canvas, Size size) {
    _paint.style = _fill ? PaintingStyle.fill : PaintingStyle.stroke;
    for (final rect in _rects) {
      canvas.drawRect(rect, _paint);
    }
  }

  @override
  bool shouldRepaint(SelectionPainter oldDelegate) {
    return true;
  }
}

class CaretPainter extends SelectionPainter {
  CaretPainter(
      {required Color color, required List<Rect> rects, bool fill = true})
      : super(color: color, rects: rects, fill: fill);
  @override
  void paint(Canvas canvas, Size size) {
    _paint.style = PaintingStyle.fill;
    for (final rect in _rects) {
      canvas.drawCircle(rect.bottomCenter+ const Offset(0, -9.0), 5, _paint);
    }
    super.paint(canvas, size);
  }
}
