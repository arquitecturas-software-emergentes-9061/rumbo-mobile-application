import 'package:rumbo_mobile_application/navigation/infrastructure/models/android_ble_session_configuration.dart';

class BleCaptureRequest {
  const BleCaptureRequest({
    required this.referenceLocation,
    required this.condition,
    required this.deviceAddresses,
    required this.serviceUuids,
  });

  final String referenceLocation;
  final String condition;
  final List<String> deviceAddresses;
  final List<String> serviceUuids;

  factory BleCaptureRequest.fromConfiguration(
    AndroidBleSessionConfiguration configuration,
  ) {
    return BleCaptureRequest(
      referenceLocation: configuration.referenceLocation,
      condition: configuration.condition,
      deviceAddresses: configuration.deviceAddresses,
      serviceUuids: configuration.serviceUuids,
    );
  }

  Map<String, Object> toMap() => {
    'referenceLocation': referenceLocation,
    'condition': condition,
    'deviceAddresses': deviceAddresses,
    'serviceUuids': serviceUuids,
  };
}
