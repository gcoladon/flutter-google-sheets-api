import 'package:flutter/material.dart';
import 'package:crutter/misc/string.dart';
import 'package:crutter/providers/google_sheets_provider.dart';
import 'package:logging/logging.dart';

class ListPage extends StatefulWidget {
  final GoogleSheetsProvider provider;
  final String sheet;
  const ListPage({
    required this.provider,
    required this.sheet,
    Key? key,
  }) : super(key: key);

  @override
  _ListPageState createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  Future<List<Map<String, String>>> get query =>
      widget.provider.getRows(widget.sheet);
  final log = Logger("optivore");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("All " + widget.sheet.capitalize().pluralize()),
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: query,
        builder: (context, snapshot) {
          log.info("Building ${widget.sheet} list page");
          if (snapshot.hasError) {
            return Center(
              child: Text(
                  'Error fetching data for ${widget.sheet}: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final rows = snapshot.data!;
          rows.sort((r1, r2) => r1["name"]!.compareTo(r2["name"]!));

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) => ItemCard(
                      fields: rows[index],
                      onDelete: () async {
                        await widget.provider.deleteRow(widget.sheet, index);
                        setState(() {});
                      },
                      onEdit: () async {
                        await Navigator.of(context).pushNamed(
                            '/${widget.sheet}/edit',
                            arguments: int.parse(rows[index]['id']!));
                        setState(() {});
                      },
                      onShow: () async {
                        await Navigator.of(context).pushNamed(
                            '/${widget.sheet}/show',
                            arguments: int.parse(rows[index]['id']!));
                        setState(() {});
                      },
                    )),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).pushNamed('/${widget.sheet}/new');
        },
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }
}

class ItemCard extends StatelessWidget {
  final Map<String, String> fields;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onShow;

  const ItemCard({
    required this.fields,
    required this.onDelete,
    required this.onEdit,
    required this.onShow,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Perform some action when the card is tapped
        onShow();
      },
      child: Card(
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
              Center(
                child: IconButton(
                  icon: const Icon(
                    Icons.edit,
                    color: Colors.blue,
                  ),
                  onPressed: onEdit,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Container(
                  color: Colors.grey,
                  height: 20.0,
                  width: 2.0,
                ),
              ),
              Center(
                child: IconButton(
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.red,
                  ),
                  onPressed: onDelete,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
