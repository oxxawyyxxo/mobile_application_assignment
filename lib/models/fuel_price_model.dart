class FuelPrice{
  final String seriesType;
  final String date;
  final double ron95;
  final double ron97;
  final double diesel;
  final double dieselEastMsia;
  final double ron95Budi95;
  final double ron95Skps;

  FuelPrice({
    required this.seriesType,
    required this.date,
    required this.ron95,
    required this.ron97,
    required this.diesel,
    required this.dieselEastMsia,
    required this.ron95Budi95,
    required this.ron95Skps
  });

  factory FuelPrice.fromJson(Map<String, dynamic> json){
    return FuelPrice(
        seriesType: json['series_type'] ?? 'level',
        date: json['date'] ?? '',
        ron95: (json['ron95'] as num?)?.toDouble() ?? 0,
        ron97: (json['ron97'] as num?)?.toDouble() ?? 0,
        diesel: (json['diesel'] as num?)?.toDouble() ?? 0,
        dieselEastMsia: (json['diesel_eastmsia'] as num?)?.toDouble() ?? 0,
        ron95Budi95: (json['ron95_budi95'] as num?)?.toDouble() ?? 0,
        ron95Skps: (json['ron95_skps'] as num?)?.toDouble() ?? 0
    );
  }

  Map<String, dynamic> toMap(){
    return {
      'series_type': seriesType,
      'date': date,
      'ron95': ron95,
      'ron97': ron97,
      'diesel': diesel,
      'diesel_eastmsia': dieselEastMsia,
      'ron95_budi95': ron95Budi95,
      'ron95_skps': ron95Skps
    };
  }
}