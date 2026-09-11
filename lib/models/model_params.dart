class ModelParams {
  const ModelParams({
    required this.temperature,
    required this.topP,
    required this.contextLength,
  });

  factory ModelParams.defaults() {
    return const ModelParams(
      temperature: 0.8,
      topP: 0.9,
      contextLength: 20,
    );
  }

  factory ModelParams.fromJson(Map<String, dynamic> json) {
    return ModelParams(
      temperature: _readDouble(json['temperature'], 0.8),
      topP: _readDouble(json['top_p'], _readDouble(json['topP'], 0.9)),
      contextLength: _readInt(json['contextLength'], 20),
    );
  }

  final double temperature;
  final double topP;
  final int contextLength;

  ModelParams copyWith({
    double? temperature,
    double? topP,
    int? contextLength,
  }) {
    return ModelParams(
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      contextLength: contextLength ?? this.contextLength,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'top_p': topP,
      'contextLength': contextLength,
    };
  }

  static double _readDouble(dynamic value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int _readInt(dynamic value, int fallback) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
