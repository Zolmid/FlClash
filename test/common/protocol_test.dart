import 'package:fl_clash/common/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('legacy formats are parsed without claiming their system handlers', () {
    expect(registeredProtocolSchemes, ['zolnit']);
    expect(
      protocolSchemes,
      containsAll(['clash', 'clashmeta', 'flclash', 'mihomo', 'zolnit']),
    );
  });
  group('ProtocolRegistrationPlan', () {
    test('builds registry writes for URL protocol registration', () {
      const plan = ProtocolRegistrationPlan(
        scheme: 'flclash',
        executable: r'C:\Program Files\ZolNit\ZolNit.exe',
      );

      expect(plan.protocolKey, r'Software\Classes\flclash');
      expect(plan.commandKey, r'shell\open\command');
      expect(plan.protocolValueName, 'URL Protocol');
      expect(plan.protocolValue, '');
      expect(plan.command, r'"C:\Program Files\ZolNit\ZolNit.exe" "%1"');
    });
  });

  group('LinuxProtocolRegistrationPlan', () {
    const plan = LinuxProtocolRegistrationPlan(
      schemes: registeredProtocolSchemes,
      executable: '/home/me/Apps/ZolNit.AppImage',
      applicationsDir: '/home/me/.local/share/applications',
      debugMode: false,
    );

    test('writes a hidden desktop entry claiming every scheme', () {
      expect(
        plan.desktopPath,
        '/home/me/.local/share/applications/com.zolmid.zolnit.desktop',
      );
      expect(
        plan.desktopEntry,
        '[Desktop Entry]\n'
        'Type=Application\n'
        'Name=ZolNit\n'
        'NoDisplay=true\n'
        'Exec="/home/me/Apps/ZolNit.AppImage" %u\n'
        'MimeType=x-scheme-handler/zolnit;\n',
      );
    });

    test('makes the entry the default handler for every scheme', () {
      expect(plan.xdgMimeArguments, [
        'default',
        'com.zolmid.zolnit.desktop',
        'x-scheme-handler/zolnit',
      ]);
    });

    test('escapes reserved characters in the executable path', () {
      const plan = LinuxProtocolRegistrationPlan(
        schemes: ['flclash'],
        executable: r'/opt/my "apps"/$HOME/100%/Fl`Clash\bin',
        applicationsDir: '/tmp',
      );

      expect(plan.exec, r'"/opt/my \"apps\"/\$HOME/100%%/Fl\`Clash\\bin" %u');
    });

    test('debug registration uses its own desktop entry', () {
      const debug = LinuxProtocolRegistrationPlan(
        schemes: registeredProtocolSchemes,
        executable: '/tmp/ZolNit',
        applicationsDir: '/tmp/applications',
        debugMode: true,
      );
      expect(debug.desktopId, 'com.zolmid.zolnit.debug.desktop');
      expect(
        debug.desktopPath,
        '/tmp/applications/com.zolmid.zolnit.debug.desktop',
      );
    });
  });
}
