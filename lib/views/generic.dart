import 'package:flutter/material.dart';
import 'package:crutter/providers/google_sheets_provider.dart';
import 'package:crutter/views/generic/list_page.dart';
import 'package:crutter/views/generic/new_page.dart';
import 'package:crutter/views/generic/edit_page.dart';
import 'package:crutter/views/generic/show_page.dart';

class GenericApp extends StatefulWidget {
  final GoogleSheetsProvider provider;
  final String appName;
  final List<String> tables;
  final Map<String, List<String>> columns;
  final Map<String, List<String>> relations;

  const GenericApp({
    required this.provider,
    required this.appName,
    required this.tables,
    required this.columns,
    required this.relations,
    Key? key,
  }) : super(key: key);

  @override
  State<GenericApp> createState() => _GenericAppState();
}

class _GenericAppState extends State<GenericApp> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page = ListPage(
        provider: widget.provider, sheet: widget.tables[selectedIndex]);

    return LayoutBuilder(builder: (context, constraints) {
      return MaterialApp(
          title: 'Generic Protosheets App',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
          ),
          onGenerateRoute: (RouteSettings settings) {
            final fields = settings.name!.split("/");
            final sheet = fields[1];
            final action = fields[2];

            if (action == "new") {
              return MaterialPageRoute(
                  builder: (context) =>
                      NewPage(provider: widget.provider, sheet: sheet));
            } else if (action == "show") {
              final int id = settings.arguments as int;
              return MaterialPageRoute(
                builder: (context) => ShowPage(
                    provider: widget.provider,
                    sheet: sheet,
                    id: id,
                    relations: widget.relations),
              );
            } else if (action == "edit") {
              final int index = settings.arguments as int;
              return MaterialPageRoute(
                builder: (context) => EditPage(
                    provider: widget.provider, sheet: sheet, id: index),
              );
            } else {
              throw UnimplementedError('no widget for ${settings.name}');
            }
          },
          home: Scaffold(
            appBar: AppBar(title: Text(widget.appName)),
            body: Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (var dest in widget.tables)
                        NavigationRailDestination(
                            icon: Icon(Icons.home), label: Text(dest))
                    ],
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (value) {
                      setState(() {
                        selectedIndex = value;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: Container(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: page,
                  ),
                ),
              ],
            ),
          ));
    });
  }
}
