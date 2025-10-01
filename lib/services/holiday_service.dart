import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/holiday_model.dart';

class HolidayService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'holidays';

  // Get all holidays from all types (optimized with concurrent calls)
  Future<List<Holiday>> getHolidays() async {
    try {
      // Make concurrent calls for better performance
      final futures = HolidayType.values.map((type) => getHolidaysByType(type));
      final results = await Future.wait(futures);
      
      // Flatten and sort results
      final allHolidays = <Holiday>[];
      for (final typeHolidays in results) {
        allHolidays.addAll(typeHolidays);
      }
      
      allHolidays.sort((a, b) => a.date.compareTo(b.date));
      return allHolidays;
    } catch (e) {
      throw Exception('Failed to fetch holidays: $e');
    }
  }

  // Get holidays by type from specific subcollection
  Future<List<Holiday>> getHolidaysByType(HolidayType type) async {
    try {
      final subCollectionName = type.value.toLowerCase();
      final querySnapshot = await _firestore
          .collection(_collection)
          .doc(subCollectionName)
          .collection('data')
          .orderBy('date', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => Holiday.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch holidays by type: $e');
    }
  }

  // Get holidays for a specific year (optimized with concurrent calls)
  Future<List<Holiday>> getHolidaysForYear(int year) async {
    try {
      final startOfYear = DateTime(year, 1, 1);
      final endOfYear = DateTime(year, 12, 31, 23, 59, 59);

      // Make concurrent calls for better performance
      final futures = HolidayType.values.map((type) async {
        final subCollectionName = type.value.toLowerCase();
        final querySnapshot = await _firestore
            .collection(_collection)
            .doc(subCollectionName)
            .collection('data')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfYear))
            .orderBy('date', descending: false)
            .get();

        return querySnapshot.docs
            .map((doc) => Holiday.fromJson({...doc.data(), 'id': doc.id}))
            .toList();
      });

      final results = await Future.wait(futures);
      
      // Flatten and sort results
      final allHolidays = <Holiday>[];
      for (final typeHolidays in results) {
        allHolidays.addAll(typeHolidays);
      }

      allHolidays.sort((a, b) => a.date.compareTo(b.date));
      return allHolidays;
    } catch (e) {
      throw Exception('Failed to fetch holidays for year: $e');
    }
  }

  // Add a new holiday to the appropriate subcollection
  Future<void> addHoliday(Holiday holiday) async {
    try {
      if (holiday.id.isEmpty) {
        throw Exception('Holiday ID cannot be empty');
      }
      
      final subCollectionName = holiday.type.value.toLowerCase();
      await _firestore
          .collection(_collection)
          .doc(subCollectionName)
          .collection('data')
          .doc(holiday.id)
          .set(holiday.toJson());
    } catch (e) {
      throw Exception('Failed to add holiday: $e');
    }
  }

  // Update an existing holiday
  Future<void> updateHoliday(Holiday holiday) async {
    try {
      if (holiday.id.isEmpty) {
        throw Exception('Holiday ID cannot be empty');
      }
      
      final subCollectionName = holiday.type.value.toLowerCase();
      final updatedHoliday = holiday.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection(_collection)
          .doc(subCollectionName)
          .collection('data')
          .doc(holiday.id)
          .update(updatedHoliday.toJson());
    } catch (e) {
      throw Exception('Failed to update holiday: $e');
    }
  }

  // Delete a holiday
  Future<void> deleteHoliday(String holidayId, HolidayType type) async {
    try {
      if (holidayId.isEmpty) {
        throw Exception('Holiday ID cannot be empty');
      }
      
      final subCollectionName = type.value.toLowerCase();
      await _firestore
          .collection(_collection)
          .doc(subCollectionName)
          .collection('data')
          .doc(holidayId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete holiday: $e');
    }
  }

  // Get upcoming holidays (next 30 days) - optimized with concurrent calls
  Future<List<Holiday>> getUpcomingHolidays() async {
    try {
      final now = DateTime.now();
      final thirtyDaysLater = now.add(const Duration(days: 30));

      // Make concurrent calls for better performance
      final futures = HolidayType.values.map((type) async {
        final subCollectionName = type.value.toLowerCase();
        final querySnapshot = await _firestore
            .collection(_collection)
            .doc(subCollectionName)
            .collection('data')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(thirtyDaysLater))
            .orderBy('date', descending: false)
            .get();

        return querySnapshot.docs
            .map((doc) => Holiday.fromJson({...doc.data(), 'id': doc.id}))
            .toList();
      });

      final results = await Future.wait(futures);
      
      // Flatten and sort results
      final allUpcomingHolidays = <Holiday>[];
      for (final typeHolidays in results) {
        allUpcomingHolidays.addAll(typeHolidays);
      }

      allUpcomingHolidays.sort((a, b) => a.date.compareTo(b.date));
      return allUpcomingHolidays;
    } catch (e) {
      throw Exception('Failed to fetch upcoming holidays: $e');
    }
  }

  // Check if a date is a holiday
  Future<Holiday?> getHolidayByDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Check each type subcollection for the date
      for (HolidayType type in HolidayType.values) {
        final subCollectionName = type.value.toLowerCase();
        final querySnapshot = await _firestore
            .collection(_collection)
            .doc(subCollectionName)
            .collection('data')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('date', isLessThan: Timestamp.fromDate(endOfDay))
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          return Holiday.fromJson({...querySnapshot.docs.first.data(), 'id': querySnapshot.docs.first.id});
        }
      }
      return null;
    } catch (e) {
      throw Exception('Failed to check holiday by date: $e');
    }
  }

  // Get holidays stream for real-time updates (specific type)
  Stream<List<Holiday>> getHolidaysStreamByType(HolidayType type) {
    final subCollectionName = type.value.toLowerCase();
    return _firestore
        .collection(_collection)
        .doc(subCollectionName)
        .collection('data')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Holiday.fromJson({...doc.data(), 'id': doc.id})).toList());
  }

  // Get all holidays stream for real-time updates (all types combined)
  // Note: For simplicity, this refreshes every 30 seconds or can be called manually
  Stream<List<Holiday>> getHolidaysStream() async* {
    while (true) {
      try {
        final holidays = await getHolidays();
        yield holidays;
        await Future.delayed(const Duration(seconds: 30));
      } catch (e) {
        yield <Holiday>[];
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  // Batch operations for importing holidays
  Future<void> addMultipleHolidays(List<Holiday> holidays) async {
    try {
      final batch = _firestore.batch();
      
      for (final holiday in holidays) {
        final subCollectionName = holiday.type.value.toLowerCase();
        final docRef = _firestore
            .collection(_collection)
            .doc(subCollectionName)
            .collection('data')
            .doc(holiday.id);
        batch.set(docRef, holiday.toJson());
      }
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to add multiple holidays: $e');
    }
  }

  // Delete all holidays of a specific type
  Future<void> deleteHolidaysByType(HolidayType type) async {
    try {
      final subCollectionName = type.value.toLowerCase();
      final querySnapshot = await _firestore
          .collection(_collection)
          .doc(subCollectionName)
          .collection('data')
          .get();

      final batch = _firestore.batch();
      
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete holidays by type: $e');
    }
  }

  // Check for conflicting holidays on a date
  Future<bool> hasHolidayConflict(DateTime date, {String? excludeHolidayId}) async {
    try {
      final existingHoliday = await getHolidayByDate(date);
      if (existingHoliday == null) {
        return false;
      }
      
      // If we're excluding a specific holiday (for updates), check if it's the same one
      if (excludeHolidayId != null && 
          excludeHolidayId.isNotEmpty && 
          existingHoliday.id == excludeHolidayId) {
        return false;
      }
      
      return true;
    } catch (e) {
      // Log error in production, for now return false to be safe
      return false;
    }
  }
}
