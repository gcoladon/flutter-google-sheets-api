import 'package:flutter/material.dart';
import 'package:gsheets/gsheets.dart';
import 'package:sheets_backend/configs/secrets.dart';
import 'package:sheets_backend/providers/google_sheets_provider.dart';
import 'package:sheets_backend/views/app.dart';
import 'package:sheets_backend/views/generic.dart';
import 'package:logging/logging.dart';

void main() async {
  final provider = GoogleSheetsProvider(credentials);

  // Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  const useGeneric = true;

  if (useGeneric) {
    final List<String> tables = [];
    final Map<String, List<String>> columns = {};
    final Map<String, List<String>> relations = {};

    final gsheets = GSheets(credentials);
    final ss = await gsheets.spreadsheet(sheetId);
    final ssTitle = ss.data.properties.title ?? "Unknown";

    for (final sheet in ss.sheets) {
      final title = sheet.title;
      columns[title] = await sheet.values.row(1);

      if (!title.contains("_")) {
        tables.add(title);
      } else {
        for (final member in title.split("_")) {
          if (!relations.containsKey(member)) {
            relations[member] = [];
          }
          relations[member]!.add(title);
        }
      }
    }
    // print ("Found relations: $relations");
    gsheets.close();

    await provider.initializeForWorksheet(sheetId);

    runApp(GenericApp(
        provider: provider,
        appName: ssTitle,
        tables: tables,
        columns: columns,
        relations: relations));
  } else {
    await provider.initializeForWorksheet(sheetId);

    runApp(SheetsApp(
      provider: provider,
    ));
  }
}
