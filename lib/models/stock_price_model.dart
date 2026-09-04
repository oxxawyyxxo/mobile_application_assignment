class StockPrice {
  final String date;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;

  StockPrice({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory StockPrice.fromYahoo({
    required int timestamp,
    required double open,
    required double high,
    required double low,
    required double close,
    required int volume,
    double fxRate = 1.0,
    bool intraday = false,
  }) {
    final dt = DateTime.fromMillisecondsSinceEpoch(
      timestamp * 1000,
      isUtc: true,
    ).toLocal();

    final dateStr = intraday
        ? '${_pad4(dt.year)}-${_pad2(dt.month)}-${_pad2(dt.day)} '
        '${_pad2(dt.hour)}:${_pad2(dt.minute)}'
        : '${_pad4(dt.year)}-${_pad2(dt.month)}-${_pad2(dt.day)}';

    return StockPrice(
      date: dateStr,
      open: open * fxRate,
      high: high * fxRate,
      low: low * fxRate,
      close: close * fxRate,
      volume: volume,
    );
  }

  static String _pad4(int n) => n.toString().padLeft(4, '0');
  static String _pad2(int n) => n.toString().padLeft(2, '0');
}