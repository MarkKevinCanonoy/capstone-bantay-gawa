import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/utils/schedule_helper.dart';
import 'package:mobile_app/data/models/user_model.dart';

void main() {
  group('ScheduleHelper Tests', () {
    test('isWorkingDay correctly handles ranges and single days', () {
      // Monday = weekday 1, Sunday = weekday 7
      final monday = DateTime(2026, 11, 2); // Monday
      final wednesday = DateTime(2026, 11, 4); // Wednesday
      final saturday = DateTime(2026, 11, 7); // Saturday
      final sunday = DateTime(2026, 11, 8); // Sunday

      expect(ScheduleHelper.isWorkingDay(monday, 'Mon-Fri'), isTrue);
      expect(ScheduleHelper.isWorkingDay(wednesday, 'Mon-Fri'), isTrue);
      expect(ScheduleHelper.isWorkingDay(saturday, 'Mon-Fri'), isFalse);
      expect(ScheduleHelper.isWorkingDay(sunday, 'Mon-Fri'), isFalse);

      expect(ScheduleHelper.isWorkingDay(saturday, 'Mon-Sat'), isTrue);
      expect(ScheduleHelper.isWorkingDay(sunday, 'Mon-Sat'), isFalse);

      expect(ScheduleHelper.isWorkingDay(sunday, 'Mon-Sun'), isTrue);
      expect(ScheduleHelper.isWorkingDay(sunday, 'Daily'), isTrue);

      expect(ScheduleHelper.isWorkingDay(monday, 'Mon, Wed, Fri'), isTrue);
      expect(ScheduleHelper.isWorkingDay(DateTime(2026, 11, 3), 'Mon, Wed, Fri'), isFalse); // Tue
    });

    test('evaluateShift handles Morning (AM) shift correctly', () {
      // Monday 2026-11-02
      final schedule = 'Mon-Fri 06:00 - 11:00';

      // 05:15 AM - 45 min before shift starts (Pre-shift reminder window)
      final preShiftTime = DateTime(2026, 11, 2, 5, 15);
      final preShiftEval = ScheduleHelper.evaluateShift(schedule: schedule, now: preShiftTime);
      expect(preShiftEval.status, equals(ShiftStatus.beforeShift));
      expect(preShiftEval.isStartingSoon, isTrue);
      expect(preShiftEval.timeUntilStart?.inMinutes, equals(45));

      // 08:30 AM - During active shift
      final activeShiftTime = DateTime(2026, 11, 2, 8, 30);
      final activeShiftEval = ScheduleHelper.evaluateShift(schedule: schedule, now: activeShiftTime);
      expect(activeShiftEval.status, equals(ShiftStatus.activeShift));
      expect(activeShiftEval.timeUntilEnd?.inMinutes, equals(150));

      // 12:00 PM - After shift ended
      final afterShiftTime = DateTime(2026, 11, 2, 12, 0);
      final afterShiftEval = ScheduleHelper.evaluateShift(schedule: schedule, now: afterShiftTime);
      expect(afterShiftEval.status, equals(ShiftStatus.afterShift));

      // Sunday 2026-11-08 at 08:00 AM - Rest day
      final restDayTime = DateTime(2026, 11, 8, 8, 0);
      final restDayEval = ScheduleHelper.evaluateShift(schedule: schedule, now: restDayTime);
      expect(restDayEval.status, equals(ShiftStatus.restDay));
    });

    test('evaluateShift handles Afternoon (PM) and Whole Day shifts', () {
      final pmSchedule = 'Mon-Fri 13:00 - 17:00';
      // 12:40 PM on Tuesday - 20 min before start
      final pmPreShift = DateTime(2026, 11, 3, 12, 40);
      final pmEval = ScheduleHelper.evaluateShift(schedule: pmSchedule, now: pmPreShift);
      expect(pmEval.status, equals(ShiftStatus.beforeShift));
      expect(pmEval.isStartingSoon, isTrue);
      expect(pmEval.timeUntilStart?.inMinutes, equals(20));

      // 14:00 PM on Tuesday - Active
      final pmActive = DateTime(2026, 11, 3, 14, 0);
      expect(ScheduleHelper.evaluateShift(schedule: pmSchedule, now: pmActive).status, equals(ShiftStatus.activeShift));

      final wholeDaySchedule = 'Mon-Fri 08:00 - 17:00';
      final wholeDayActive = DateTime(2026, 11, 4, 10, 0);
      expect(ScheduleHelper.evaluateShift(schedule: wholeDaySchedule, now: wholeDayActive).status, equals(ShiftStatus.activeShift));
    });

    test('evaluateShift handles unassigned or empty schedule gracefully', () {
      expect(ScheduleHelper.evaluateShift(schedule: null).status, equals(ShiftStatus.unassigned));
      expect(ScheduleHelper.evaluateShift(schedule: '').status, equals(ShiftStatus.unassigned));
      expect(ScheduleHelper.evaluateShift(schedule: 'Unassigned').status, equals(ShiftStatus.unassigned));
    });

    test('canTimeInNow strictly enforces shift window and early buffer', () {
      final schedule = 'Mon-Fri 07:00 - 12:00';

      // 1. At 21:48 (9:48 PM) on Monday - Shift is over
      final eveningTime = DateTime(2026, 11, 2, 21, 48);
      final eveningEval = ScheduleHelper.evaluateShift(schedule: schedule, now: eveningTime);
      final eveningValidation = ScheduleHelper.canTimeInNow(eveningEval);
      expect(eveningValidation.allowed, isFalse);
      expect(eveningValidation.reasonCeb, contains('Nahuman na'));

      // 2. At 06:15 AM on Monday (45m before start - too early)
      final earlyTime = DateTime(2026, 11, 2, 6, 15);
      final earlyEval = ScheduleHelper.evaluateShift(schedule: schedule, now: earlyTime);
      final earlyValidation = ScheduleHelper.canTimeInNow(earlyEval);
      expect(earlyValidation.allowed, isFalse);
      expect(earlyValidation.reasonCeb, contains('Sayo ra kaayo'));

      // 3. At 06:40 AM on Monday (20m before start - within 30m buffer)
      final bufferTime = DateTime(2026, 11, 2, 6, 40);
      final bufferEval = ScheduleHelper.evaluateShift(schedule: schedule, now: bufferTime);
      expect(ScheduleHelper.canTimeInNow(bufferEval).allowed, isTrue);

      // 4. At 08:30 AM on Monday (Active Shift)
      final activeTime = DateTime(2026, 11, 2, 8, 30);
      final activeEval = ScheduleHelper.evaluateShift(schedule: schedule, now: activeTime);
      expect(ScheduleHelper.canTimeInNow(activeEval).allowed, isTrue);

      // 5. Sunday on Rest Day
      final sundayTime = DateTime(2026, 11, 8, 8, 30);
      final sundayEval = ScheduleHelper.evaluateShift(schedule: schedule, now: sundayTime);
      final sundayValidation = ScheduleHelper.canTimeInNow(sundayEval);
      expect(sundayValidation.allowed, isFalse);
      expect(sundayValidation.reasonCeb, contains('Adlaw sa Pagpahulay'));
    });
  });

  group('UserModel Schedule Parsing Tests', () {
    test('parses schedule from joined relational schedules table', () {
      final json = {
        'user_id': 'w-101',
        'name': 'Juan Dela Cruz',
        'email': 'juan@enro.ormoc.gov.ph',
        'role': 'Field Worker',
        'assigned_area': 'Ormoc Plaza',
        'assigned_sector': 'Zone A',
        'schedules': [
          {
            'schedule_id': 'sch-1',
            'start_time': '06:00',
            'end_time': '11:00',
            'days': 'Mon-Fri',
            'created_at': '2026-11-01T08:00:00Z',
          }
        ],
      };

      final user = UserModel.fromJson(json);
      expect(user.schedule, equals('Mon-Fri 06:00 - 11:00'));
    });

    test('parses schedule fallback from direct string column', () {
      final json = {
        'user_id': 'w-102',
        'name': 'Maria Santos',
        'email': 'maria@enro.ormoc.gov.ph',
        'role': 'Field Worker',
        'assigned_area': 'City Hall',
        'assigned_sector': 'Zone B',
        'schedule': 'Mon-Sat 13:00 - 17:00',
      };

      final user = UserModel.fromJson(json);
      expect(user.schedule, equals('Mon-Sat 13:00 - 17:00'));
    });
  });
}
