class RoutePreferences {
  const RoutePreferences({
    this.avoidStairs = false,
    this.simplerRoute = false,
    this.voiceGuidance = false,
    this.configured = false,
  });

  final bool avoidStairs;
  final bool simplerRoute;
  final bool voiceGuidance;
  final bool configured;

  bool get accessibleOnly => avoidStairs;

  factory RoutePreferences.fromJson(Map<String, dynamic> data) =>
      RoutePreferences(
        avoidStairs: data['avoidStairs'] as bool,
        simplerRoute: data['simplerRoute'] as bool,
        voiceGuidance: data['voiceGuidance'] as bool,
        configured: data['configured'] as bool,
      );

  RoutePreferences copyWith({
    bool? avoidStairs,
    bool? simplerRoute,
    bool? voiceGuidance,
  }) => RoutePreferences(
    avoidStairs: avoidStairs ?? this.avoidStairs,
    simplerRoute: simplerRoute ?? this.simplerRoute,
    voiceGuidance: voiceGuidance ?? this.voiceGuidance,
    configured: configured,
  );

  Map<String, bool> toJson() => {
    'avoidStairs': avoidStairs,
    'simplerRoute': simplerRoute,
    'voiceGuidance': voiceGuidance,
  };
}
