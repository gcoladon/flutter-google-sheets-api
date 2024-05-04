import 'package:flutter/material.dart';
import 'package:sheets_backend/providers/google_sheets_provider.dart';
import 'package:logging/logging.dart';

class EditPage extends StatefulWidget {
  final GoogleSheetsProvider provider;
  final String sheet;
  final int id;
  const EditPage(
      {required this.provider, required this.sheet, required this.id, Key? key})
      : super(key: key);

  @override
  _EditPageState createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  Future<Map<String, String>> get _future =>
      widget.provider.getRow(widget.sheet, widget.id);
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool valsInitted = false;
  final log = Logger("optivore");

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width;
    return Scaffold(
        appBar: AppBar(
          title: Text("Generic Edit ${widget.sheet}"),
        ),
        body: FutureBuilder(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error fetching data for ${widget.sheet}: ${snapshot.error}'),
                );
              }
                if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final row = snapshot.data! as Map<String, String>;
              if (!valsInitted) {
                _idController.text = row['id']!;
                _nameController.text = row['name']!;
                valsInitted = true;
              }
              return Center(
                child: SizedBox(
                  width: size > 300 ? 300 : size,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _idController,
                        onChanged: (_) => setState(() {}),
                        decoration:
                            InputDecoration(hintText: "${widget.sheet} id"),
                      ),
                      const SizedBox(
                        height: 12.0,
                      ),
                      TextFormField(
                        controller: _nameController,
                        onChanged: (_) => setState(() {}),
                        decoration:
                            InputDecoration(hintText: "${widget.sheet} name"),
                      ),
                      const SizedBox(
                        height: 12.0,
                      ),
                      MaterialButton(
                          child: Text(
                            'Update ${widget.sheet}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          color: Theme.of(context).primaryColor,
                          onPressed: () async {
                            await widget.provider.updateRow(
                              widget.sheet,
                              {
                                "id": _idController.text,
                                "name": _nameController.text
                              },
                            );
                            Navigator.of(context).pop();
                          }),
                    ],
                  ),
                ),
              );
            }));
  }
}
