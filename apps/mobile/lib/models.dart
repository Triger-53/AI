import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Verse {
  final int id;
  final String text;
  const Verse(this.id, this.text);
}

class Chapter {
  final int id;
  final String name, transliteration, type;
  final List<Verse> verses;
  const Chapter(this.id, this.name, this.transliteration, this.type, this.verses);
  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
    j['id'] as int, j['name'] as String, j['transliteration'] as String,
    j['type'] as String,
    (j['verses'] as List).map((v) => Verse(v['id'] as int, v['text'] as String)).toList(),
  );
  static Future<List<Chapter>> load() async {
    final list = jsonDecode(await rootBundle.loadString('assets/quran.json')) as List;
    final chapters = list.map((j) => Chapter.fromJson(j as Map<String, dynamic>)).toList();
    if (chapters.length != 114 || chapters.fold<int>(0, (n, c) => n + c.verses.length) != 6236) {
      throw const FormatException('Invalid Quran corpus');
    }
    return chapters;
  }
}

class Passage {
  final Chapter chapter;
  final int start, end;
  const Passage(this.chapter, this.start, this.end);
  List<Verse> get verses => chapter.verses.sublist(start - 1, end);
  List<String> get words => verses.expand((v) => v.text.split(RegExp(r'\s+'))).toList();
  bool get liveEligible => end - start < 10 && verses.map((v) => v.text).join(' ').length <= 6000;
  String get reference => '${chapter.id}:$start–$end';
}

class PracticeRecord {
  final int surah, start, end, seconds, reviews;
  final bool demo, completed;
  final DateTime date;
  const PracticeRecord({required this.surah, required this.start, required this.end,
    required this.seconds, required this.reviews, required this.demo,
    required this.completed, required this.date});
  Map<String, dynamic> toJson() => {'surah': surah, 'start': start, 'end': end,
    'seconds': seconds, 'reviews': reviews, 'demo': demo, 'completed': completed,
    'date': date.toIso8601String()};
  factory PracticeRecord.fromJson(Map<String, dynamic> j) => PracticeRecord(
    surah: j['surah'], start: j['start'], end: j['end'], seconds: j['seconds'],
    reviews: j['reviews'], demo: j['demo'], completed: j['completed'], date: DateTime.parse(j['date']));
}

class AppStore {
  final SharedPreferences preferences;
  AppStore(this.preferences);
  String get language => preferences.getString('language') ?? 'en';
  double get textSize => preferences.getDouble('textSize') ?? 32;
  bool get hifz => preferences.getBool('hifz') ?? false;
  String get server => preferences.getString('server') ?? '';
  List<PracticeRecord> get history {
    try {
      return (jsonDecode(preferences.getString('history') ?? '[]') as List)
        .map((j) => PracticeRecord.fromJson(j)).toList();
    } catch (_) { return []; }
  }
  Future<void> add(PracticeRecord record) async {
    final records = [record, ...history].take(100).map((r) => r.toJson()).toList();
    await preferences.setString('history', jsonEncode(records));
  }
  Future<void> clearHistory() async { await preferences.remove('history'); }
}
