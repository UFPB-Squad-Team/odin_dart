abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'ODIN_API_BASE_URL',
    defaultValue: 'https://odin-backend-xdfx.onrender.com/api/v1',
  );

  static const userAgentPackage = 'br.ufpb.lema.odin_app';

  /// Whether the map may ask the API for viewport-scoped, resolution-aware
  /// geometry (`?bbox=…&resolution=…`).
  ///
  /// Defaults to `false` because the deployed backend has not been verified to
  /// accept these parameters. When enabled and the API answers with a 4xx, the
  /// repository downgrades itself for the rest of the session and falls back to
  /// whole-territory payloads — so enabling this is always safe. Override with
  /// `--dart-define=ODIN_SPATIAL_API=true`.
  static const spatialApiEnabled =
      bool.fromEnvironment('ODIN_SPATIAL_API', defaultValue: false);
}
