import 'package:gsheets/gsheets.dart';
import 'package:logging/logging.dart';

class MissingDataException implements Exception {
  final String message;

  MissingDataException(this.message);

  @override
  String toString() => 'MissingDataException: $message';
}

class GoogleSheetsProvider {
  final GSheets _gsheets;

  final Map<String, Worksheet> _worksheets = {};

  final log = Logger("gsheets");

  GoogleSheetsProvider(String credentials) : _gsheets = GSheets(credentials);

  Future<void> initializeForWorksheet(String spreadsheetId) async {
    final excel = await _gsheets.spreadsheet(spreadsheetId);

    for (final sheet in excel.sheets) {
      _worksheets[sheet.title] = sheet;
    }
  }

  //
  // generic methods!
  //

  Future<List<Map<String, String>>> getRows(String sheet) async {
    log.info("getRows($sheet) called");
    final headerAndRows = (await _worksheets[sheet]!.values.allRows()).toList();
    final headerRow = headerAndRows.removeAt(0);
    final betterValues = [
      for (final dataRow in headerAndRows) Map.fromIterables(headerRow, dataRow)
    ];
    return betterValues;
  }

  Future<Map<String, String>> getRow(String sheet, int id) async {
    log.info("getRow($sheet, $id) called");
    final headerAndRows = (await _worksheets[sheet]!.values.allRows()).toList();
    final headerRow = headerAndRows.removeAt(0);
    for (final dataRow in headerAndRows) {
      final thisMap = Map.fromIterables(headerRow, dataRow);
      if (int.parse(thisMap["id"]!) == id) {
        return thisMap;
      }
    }
    throw MissingDataException('getRow could not find id=$id in sheet $sheet');
  }

  Future<bool> deleteRow(String sheet, int id) async {
    log.info("deleteRow($sheet, $id) called");
    final headerAndRows = (await _worksheets[sheet]!.values.allRows()).toList();
    final headerRow = headerAndRows.removeAt(0);
    for (final dataRow in headerAndRows.asMap().entries) {
      final thisMap = Map.fromIterables(headerRow, dataRow.value);
      if (int.parse(thisMap['id']!) == id) {
        return _worksheets[sheet]!.deleteRow(dataRow.key);
      }
    }
    throw MissingDataException(
        'deleteRow could not find id=$id in sheet $sheet');
  }

  Future<bool> addRow(String sheet, Map<String, String> fields) {
    log.info("addRow($sheet, $fields) called");
    return _worksheets[sheet]!.values.appendRow(fields.values.toList());
  }

  Future<bool> updateRow(String sheet, Map<String, String> fields) async {
    log.info("updateRow($sheet, $fields) called");
    final headerAndRows = (await _worksheets[sheet]!.values.allRows()).toList();
    final headerRow = headerAndRows.removeAt(0);
    for (final dataRow in headerAndRows.asMap().entries) {
      final thisMap = Map.fromIterables(headerRow, dataRow.value);
      if (thisMap['id']! == fields['id']!) {
        return _worksheets[sheet]!
            .values
            .insertRow(dataRow.key, fields.values.toList());
      }
    }
    throw MissingDataException(
        'updateRow could not find id=${fields["id"]} in sheet $sheet');
  }

  Future<Map<String, Map<int, String>>> getRelations(String sheet, int id,
      Map<String, List<String>> tableToJoinTableMap) async {
    log.info("getReltions($sheet, $id) called");
    // resultMap will contain {"diet": {1: "foo", 2: "bar"}, "goal": {3: 4:}}
    final Map<String, Map<int, String>> resultMap = {};

    if (tableToJoinTableMap.containsKey(sheet)) {
      // this means that this table takes part in at least one join table.
      for (var reltable in tableToJoinTableMap[sheet]!) {
        final halves = reltable.split("_");
        final otherGuy = halves[0] == sheet ? halves[1] : halves[0];
        final relTableRows = await getRows(reltable);
        for (final relRow in relTableRows) {
          if (int.parse(relRow['${sheet}_id']!) == id) {
            resultMap[otherGuy] ??= {};
            resultMap[otherGuy]![int.parse(relRow['${otherGuy}_id']!)] =
                relRow['${otherGuy}_name']!;
          }
        }
      }
    }
    return resultMap;
  }
}
