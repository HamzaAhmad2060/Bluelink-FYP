import 'dart:io';
import 'package:near_talk/core/resources/assets.dart';
import 'package:near_talk/core/resources/colors.dart';
import 'package:permission_handler/permission_handler.dart';

import '../exports.dart';

class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> {
  Map<Permission, bool> _permissionStatuses = {
    Permission.location: false,
    Permission.storage: false,
    Permission.bluetooth: false,
  };

  bool _shouldRequestNearbyWifi = false;

  @override
  void initState() {
    super.initState();
    _checkAndroidVersion();
    _checkPermissions();
  }

  Future<void> _checkAndroidVersion() async {
    if (Platform.isAndroid) {
      int sdkVersion = int.parse((await Permission.nearbyWifiDevices.status).index.toString());
      if (sdkVersion >= 31) {
        setState(() {
          _shouldRequestNearbyWifi = true;
          _permissionStatuses[Permission.nearbyWifiDevices] = false;
        });
      }
    }
  }

  Future<void> _checkPermissions() async {
    final statuses = await Future.wait(_permissionStatuses.keys.map((p) => p.status));
    setState(() {
      _permissionStatuses = Map.fromIterables(
        _permissionStatuses.keys,
        statuses.map((s) => s.isGranted),
      );
    });
  }

  Future<void> _requestPermission(Permission permission) async {
    final status = await permission.request();
    setState(() {
      _permissionStatuses[permission] = status.isGranted;
    });
    if (!status.isGranted) {
      _showPermissionDeniedDialog(permission);
    }
  }

  Future<void> _requestAllPermissions() async {
    for (var permission in _permissionStatuses.keys) {
      if (!_permissionStatuses[permission]!) {
        await _requestPermission(permission);
      }
    }
  }

  void _showPermissionDeniedDialog(Permission permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(
          'This app needs ${permission.toString().split('.').last} permission to function properly. '
          'Please grant it in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  bool get _allPermissionsGranted => _permissionStatuses.values.every((status) => status);

  void _onSkipPressed() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Skipped permissions')),
    );
  }

  void _onNextPressed() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            AppAssets.bgImage,
            fit: BoxFit.cover,
          ),
        ),
        // Foreground content
        SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextWidget(
                    text: "Setup Permissions",
                    color: AppColors.primaryTextColor,
                    fontSize: 24.sp,
                  ),
                  TextButton(
                    onPressed: _onSkipPressed,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Required Permissions',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We need these permissions to work properly. '
                'Please grant them to continue.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              _buildPermissionTile(
                permission: Permission.location,
                title: 'Location',
                subtitle: 'To provide location-based features and services',
                icon: Icons.location_on,
              ),
              _buildPermissionTile(
                permission: Permission.storage,
                title: 'Storage',
                subtitle: 'To access and save files on your device',
                icon: Icons.folder,
              ),
              _buildPermissionTileForBluetooth(
                title: 'Bluetooth',
                subtitle: 'To connect with nearby Bluetooth devices',
                icon: Icons.bluetooth,
              ),
              if (_shouldRequestNearbyWifi)
                _buildPermissionTile(
                  permission: Permission.nearbyWifiDevices,
                  title: 'Nearby WiFi Devices',
                  subtitle: 'To discover and connect with nearby devices',
                  icon: Icons.wifi,
                ),
              const SizedBox(height: 24),
              if (!_allPermissionsGranted)
                ElevatedButton(
                  onPressed: _requestAllPermissions,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.blueAccent,
                  ),
                  child: const Text(
                    'Grant All Permissions',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              if (_allPermissionsGranted) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF30A6F0), Color(0xFF555555)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton(
                    onPressed: _onNextPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Next',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionTile({
    required Permission permission,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isGranted = _permissionStatuses[permission]!;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: isGranted ? Colors.green : Colors.grey),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isGranted ? Colors.green : Colors.transparent,
            border: Border.all(
              color: isGranted ? Colors.green : Colors.grey,
              width: 2,
            ),
          ),
          child: isGranted ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
        ),
        onTap: () => _requestPermission(permission),
      ),
    );
  }

  Widget _buildPermissionTileForBluetooth({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bluetoothPermissions = [Permission.bluetooth, Permission.bluetoothAdvertise, Permission.bluetoothConnect, Permission.bluetoothScan];

    final isGranted = bluetoothPermissions.every((p) => _permissionStatuses[p] ?? false);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: isGranted ? Colors.green : Colors.grey),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isGranted ? Colors.green : Colors.transparent,
            border: Border.all(
              color: isGranted ? Colors.green : Colors.grey,
              width: 2,
            ),
          ),
          child: isGranted ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
        ),
        onTap: () async {
          final statuses = await bluetoothPermissions.request();

          setState(() {
            _permissionStatuses.addEntries(
              statuses.entries.map((entry) => MapEntry(entry.key, entry.value.isGranted)),
            );
          });
        },
      ),
    );
  }
}
