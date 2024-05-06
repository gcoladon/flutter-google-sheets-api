import 'package:flutter/material.dart';
import 'package:crutter/providers/google_sheets_provider.dart';
import 'package:logging/logging.dart';

class NewPage extends StatefulWidget {
  final GoogleSheetsProvider provider;
  final String sheet;
  const NewPage({required this.provider, required this.sheet, Key? key})
      : super(key: key);

  @override
  _NewPageState createState() => _NewPageState();
}

class _NewPageState extends State<NewPage> {
  final TextEditingController _nameController = TextEditingController();
  final log = Logger("optivore");

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: Text("Add ${widget.sheet}"),
      ),
      body: Center(
        child: SizedBox(
          width: size > 300 ? 300 : size,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(hintText: "${widget.sheet} name"),
              ),
              const SizedBox(
                height: 12.0,
              ),
              MaterialButton(
                  child: Text(
                    'Add ${widget.sheet}',
                    style: TextStyle(color: Colors.white),
                  ),
                  color: Theme.of(context).primaryColor,
                  onPressed: () async {
                    await widget.provider.addRow(
                      widget.sheet,
                      {'id': '', 'name': _nameController.text},
                    );
                    Navigator.of(context).pop();
                  }),
            ],
          ),
        ),
      ),
    );
  }
}
