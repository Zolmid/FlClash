import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

Group? zolnitMainGroup(String? defaultGroup, List<Group> groups, Mode mode) =>
    groups.getGroup(
      mode == Mode.global ? GroupName.GLOBAL.name : defaultGroup ?? '',
    );
