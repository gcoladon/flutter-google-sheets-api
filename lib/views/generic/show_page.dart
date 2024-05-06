import 'package:flutter/material.dart';
import 'package:crutter/providers/google_sheets_provider.dart';
import 'package:crutter/misc/string.dart';
import 'package:logging/logging.dart';

class ShowPage extends StatefulWidget {
  final GoogleSheetsProvider provider;
  final String sheet;
  final int id;
  final Map<String, List<String>> relations;
  const ShowPage(
      {required this.provider,
      required this.sheet,
      required this.id,
      required this.relations,
      Key? key})
      : super(key: key);

  @override
  _ShowPageState createState() => _ShowPageState();
}

class _ShowPageState extends State<ShowPage> {
  Map<String, int> dropdownSelections = {};
  final log = Logger("optivore");

  Future<Map<String, String>> _futureEnt() =>
      widget.provider.getRow(widget.sheet, widget.id);
  Future<Map<String, Map<int, String>>> _futureRels() =>
      widget.provider.getRelations(widget.sheet, widget.id, widget.relations);
  Future<Map<String, Map<int, String>>> _futureNonRels() async {
    Map<String, Map<int, String>> notJoinedYet = {};

    if (widget.relations.containsKey(widget.sheet)) {
      // this table takes part in join tables! Let's GOOO
      final alreadyRelated = await _futureRels();
      for (var joinTable in widget.relations[widget.sheet]!) {
        final halves = joinTable.split("_");
        final otherGuy = halves[0] == widget.sheet ? halves[1] : halves[0];
        if (alreadyRelated.containsKey(otherGuy)) {
          final actuallyRelated = alreadyRelated[otherGuy]!;
          final otherTableRows = await widget.provider.getRows(otherGuy);
          for (var potentialRel in otherTableRows) {
            final potentialRelId = int.parse(potentialRel['id']!);
            if (!actuallyRelated.containsKey(potentialRelId)) {
              notJoinedYet[otherGuy] ??= {};
              notJoinedYet[otherGuy]![potentialRelId] = potentialRel['name']!;
            }
          }
        } else {
          final otherTableRows = await widget.provider.getRows(otherGuy);
          notJoinedYet[otherGuy] ??= {};
          for (var potentialRel in otherTableRows) {
            final potentialRelId = int.parse(potentialRel['id']!);
            notJoinedYet[otherGuy]![potentialRelId] = potentialRel['name']!;
          }
        }
      }
    }
    return notJoinedYet;
  }

  Future<List<dynamic>> _combine() async {
    return await Future.wait([
      _futureEnt(),
      _futureRels(),
      _futureNonRels(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width;
    return Scaffold(
        appBar: AppBar(
          title: Text("Show ${widget.sheet}"),
        ),
        body: FutureBuilder(
            future: _combine(),
            builder: (context, snapshot) {
              log.info("Building ${widget.sheet} list page");
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                      'Error fetching data for ${widget.sheet}: ${snapshot.error}'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final results = snapshot.data! as List<dynamic>;
              final fields = results[0]! as Map<String, String>;
              final rels = results[1]! as Map<String, Map<int, String>>;
              final nonrels = results[2]! as Map<String, Map<int, String>>;
              List<Widget> children = [];
              children.add(IdNameCard(fields: fields));
              Map<String, List<DropdownMenuItem<int>>> dropdownItems = {};

              for (var table in nonrels.entries) {
                children.add(Text(table.key.capitalize().pluralize(),
                    style: const TextStyle(
                        fontSize: 16.0, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.start));

                if (rels.containsKey(table.key)) {
                  final sortedRels = (rels[table.key]!.entries).toList();
                  sortedRels.sort((e1, e2) => e1.value.compareTo(e2.value));

                  for (var entry in sortedRels) {
                    children.add(GestureDetector(
                        onTap: () async {
                          await Navigator.of(context).pushNamed(
                              '/${table.key}/show',
                              arguments: entry.key);
                          // print("trying to redirect!");
                          setState(() {});
                        },
                        child: IdNameCard(
                            fields: {"id": '', "name": entry.value})));
                  }
                }

                final sortedNonRels = (table.value.entries).toList();
                sortedNonRels.sort((e1, e2) => e1.value.compareTo(e2.value));

                dropdownItems[table.key] = [];
                for (var nr in sortedNonRels) {
                  dropdownItems[table.key]!.add(DropdownMenuItem(
                      value: nr.key, child: Text(nr.value.upTo(35))));
                }
                children.add(Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DropdownButton(
                      value: dropdownSelections[table.key],
                      hint: Text('Select ${table.key} to add..'),
                      onChanged: (newValue) {
                        setState(() {
                          dropdownSelections[table.key] = newValue as int;
                        });
                      },
                      items: dropdownItems[table.key],
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (widget.relations[widget.sheet]!
                          .contains("${widget.sheet}_${table.key}")) {
                          final joinTable = "${widget.sheet}_${table.key}";
                          await widget.provider.addRow(
                            joinTable,
                            {
                              "id": '',
                              "${widget.sheet}_id": fields['id']!,
                              "${widget.sheet}_name": fields['name']!,
                              "${table.key}_id":
                              dropdownSelections[table.key].toString(),
                              "${table.key}_name":
                              table.value[dropdownSelections[table.key]]!,
                            },
                          );
                        } else {
                          final joinTable = "${table.key}_${widget.sheet}";
                          await widget.provider.addRow(
                            joinTable,
                            {
                              "id": '',
                              "${table.key}_id":
                              dropdownSelections[table.key].toString(),
                              "${table.key}_name":
                              table.value[dropdownSelections[table.key]]!,
                              "${widget.sheet}_id": fields['id']!,
                              "${widget.sheet}_name": fields['name']!,
                            },
                          );
                        }
                        Navigator.of(context).pop();
                      },
                      child: Text('Add'),
                    ),
                  ],
                ));
              }

              return Center(
                  child: SizedBox(
                width: size > 400 ? 400 : size,
                //   child: Column(
                //       mainAxisAlignment: MainAxisAlignment.start,
                //       crossAxisAlignment: CrossAxisAlignment.stretch,
                //       children: children),
                // ),
                child: ListView.builder(
                    itemCount: children.length,
                    itemBuilder: (context, index) => children[index]),
              ));
            }));
  }
}

class IdNameCard extends StatelessWidget {
  final Map<String, String> fields;

  const IdNameCard({
    required this.fields,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (fields['id'] == "") {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      fields['name']!,
                      style: const TextStyle(
                          fontSize: 20.0, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.start,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      fields['name']!,
                      style: const TextStyle(
                          fontSize: 20.0, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.start,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
