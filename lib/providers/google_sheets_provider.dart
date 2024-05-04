import 'package:gsheets/gsheets.dart';
import 'package:sheets_backend/models/diet_entity.dart';
import 'package:sheets_backend/models/goal_entity.dart';
import 'package:sheets_backend/models/group_entity.dart';
import 'package:sheets_backend/models/food_entity.dart';
import 'package:sheets_backend/models/dish_entity.dart';
import 'package:sheets_backend/models/vendor_entity.dart';
import 'package:sheets_backend/models/user_entity.dart';
import 'package:sheets_backend/models/diet_group_entity.dart';
import 'package:sheets_backend/models/food_dish_entity.dart';
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

  //
  // methods for diet sheet
  //

  Future<List<DietEntity>> getDiets() async {
    /// skips the first value which is the header
    final values =
        (await _worksheets["diet"]!.values.allRows()).skip(1).toList();
    return values.map((value) => DietEntity.fromSheets(value)).toList();
  }

  Future<DietEntity> getDiet(int index) async {
    /// skips the first value which is the header
    final values =
        (await _worksheets["diet"]!.values.allRows()).skip(1).toList();
    return DietEntity.fromSheets(values[index]);
  }

  Future<Map<String, List<String>>> getDietRelations(int index) async {
    // should we be returning a map with objects, maybe the base classes?
    final Map<String, List<String>> resultMap = {};
    // would be good to only pull one row here, not all rows.
    final allDiets =
        (await _worksheets["diet"]!.values.allRows()).skip(1).toList();
    final diet = DietEntity.fromSheets(allDiets[index]);
    final related =
        (await _worksheets['diet_group']!.values.allRows()).skip(1).toList();
    for (final row in related) {
      final entity = DietGroupEntity.fromSheets(row);
      if (entity.diet_id == diet.id) {
        if (!resultMap.containsKey("group")) {
          resultMap["group"] = [];
        }
        resultMap["group"]!.add(entity.group_name);
      }
    }
    return resultMap;
  }

  Future<bool> deleteDiet(int index) {
    /// We add two to the index so that we can:
    /// 1. Start at index 1
    /// 2. Skip the first row
    return _worksheets["diet"]!.deleteRow(index + 2);
  }

  Future<bool> addDiet(
    String id,
    String name,
  ) {
    return _worksheets["diet"]!.values.appendRow([
      id,
      name,
    ]);
  }

  Future<bool> updateDiet(
    int index,
    String id,
    String name,
  ) {
    /// We add 2 to the index so that we can:
    /// 1. Start at index 1
    /// 2. Skip the first row
    return _worksheets["diet"]!.values.insertRow(index + 2, [
      id,
      name,
    ]);
  }

  //
  // methods for goal sheet
  //

  Future<List<GoalEntity>> getGoals() async {
    /// skips the first value which is the header
    final values =
        (await _worksheets["goal"]!.values.allRows()).skip(1).toList();
    return values.map((value) => GoalEntity.fromSheets(value)).toList();
  }

  Future<GoalEntity> getGoal(int index) async {
    /// skips the first value which is the header
    final values =
        (await _worksheets["goal"]!.values.allRows()).skip(1).toList();
    return GoalEntity.fromSheets(values[index]);
  }

  Future<Map<String, List<String>>> getGoalRelations(int index) async {
    // should we be returning a map with objects, maybe the base classes?
    final Map<String, List<String>> resultMap = {};
    return resultMap;
  }

  Future<bool> deleteGoal(int index) {
    /// We add two to the index so that we can:
    /// 1. Start at index 1
    /// 2. Skip the first row
    return _worksheets["goal"]!.deleteRow(index + 2);
  }

  Future<bool> addGoal(
    String id,
    String name,
  ) {
    return _worksheets["goal"]!.values.appendRow([
      id,
      name,
    ]);
  }

  Future<bool> updateGoal(
    int index,
    String id,
    String name,
  ) {
    /// We add 2 to the index so that we can:
    /// 1. Start at index 1
    /// 2. Skip the first row
    return _worksheets["goal"]!.values.insertRow(index + 2, [
      id,
      name,
    ]);
  }

  //
  // methods for group sheet
  //

  Future<List<GroupEntity>> getGroups() async {
    /// skips the first value which is the header
    final values =
        (await _worksheets["group"]!.values.allRows()).skip(1).toList();
    return values.map((value) => GroupEntity.fromSheets(value)).toList();
  }

  Future<GroupEntity> getGroup(int index) async {
    /// skips the first value which is the header
    final values =
        (await _worksheets["group"]!.values.allRows()).skip(1).toList();
    return GroupEntity.fromSheets(values[index]);
  }

  Future<Map<String, List<String>>> getGroupRelations(int index) async {
    // should we be returning a map with objects, maybe the base classes?
    final Map<String, List<String>> resultMap = {};
    // would be good to only pull one row here, not all rows.
    final allGroups =
        (await _worksheets["group"]!.values.allRows()).skip(1).toList();
    final group = GroupEntity.fromSheets(allGroups[index]);
    final related =
        (await _worksheets['diet_group']!.values.allRows()).skip(1).toList();
    for (final row in related) {
      final entity = DietGroupEntity.fromSheets(row);
      if (entity.group_id == group.id) {
        if (!resultMap.containsKey("diet")) {
          resultMap["diet"] = [];
        }
        resultMap["diet"]!.add(entity.diet_name);
      }
    }
    return resultMap;
  }

  Future<bool> deleteGroup(int index) {
    /// We add two to the index so that we can:
    /// 1. Start at index 1
    /// 2. Skip the first row
    return _worksheets["group"]!.deleteRow(index + 2);
  }

  Future<bool> addGroup(
    String id,
    String name,
  ) {
    return _worksheets["group"]!.values.appendRow([
      id,
      name,
    ]);
  }

  Future<bool> updateGroup(
    int index,
    String id,
    String name,
  ) {
    /// We add 2 to the index so that we can:
    /// 1. Start at index 1
    /// 2. Skip the first row
    return _worksheets["group"]!.values.insertRow(index + 2, [
      id,
      name,
    ]);
  }

  //
  // methods for food sheet
  //

  Future<List<FoodEntity>> getFoods() async {
    /// skips the first value which is the header
    final values =
        (await _worksheets["food"]!.values.allRows()).skip(1).toList();
    return values.map((value) => FoodEntity.fromSheets(value)).toList();
  }

  Future<FoodEntity> getFood(int index) async {
    /// skips the first value which is the header
    final values =
        (await _worksheets["food"]!.values.allRows()).skip(1).toList();
    return FoodEntity.fromSheets(values[index]);
  }

  Future<Map<String, List<String>>> getFoodRelations(int index) async {
    // should we be returning a map with objects, maybe the base classes?
    final Map<String, List<String>> resultMap = {};
    // would be good to only pull one row here, not all rows.
    final allFoods =
        (await _worksheets["food"]!.values.allRows()).skip(1).toList();
    final food = FoodEntity.fromSheets(allFoods[index]);
    final related =
        (await _worksheets['food_dish']!.values.allRows()).skip(1).toList();
    for (final row in related) {
      final entity = FoodDishEntity.fromSheets(row);
      if (entity.food_id == food.id) {
        if (!resultMap.containsKey("dish")) {
          resultMap["dish"] = [];
        }
        resultMap["dish"]!.add(entity.dish_name);
      }
    }
    return resultMap;
  }

  Future<bool> deleteFood(int index) {
    /// We add two to the index so that we can:
    /// 1. Start at index 1
    /// 2. Skip the first row
    return _worksheets["food"]!.deleteRow(index + 2);
  }

  Future<bool> addFood(
    String id,
    String name,
    String groupName,
  ) {
    return _worksheets["food"]!.values.appendRow([
      id,
      name,
      groupName,
    ]);
  }

  Future<bool> updateFood(
    int index,
    String id,
    String name,
    String groupName,
  ) {
    /// We add 2 to the index so that we can:
    /// 1. Start at index 1
    /// 2. Skip the first row
    return _worksheets["food"]!.values.insertRow(index + 2, [
      id,
      name,
      groupName,
    ]);
  }

  //
  // methods for dish sheet
  //

  Future<List<DishEntity>> getDishes() async {
    /// skips the first value which is the header
    final values =
        (await _worksheets["dish"]!.values.allRows()).skip(1).toList();
    return values.map((value) => DishEntity.fromSheets(value)).toList();
  }

  Future<DishEntity> getDish(int index) async {
    /// skips the first value which is the header
    final values =
        (await _worksheets["dish"]!.values.allRows()).skip(1).toList();
    return DishEntity.fromSheets(values[index]);
  }

  Future<Map<String, List<String>>> getDishRelations(int index) async {
    // should we be returning a map with objects, maybe the base classes?
    final Map<String, List<String>> resultMap = {};
    // would be good to only pull one row here, not all rows.
    final allDishes =
        (await _worksheets["dish"]!.values.allRows()).skip(1).toList();
    final dish = DishEntity.fromSheets(allDishes[index]);
    final related =
        (await _worksheets['food_dish']!.values.allRows()).skip(1).toList();
    for (final row in related) {
      final entity = FoodDishEntity.fromSheets(row);
      if (entity.dish_id == dish.id) {
        if (!resultMap.containsKey("food")) {
          resultMap["food"] = [];
        }
        resultMap["food"]!.add(entity.food_name);
      }
    }
    return resultMap;
  }

  Future<bool> deleteDish(int index) {
    /// We add two to the index so that we can:
    /// 1. Start at index 1
    /// 2. Skip the first row
    return _worksheets["dish"]!.deleteRow(index + 2);
  }

  Future<bool> addDish(
    String id,
    String name,
  ) {
    return _worksheets["dish"]!.values.appendRow([
      id,
      name,
    ]);
  }

  Future<bool> updateDish(
    int index,
    String id,
    String name,
  ) {
    /// We add 2 to the index so that we can:
    /// 1. Start at index 1
    /// 2. Skip the first row
    return _worksheets["dish"]!.values.insertRow(index + 2, [
      id,
      name,
    ]);
  }

  //
  // methods for vendor sheet
  //

  Future<List<VendorEntity>> getVendors() async {
    /// skips the first value which is the header
    final values =
        (await _worksheets["vendor"]!.values.allRows()).skip(1).toList();
    return values.map((value) => VendorEntity.fromSheets(value)).toList();
  }

  Future<VendorEntity> getVendor(int index) async {
    /// skips the first value which is the header
    final values =
        (await _worksheets["vendor"]!.values.allRows()).skip(1).toList();
    return VendorEntity.fromSheets(values[index]);
  }

  Future<Map<String, List<String>>> getVendorRelations(int index) async {
    // should we be returning a map with objects, maybe the base classes?
    final Map<String, List<String>> resultMap = {};
    return resultMap;
  }

  Future<bool> deleteVendor(int index) {
    /// We add two to the index so that we can:
    /// 1. Start at index 1
    /// 2. Skip the first row
    return _worksheets["vendor"]!.deleteRow(index + 2);
  }

  Future<bool> addVendor(
    String id,
    String name,
    String address,
    String url,
  ) {
    return _worksheets["vendor"]!.values.appendRow([
      id,
      name,
      address,
      url,
    ]);
  }

  Future<bool> updateVendor(
    int index,
    String id,
    String name,
    String address,
    String url,
  ) {
    /// We add 2 to the index so that we can:
    /// 1. Start at index 1
    /// 2. Skip the first row
    return _worksheets["vendor"]!.values.insertRow(index + 2, [
      id,
      name,
      address,
      url,
    ]);
  }

  //
  // methods for user sheet
  //

  Future<List<UserEntity>> getUsers() async {
    /// skips the first value which is the header
    final values =
        (await _worksheets["user"]!.values.allRows()).skip(1).toList();
    return values.map((value) => UserEntity.fromSheets(value)).toList();
  }

  Future<UserEntity> getUser(int index) async {
    /// skips the first value which is the header
    final values =
        (await _worksheets["user"]!.values.allRows()).skip(1).toList();
    return UserEntity.fromSheets(values[index]);
  }

  Future<Map<String, List<String>>> getUserRelations(int index) async {
    // should we be returning a map with objects, maybe the base classes?
    final Map<String, List<String>> resultMap = {};
    return resultMap;
  }

  Future<bool> deleteUser(int index) {
    /// We add two to the index so that we can:
    /// 1. Start at index 1
    /// 2. Skip the first row
    return _worksheets["user"]!.deleteRow(index + 2);
  }

  Future<bool> addUser(
    String id,
    String name,
  ) {
    return _worksheets["user"]!.values.appendRow([
      id,
      name,
    ]);
  }

  Future<bool> updateUser(
    int index,
    String id,
    String name,
  ) {
    /// We add 2 to the index so that we can:
    /// 1. Start at index 1
    /// 2. Skip the first row
    return _worksheets["user"]!.values.insertRow(index + 2, [
      id,
      name,
    ]);
  }
}
