import 'dart:convert';
import 'package:flutter/services.dart';

class MumbaiRisk {
  final List<RiskPoint> points;
  MumbaiRisk(this.points);

  static Future<MumbaiRisk> load() async {
    final data = await rootBundle.loadString(
      'assets/data/mumbai_risk_grid.json',
    );
    final list = json.decode(data) as List;
    return MumbaiRisk(list.map((e) => RiskPoint.fromJson(e)).toList());
  }
}

class RiskPoint {
  final double lat, lng, risk;
  RiskPoint(this.lat, this.lng, this.risk);
  factory RiskPoint.fromJson(Map<String, dynamic> json) => RiskPoint(
    json['lat']?.toDouble() ?? 0,
    json['lng']?.toDouble() ?? 0,
    json['risk']?.toDouble() ?? 0,
  );
}
