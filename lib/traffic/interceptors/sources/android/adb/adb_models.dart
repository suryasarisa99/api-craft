class AdbDevice {
  final String id;
  final String status;
  final String? name;

  AdbDevice({required this.id, required this.status, this.name});

  @override
  String toString() => name ?? id;
  // String toString() => 'AdbDevice(id: $id, status: $status, name: $name)';
}

class AdbAppInfo {
  final String packageName;
  final String name;
  final String version;

  AdbAppInfo({
    required this.packageName,
    required this.name,
    required this.version,
  });

  @override
  String toString() =>
      'AdbAppInfo(packageName: $packageName, name: $name, version: $version)';
}

class FileEntry {
  final String name;
  final int size;
  final int mode;
  final String permissions;

  FileEntry({
    required this.name,
    required this.size,
    required this.mode,
    required this.permissions,
  });

  @override
  String toString() =>
      'FileEntry(name: $name, size: $size, mode: $mode, permissions: $permissions)';
}

class DeviceDetails {
  final String id;
  final String name;
  final String status;
  final String type;

  DeviceDetails({
    required this.id,
    required this.name,
    required this.status,
    required this.type,
  });

  @override
  String toString() =>
      'DeviceDetails(id: $id, name: $name, status: $status, type: $type)';
}
