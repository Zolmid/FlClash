// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ru locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'ru';

  static String m0(count, skipped) =>
      "Будет добавлено: ${count}, пропущено (уже есть): ${skipped}";

  static String m1(detail) => "Не удалось очистить данные: ${detail}";

  static String m2(code) =>
      "Windows отказалась запускать FlClashCore.exe (ошибка ${code}). Политики контроля приложений, такие как Smart App Control или AppLocker, блокируют неподписанные программы; разрешите FlClash в этой политике или отключите её и повторите попытку.";

  static String m3(name) =>
      "Приложение два раза подряд не смогло завершить запуск. Чтобы разорвать цикл, профиль ${name} снят с выбора, а автоматическая настройка пропущена. Вы можете выбрать его снова в любой момент.";

  static String m4(url) => "Создать профиль по ссылке ${url}?";

  static String m5(count, label) =>
      "${Intl.plural(count, one: 'Пользовательские профили не поддерживают подправила, поэтому отброшено ${label} правило SUB-RULE', few: 'Пользовательские профили не поддерживают подправила, поэтому отброшено ${label} правила SUB-RULE', many: 'Пользовательские профили не поддерживают подправила, поэтому отброшено ${label} правил SUB-RULE', other: 'Пользовательские профили не поддерживают подправила, поэтому отброшено ${label} правила SUB-RULE')}";

  static String m6(message) =>
      "Ядро не может разобрать этот прокси: ${message}";

  static String m7(proxy, target) =>
      "${proxy} подключается через ${target}, а ${target} снова ведёт к ${proxy}, поэтому подключение зацикливается";

  static String m8(name) =>
      "Имя ${name} уже занято другим прокси или группой прокси";

  static String m9(path) =>
      "Группы прокси ссылаются друг на друга по кругу: ${path}";

  static String m10(name) =>
      "Резервом для пустой группы может быть только прокси, а ${name} не существует или является группой прокси";

  static String m11(name, message) =>
      "${name}: недопустимое регулярное выражение: ${message}";

  static String m12(name) => "Прокси для подключения ${name} не существует";

  static String m13(names) => "Эти провайдеры прокси не существуют: ${names}";

  static String m14(names) => "Эти прокси или политики не существуют: ${names}";

  static String m15(name) =>
      "${name} — встроенное имя политики, его нельзя использовать";

  static String m16(count) =>
      "Проблем: ${count}, применение профиля может завершиться ошибкой";

  static String m17(count) =>
      "${Intl.plural(count, one: '${count} день назад', few: '${count} дня назад', many: '${count} дней назад', other: '${count} дня назад')}";

  static String m18(count) => "${count} дн. назад";

  static String m19(label) =>
      "Вы уверены, что хотите удалить выбранные элементы (${label})?";

  static String m20(label) => "Вы уверены, что хотите удалить «${label}»?";

  static String m21(label) => "Сведения: ${label}";

  static String m22(name) =>
      "Подключение через ${name} ведёт обратно к прокси, который его использует, поэтому соединение остановлено";

  static String m23(label) => "Поле «${label}» не может быть пустым";

  static String m24(count) =>
      "${Intl.plural(count, one: '${count} запись', few: '${count} записи', many: '${count} записей', other: '${count} записи')}";

  static String m25(label) => "«${label}» уже существует";

  static String m26(count) => "Ошибок: ${count}";

  static String m27(label, message) => "${label}: ${message}";

  static String m28(name) => "${name}: уже последняя версия";

  static String m29(name) => "${name}: обновлено";

  static String m30(name) => "Обновление ${name}...";

  static String m31(count) => "Групп: ${count}";

  static String m32(count) => "Тайм-аут: ${count}";

  static String m33(action) =>
      "Уже используется для «${action}». При сохранении будет перенесено сюда.";

  static String m34(modifiers) =>
      "Добавьте хотя бы одну из клавиш: ${modifiers}";

  static String m35(count) =>
      "${Intl.plural(count, one: '${count} час назад', few: '${count} часа назад', many: '${count} часов назад', other: '${count} часа назад')}";

  static String m36(count) => "${count} ч назад";

  static String m37(target) => "${target} — недопустимая политика";

  static String m38(proxyName) => "${proxyName} — недопустимый прокси";

  static String m39(providerName) =>
      "${providerName} — недопустимый провайдер прокси";

  static String m40(ruleSet) => "${ruleSet} — недопустимый набор правил";

  static String m41(subRule) => "${subRule} — недопустимый SUB_RULE";

  static String m42(count) =>
      "${Intl.plural(count, one: '${count} элемент', few: '${count} элемента', many: '${count} элементов', other: '${count} элемента')}";

  static String m43(line, message) => "Строка ${line}: ${message}";

  static String m44(appName) =>
      "1. Откройте Системные настройки > Конфиденциальность и безопасность\n2. Выберите Службы геолокации\n3. Найдите и отметьте ${appName} в списке\n\nПосле настройки вернитесь в приложение и продолжайте работу. Спасибо за сотрудничество.";

  static String m45(label, max) => "«${label}» — не более ${max} символов";

  static String m46(size) => "Освобождено ${size}";

  static String m47(count) =>
      "${Intl.plural(count, one: '${count} минуту назад', few: '${count} минуты назад', many: '${count} минут назад', other: '${count} минуты назад')}";

  static String m48(count) => "${count} мин назад";

  static String m49(count) =>
      "${Intl.plural(count, one: '${count} месяц назад', few: '${count} месяца назад', many: '${count} месяцев назад', other: '${count} месяца назад')}";

  static String m50(count) => "${count} мес. назад";

  static String m51(code) =>
      "Сервер запретил доступ (HTTP ${code}). Возможно, ссылка устарела или учётные данные неверны";

  static String m52(code) => "Сервер отклонил запрос (HTTP ${code})";

  static String m53(code) =>
      "По этому адресу ничего не найдено (HTTP ${code}). Проверьте правильность URL";

  static String m54(detail) => "Сетевой запрос не выполнен: ${detail}";

  static String m55(code) =>
      "На сервере произошла ошибка (HTTP ${code}). Повторите попытку позже";

  static String m56(label) => "Пока нет: ${label}";

  static String m57(label, min, max) =>
      "Значение «${label}» должно быть от ${min} до ${max}";

  static String m58(label) => "Значение «${label}» должно быть числом";

  static String m59(label) =>
      "Значение «${label}» должно быть от 1024 до 49151";

  static String m60(port) => "Порт ${port}";

  static String m61(days) => "Осталось дней: ${days}";

  static String m62(date, days) => "Истекает ${date}, осталось дней: ${days}";

  static String m63(time) => "Обновлено ${time}";

  static String m64(label, profiles) =>
      "«${label}» всё ещё используется профилями: ${profiles}. После удаления они будут работать неправильно. Вы уверены, что хотите удалить его?";

  static String m65(count, label) =>
      "${Intl.plural(count, other: '${label} прокси')}";

  static String m66(name, count) => "${name} и другие (${count} прокси)";

  static String m67(removed) =>
      "Будут удалены прокси: ${removed}. Строка с изменённым именем считается новым прокси, а пользовательские профили, ссылающиеся на удалённые, пометят их как отсутствующие. Применить?";

  static String m68(removed, added) =>
      "Будут удалены прокси: ${removed}. Будут добавлены: ${added}. Строка с изменённым именем считается новым прокси, а пользовательские профили, ссылающиеся на удалённые, пометят их как отсутствующие. Применить?";

  static String m69(label) =>
      "На «${label}» всё ещё ссылаются правила, группы прокси, прокси для подключения, DNS или NTP этого профиля, и после удаления эти ссылки перестанут работать. Вы уверены, что хотите удалить её?";

  static String m70(count, label) =>
      "${Intl.plural(count, one: '${label} группа прокси', few: '${label} группы прокси', many: '${label} групп прокси', other: '${label} группы прокси')}";

  static String m71(maximum) => "Введите целое число от 0 до ${maximum}.";

  static String m72(count, label) =>
      "${Intl.plural(count, one: '${label} правило', few: '${label} правила', many: '${label} правил', other: '${label} правила')}";

  static String m73(appName) => "${appName} (Безопасный режим)";

  static String m74(count) =>
      "${Intl.plural(count, one: '${count} секунда', few: '${count} секунды', many: '${count} секунд', other: '${count} секунды')}";

  static String m75(count) => "Действуют: ${count}";

  static String m76(count) => "Проблем: ${count}";

  static String m77(time) => "Проверено в ${time}";

  static String m78(count) =>
      "${Intl.plural(count, one: '${count} настройка', few: '${count} настройки', many: '${count} настроек', other: '${count} настройки')}";

  static String m79(link) => "Не удалось прочитать прокси из ${link}";

  static String m80(label) => "«${label}» — только одно значение";

  static String m81(value) => "Пик ${value}";

  static String m82(value) => "Всего ${value}";

  static String m83(interval, idleInterval) =>
      "${interval} · бездействие ${idleInterval}";

  static String m84(interval) => "${interval} · бездействие отключено";

  static String m85(label) => "Значение «${label}» должно быть URL";

  static String m86(count) =>
      "${Intl.plural(count, one: '${count} год назад', few: '${count} года назад', many: '${count} лет назад', other: '${count} года назад')}";

  static String m87(count) =>
      "${Intl.plural(count, one: '${count} г. назад', few: '${count} г. назад', many: '${count} л. назад', other: '${count} г. назад')}";

  static String m88(amount, cycle) => "${amount} за ${cycle}, одним платежом";

  static String m89(date) =>
      "Действует до ${date}. Повысить или продлить тариф можно здесь.";

  static String m90(plan) => "Текущий тариф · ${plan}";

  static String m91(days) => "Осталось ${days} дн.";

  static String m92(date) => "Действует до ${date}";

  static String m93(count) => "До ${count} устройств онлайн одновременно";

  static String m94(mbps) => "Скорость до ${mbps} Мбит/с";

  static String m95(gb) => "${gb} ГБ высокоскоростного трафика в месяц";

  static String m96(name) => "Здравствуйте, ${name}.";

  static String m97(rate) => "Учёт ×${rate}";

  static String m98(count) => "Узлов: ${count}";

  static String m99(count) => "/ ${count}";

  static String m100(days) => "Сброс через ${days} дн.";

  static String m101(percent) => "Выгода ${percent}%";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("О программе"),
    "accessControl": MessageLookupByLibrary.simpleMessage("Контроль доступа"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Через VPN проходят только выбранные приложения",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "Контроль доступа выбирает приложения, использующие прокси.",
    ),
    "accessControlDisabledDesc": MessageLookupByLibrary.simpleMessage(
      "Контроль доступа приложений отключён",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Выбранные приложения исключаются из VPN",
    ),
    "accessControlSettings": MessageLookupByLibrary.simpleMessage(
      "Настройки контроля доступа",
    ),
    "accessDenied": MessageLookupByLibrary.simpleMessage("Доступ запрещён"),
    "account": MessageLookupByLibrary.simpleMessage("Аккаунт"),
    "action": MessageLookupByLibrary.simpleMessage("Действие"),
    "actionDelayTest": MessageLookupByLibrary.simpleMessage(
      "Проверить все задержки",
    ),
    "actionDirectMode": MessageLookupByLibrary.simpleMessage("Прямой режим"),
    "actionGlobalMode": MessageLookupByLibrary.simpleMessage(
      "Глобальный режим",
    ),
    "actionMode": MessageLookupByLibrary.simpleMessage("Переключить режим"),
    "actionProxy": MessageLookupByLibrary.simpleMessage("Системный прокси"),
    "actionRuleMode": MessageLookupByLibrary.simpleMessage("Режим правил"),
    "actionStart": MessageLookupByLibrary.simpleMessage("Старт/Стоп"),
    "actionTun": MessageLookupByLibrary.simpleMessage("TUN"),
    "actionUpdateProfiles": MessageLookupByLibrary.simpleMessage(
      "Обновить профили",
    ),
    "actionView": MessageLookupByLibrary.simpleMessage("Показать/Скрыть"),
    "add": MessageLookupByLibrary.simpleMessage("Добавить"),
    "addCustomProxy": MessageLookupByLibrary.simpleMessage("Добавить прокси"),
    "addFilters": MessageLookupByLibrary.simpleMessage("Добавить фильтры"),
    "addNodes": MessageLookupByLibrary.simpleMessage("Добавить узлы"),
    "addOverrideEntry": MessageLookupByLibrary.simpleMessage(
      "Добавить параметр",
    ),
    "addProfile": MessageLookupByLibrary.simpleMessage("Добавить профиль"),
    "addProxies": MessageLookupByLibrary.simpleMessage("Добавить прокси"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Добавить группу прокси",
    ),
    "addRule": MessageLookupByLibrary.simpleMessage("Добавить правило"),
    "addSettingEntry": MessageLookupByLibrary.simpleMessage(
      "Добавить параметр",
    ),
    "addSsid": MessageLookupByLibrary.simpleMessage("Добавить SSID"),
    "addedRules": MessageLookupByLibrary.simpleMessage("Добавленные правила"),
    "additionalParameters": MessageLookupByLibrary.simpleMessage(
      "Дополнительные параметры",
    ),
    "additionalPrefix": MessageLookupByLibrary.simpleMessage("Префикс имени"),
    "additionalSuffix": MessageLookupByLibrary.simpleMessage("Суффикс имени"),
    "address": MessageLookupByLibrary.simpleMessage("Адрес"),
    "addressHelp": MessageLookupByLibrary.simpleMessage("Адрес сервера WebDAV"),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "Введите корректный адрес WebDAV",
    ),
    "advancedConfig": MessageLookupByLibrary.simpleMessage(
      "Расширенная конфигурация",
    ),
    "advancedConfigDesc": MessageLookupByLibrary.simpleMessage(
      "Расширенная конфигурация включает сеть, DNS, добавленные правила и скрипты.",
    ),
    "ageEncryptedProfile": MessageLookupByLibrary.simpleMessage(
      "Зашифрованный профиль",
    ),
    "ageKeyGenerateTitle": MessageLookupByLibrary.simpleMessage(
      "Генерация ключа Age",
    ),
    "ageKeyPairGeneratedSuccess": MessageLookupByLibrary.simpleMessage(
      "Пара ключей X25519 создана, сохраните ее в надежном месте",
    ),
    "agePrivateKeyLabel": MessageLookupByLibrary.simpleMessage(
      "Закрытый ключ Age",
    ),
    "agePrivateKeyRequired": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, сначала введите корректный закрытый ключ Age",
    ),
    "agePublicKeyLabel": MessageLookupByLibrary.simpleMessage(
      "Открытый ключ Age",
    ),
    "ageSecretKey": MessageLookupByLibrary.simpleMessage("Секретный ключ age"),
    "ageSecretKeyInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, введите корректный приватный ключ Age (должен начинаться с AGE-SECRET-KEY-)",
    ),
    "ageSecretKeyOptional": MessageLookupByLibrary.simpleMessage(
      "Приватный ключ Age (необязательно)",
    ),
    "ageSecretKeyRequiredTip": MessageLookupByLibrary.simpleMessage(
      "Профиль зашифрован с помощью age, для расшифровки нужен секретный ключ age",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("Согласен"),
    "allData": MessageLookupByLibrary.simpleMessage("Все данные"),
    "allReferencedProxies": MessageLookupByLibrary.simpleMessage(
      "Все используемые прокси",
    ),
    "allReferencedProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Все используемые провайдеры прокси",
    ),
    "allowBypass": MessageLookupByLibrary.simpleMessage(
      "Разрешить приложениям обходить VPN",
    ),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "При включении некоторые приложения смогут обходить VPN",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("Разрешить LAN"),
    "allowLanAccess": MessageLookupByLibrary.simpleMessage(
      "Разрешить доступ из LAN",
    ),
    "allowLanAccessDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить доступ к внешнему контроллеру из локальной сети",
    ),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить доступ к прокси из локальной сети",
    ),
    "allowedIps": MessageLookupByLibrary.simpleMessage("Разрешённые IP"),
    "alwaysOn": MessageLookupByLibrary.simpleMessage("Всегда включён"),
    "alwaysOnDesc": MessageLookupByLibrary.simpleMessage(
      "Поддерживать VPN-подключение в любых сетевых условиях",
    ),
    "answers": MessageLookupByLibrary.simpleMessage("Ответы"),
    "app": MessageLookupByLibrary.simpleMessage("Приложение"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "Контроль доступа приложений",
    ),
    "appIconDesign": MessageLookupByLibrary.simpleMessage(
      "Дизайн значка приложения",
    ),
    "appProxiesEmpty": MessageLookupByLibrary.simpleMessage(
      "Нет локальных прокси",
    ),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage(
      "Добавлять системный DNS",
    ),
    "appendSystemDnsTip": MessageLookupByLibrary.simpleMessage(
      "Принудительно добавлять системный DNS в конфигурацию",
    ),
    "application": MessageLookupByLibrary.simpleMessage("Приложение"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage(
      "Настройки, связанные с приложением",
    ),
    "ascending": MessageLookupByLibrary.simpleMessage("По возрастанию"),
    "authentication": MessageLookupByLibrary.simpleMessage("Аутентификация"),
    "authenticationDesc": MessageLookupByLibrary.simpleMessage(
      "Аутентификация требует логин и пароль для локального порта прокси.",
    ),
    "authenticationSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Пока включена аутентификация, системный прокси не применяется.",
    ),
    "authorize": MessageLookupByLibrary.simpleMessage("Разрешить"),
    "authorized": MessageLookupByLibrary.simpleMessage("Разрешено"),
    "auto": MessageLookupByLibrary.simpleMessage("Авто"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage(
      "Автопроверка обновлений",
    ),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "Автоматически проверять обновления при запуске приложения",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Автозакрытие соединений",
    ),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Автозакрытие соединений обрывает открытые соединения при смене прокси.",
    ),
    "autoInclude": MessageLookupByLibrary.simpleMessage(
      "Автоматическое включение",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("Автозапуск"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Запускаться автоматически при старте системы",
    ),
    "autoRun": MessageLookupByLibrary.simpleMessage("Автовключение"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "Автовключение запускает прокси при открытии приложения.",
    ),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage(
      "Автонастройка системного DNS",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("Автообновление"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал автообновления",
    ),
    "back": MessageLookupByLibrary.simpleMessage("Назад"),
    "backToDashboard": MessageLookupByLibrary.simpleMessage(
      "Возврат на главную",
    ),
    "backToDashboardDesc": MessageLookupByLibrary.simpleMessage(
      "Перед выходом возвращаться на панель",
    ),
    "backup": MessageLookupByLibrary.simpleMessage("Резервное копирование"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage(
      "Резервное копирование и восстановление",
    ),
    "backupDateDescription": MessageLookupByLibrary.simpleMessage(
      "Местная дата (YYYY-MM-DD)",
    ),
    "backupFromNewerVersion": MessageLookupByLibrary.simpleMessage(
      "Резервная копия создана более новой версией приложения. Обновите приложение перед восстановлением",
    ),
    "backupPlatformDescription": MessageLookupByLibrary.simpleMessage(
      "Текущая платформа",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage(
      "Резервная копия создана",
    ),
    "backupTimeDescription": MessageLookupByLibrary.simpleMessage(
      "Местное время (HHmmss)",
    ),
    "backupVersionDescription": MessageLookupByLibrary.simpleMessage(
      "Версия приложения",
    ),
    "basicConfig": MessageLookupByLibrary.simpleMessage("Базовая конфигурация"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage(
      "Глобальное изменение базовой конфигурации",
    ),
    "basicInfo": MessageLookupByLibrary.simpleMessage("Основная информация"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("Базовые политики"),
    "batchAdd": MessageLookupByLibrary.simpleMessage("Массовое добавление"),
    "batchImport": MessageLookupByLibrary.simpleMessage("Массовый импорт"),
    "batchLinkInputTip": MessageLookupByLibrary.simpleMessage(
      "По одной ссылке на строку",
    ),
    "batchListInputTip": MessageLookupByLibrary.simpleMessage(
      "По одному значению на строку или через запятую",
    ),
    "batchMapInputTip": MessageLookupByLibrary.simpleMessage(
      "По одной записи на строку: ключ, пробел, значение",
    ),
    "batchPreviewTip": m0,
    "batchUrlInputTip": MessageLookupByLibrary.simpleMessage(
      "По одному URL на строку",
    ),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "Игнорирование оптимизации батареи позволяет приложению работать в фоне.",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("Привязать"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage(
      "Режим чёрного списка",
    ),
    "blockConnection": MessageLookupByLibrary.simpleMessage(
      "Заблокировать соединение",
    ),
    "brightness": MessageLookupByLibrary.simpleMessage("Яркость"),
    "browse": MessageLookupByLibrary.simpleMessage("Обзор"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("Исключённые домены"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Исключённые домены действуют только при включённом системном прокси.",
    ),
    "bypassPrivateRoute": MessageLookupByLibrary.simpleMessage(
      "Обходить частные адреса",
    ),
    "bypassPrivateRouteDesc": MessageLookupByLibrary.simpleMessage(
      "При обходе частных адресов адреса LAN, loopback и multicast идут в обход TUN.",
    ),
    "cache": MessageLookupByLibrary.simpleMessage("Кэш"),
    "cacheAlgorithm": MessageLookupByLibrary.simpleMessage("Алгоритм кэша"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "Кэш повреждён. Очистить его?",
    ),
    "cacheMaxSize": MessageLookupByLibrary.simpleMessage("Размер кэша"),
    "cameraPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешите доступ к камере в системных настройках, чтобы сканировать QR-коды, или выберите изображение QR-кода из галереи.",
    ),
    "cameraPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Требуется доступ к камере",
    ),
    "cameraUnavailable": MessageLookupByLibrary.simpleMessage(
      "Камера недоступна",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Отмена"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("Снять выделение"),
    "cannotSave": MessageLookupByLibrary.simpleMessage("Не удалось сохранить"),
    "captureDns": MessageLookupByLibrary.simpleMessage(
      "Перехват системного DNS",
    ),
    "captureDnsDesc": MessageLookupByLibrary.simpleMessage(
      "Перенаправлять все системные DNS-запросы во внутренний модуль DNS",
    ),
    "changeProxyFailedTip": MessageLookupByLibrary.simpleMessage(
      "Не удалось переключить прокси; восстановлен предыдущий выбор",
    ),
    "changelogBreaking": MessageLookupByLibrary.simpleMessage(
      "Важные изменения",
    ),
    "changelogFeatures": MessageLookupByLibrary.simpleMessage("Новые функции"),
    "changelogFixes": MessageLookupByLibrary.simpleMessage("Исправления"),
    "changelogPerformance": MessageLookupByLibrary.simpleMessage(
      "Производительность",
    ),
    "changelogReverts": MessageLookupByLibrary.simpleMessage("Откаты"),
    "checkCertificate": MessageLookupByLibrary.simpleMessage(
      "Проверять TLS-сертификаты",
    ),
    "checkCertificateDesc": MessageLookupByLibrary.simpleMessage(
      "Без проверки TLS-сертификатов подписки и резервные копии уязвимы для атаки «человек посередине».",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("Проверить обновления"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "У вас уже последняя версия",
    ),
    "cipher": MessageLookupByLibrary.simpleMessage("Шифр"),
    "clear": MessageLookupByLibrary.simpleMessage("Очистить"),
    "clearData": MessageLookupByLibrary.simpleMessage("Очистить данные"),
    "clearDataAndExitTip": MessageLookupByLibrary.simpleMessage(
      "Все профили, настройки и локальные данные будут удалены, после чего приложение закроется. Откройте его снова, чтобы начать заново.",
    ),
    "clearDataFailed": m1,
    "clearSearch": MessageLookupByLibrary.simpleMessage("Очистить поиск"),
    "clientFingerprint": MessageLookupByLibrary.simpleMessage(
      "Отпечаток клиента",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage(
      "Экспорт в буфер обмена",
    ),
    "clipboardImport": MessageLookupByLibrary.simpleMessage(
      "Импорт из буфера обмена",
    ),
    "clipboardWriteFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось скопировать в буфер обмена. Возможно, выделение слишком велико",
    ),
    "close": MessageLookupByLibrary.simpleMessage("Закрыть"),
    "closeAll": MessageLookupByLibrary.simpleMessage("Закрыть все"),
    "closeConnections": MessageLookupByLibrary.simpleMessage(
      "Закрыть соединения",
    ),
    "closeConnectionsPrompt": MessageLookupByLibrary.simpleMessage(
      "Закрыть соединения, использующие предыдущий прокси?",
    ),
    "collapse": MessageLookupByLibrary.simpleMessage("Свернуть"),
    "collapseProxyChains": MessageLookupByLibrary.simpleMessage(
      "Сворачивать цепочки прокси",
    ),
    "collapseProxyChainsDesc": MessageLookupByLibrary.simpleMessage(
      "Скрывать промежуточные узлы, если в цепочке прокси больше трёх узлов",
    ),
    "collapseQuickSettingsPanel": MessageLookupByLibrary.simpleMessage(
      "Сворачивать панель быстрых настроек",
    ),
    "collapseQuickSettingsPanelDesc": MessageLookupByLibrary.simpleMessage(
      "Сворачивать панель быстрых настроек после нажатия плитки",
    ),
    "color": MessageLookupByLibrary.simpleMessage("Цвет"),
    "colorStyle": MessageLookupByLibrary.simpleMessage("Стиль палитры"),
    "columns": MessageLookupByLibrary.simpleMessage("Столбцы"),
    "compact": MessageLookupByLibrary.simpleMessage("Компактный"),
    "compatible": MessageLookupByLibrary.simpleMessage("Режим совместимости"),
    "configDataDetected": MessageLookupByLibrary.simpleMessage(
      "В конфигурации обнаружены данные",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("Подтвердить"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите удалить все данные?",
    ),
    "confirmClearSelectedData": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите удалить выбранные данные?",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите удалить эту группу прокси?",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите закрыть текущее окно?",
    ),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите принудительно завершить ядро со сбоем?",
    ),
    "confirmOverwriteTip": MessageLookupByLibrary.simpleMessage(
      "После подтверждения существующие данные будут перезаписаны",
    ),
    "congestionControl": MessageLookupByLibrary.simpleMessage(
      "Управление перегрузкой",
    ),
    "congestionController": MessageLookupByLibrary.simpleMessage(
      "Управление перегрузкой TCP",
    ),
    "congestionControllerDesc": MessageLookupByLibrary.simpleMessage(
      "Управление перегрузкой TCP действует только со стеком mips.",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("Подключено"),
    "connecting": MessageLookupByLibrary.simpleMessage("Подключение…"),
    "connection": MessageLookupByLibrary.simpleMessage("Соединение"),
    "connectionInfo": MessageLookupByLibrary.simpleMessage(
      "Количество подключений",
    ),
    "connectionStats": MessageLookupByLibrary.simpleMessage(
      "Статистика подключений",
    ),
    "connectionStatsDesc": MessageLookupByLibrary.simpleMessage(
      "Подключения, запросы и DNS-запросы",
    ),
    "connections": MessageLookupByLibrary.simpleMessage("Соединения"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Просмотр данных о текущих соединениях",
    ),
    "connectivity": MessageLookupByLibrary.simpleMessage("Подключение: "),
    "content": MessageLookupByLibrary.simpleMessage("Содержимое"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Содержимое не может быть пустым",
    ),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage(
      "Управление глобальными добавленными правилами",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("Копировать"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage(
      "Копировать переменные окружения",
    ),
    "copyLink": MessageLookupByLibrary.simpleMessage("Копировать ссылку"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("Скопировано"),
    "core": MessageLookupByLibrary.simpleMessage("Ядро"),
    "coreBlockedByPolicyTip": m2,
    "coreBlockedBySmartAppControlTip": MessageLookupByLibrary.simpleMessage(
      "Smart App Control в Windows заблокировал неподписанный FlClashCore.exe. Откройте Безопасность Windows → Управление приложениями и браузером → Параметры Smart App Control, выберите «Выкл.» и снова запустите FlClash. Повторно включить Smart App Control без переустановки Windows нельзя.",
    ),
    "coreStatus": MessageLookupByLibrary.simpleMessage("Статус ядра"),
    "country": MessageLookupByLibrary.simpleMessage("Регион"),
    "crashDetected": MessageLookupByLibrary.simpleMessage("Обнаружен сбой"),
    "crashDetectedTip": m3,
    "crashTest": MessageLookupByLibrary.simpleMessage("Тест сбоя"),
    "create": MessageLookupByLibrary.simpleMessage("Создать"),
    "createProfile": MessageLookupByLibrary.simpleMessage("Создать профиль"),
    "createProfileFromUrlTip": m4,
    "creationTime": MessageLookupByLibrary.simpleMessage("Время создания"),
    "currentOutboundDesc": MessageLookupByLibrary.simpleMessage(
      "Содержит кнопку запуска, удалить нельзя",
    ),
    "custom": MessageLookupByLibrary.simpleMessage("Вручную"),
    "customColor": MessageLookupByLibrary.simpleMessage("Свой цвет"),
    "customImportDroppedSubRules": m5,
    "customIssueCoreRejected": m6,
    "customIssueDialerLoop": m7,
    "customIssueDuplicateName": m8,
    "customIssueEmptyName": MessageLookupByLibrary.simpleMessage(
      "Имя не задано",
    ),
    "customIssueGroupLoop": m9,
    "customIssueInvalidEmptyFallback": m10,
    "customIssueInvalidFilter": m11,
    "customIssueMissingDialer": m12,
    "customIssueMissingProviders": m13,
    "customIssueMissingProxies": m14,
    "customIssueNoProxySource": MessageLookupByLibrary.simpleMessage(
      "Не выбраны ни прокси, ни провайдеры прокси, поэтому ядро отклонит эту группу",
    ),
    "customIssueReservedName": m15,
    "customIssuesSummary": m16,
    "customProfile": MessageLookupByLibrary.simpleMessage("Пользовательский"),
    "customProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Группы прокси и правила из прокси приложения и других профилей",
    ),
    "customProfileResources": MessageLookupByLibrary.simpleMessage(
      "Ресурсы пользовательских профилей",
    ),
    "customProfileResourcesDesc": MessageLookupByLibrary.simpleMessage(
      "Ресурсы пользовательских профилей включают прокси, провайдеры правил, фильтры и наборы значков.",
    ),
    "cut": MessageLookupByLibrary.simpleMessage("Вырезать"),
    "dark": MessageLookupByLibrary.simpleMessage("Тёмная"),
    "dashboard": MessageLookupByLibrary.simpleMessage("Панель"),
    "dashboardAddableSection": MessageLookupByLibrary.simpleMessage(
      "Можно добавить",
    ),
    "dataChangedSave": MessageLookupByLibrary.simpleMessage(
      "Обнаружены изменения данных. Сохранить их?",
    ),
    "databaseWriteFailedTip": MessageLookupByLibrary.simpleMessage(
      "Не удалось сохранить изменение; оно отменено",
    ),
    "davDirectory": MessageLookupByLibrary.simpleMessage("Каталог"),
    "daysAgo": m17,
    "daysAgoShort": m18,
    "defaultNameserver": MessageLookupByLibrary.simpleMessage(
      "DNS-сервер по умолчанию",
    ),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Используется для разрешения адресов DNS-серверов",
    ),
    "defaultSelected": MessageLookupByLibrary.simpleMessage(
      "Выбор по умолчанию",
    ),
    "defaultText": MessageLookupByLibrary.simpleMessage("По умолчанию"),
    "definitionNotMap": MessageLookupByLibrary.simpleMessage(
      "Конфигурация должна быть YAML-словарём с полями name и type",
    ),
    "delay": MessageLookupByLibrary.simpleMessage("Задержка"),
    "delayFailed": MessageLookupByLibrary.simpleMessage("Сбой"),
    "delayTest": MessageLookupByLibrary.simpleMessage("Тест задержки"),
    "delete": MessageLookupByLibrary.simpleMessage("Удалить"),
    "deleteMultipTip": m19,
    "deleteTip": m20,
    "desc": MessageLookupByLibrary.simpleMessage(
      "Многоплатформенный прокси-клиент на основе ClashMeta: простой и удобный, с открытым исходным кодом и без рекламы.",
    ),
    "descending": MessageLookupByLibrary.simpleMessage("По убыванию"),
    "destination": MessageLookupByLibrary.simpleMessage("Назначение"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage(
      "GeoIP назначения",
    ),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage(
      "ASN IP назначения",
    ),
    "details": m21,
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "Использует сторонний API; только для справки",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("Режим разработчика"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "Режим разработчика включён.",
    ),
    "dialerProxy": MessageLookupByLibrary.simpleMessage(
      "Прокси для подключения",
    ),
    "dialerProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Прокси для подключения — исход, через который идёт обращение к NTP-серверу.",
    ),
    "dialerProxyLoopStopped": m22,
    "direct": MessageLookupByLibrary.simpleMessage("Прямой"),
    "disableIcmpForwarding": MessageLookupByLibrary.simpleMessage(
      "Отключить пересылку ICMP",
    ),
    "disableIcmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "При отключённой пересылке ICMP TUN сам отвечает на ping, поэтому ping больше не показывает реальную задержку.",
    ),
    "disableKeepAlive": MessageLookupByLibrary.simpleMessage(
      "Отключить TCP keep-alive",
    ),
    "disableUDP": MessageLookupByLibrary.simpleMessage("Отключить UDP"),
    "disabled": MessageLookupByLibrary.simpleMessage("Выключено"),
    "discardChanges": MessageLookupByLibrary.simpleMessage(
      "Отменить изменения?",
    ),
    "disclaimer": MessageLookupByLibrary.simpleMessage(
      "Отказ от ответственности",
    ),
    "disclaimerAcceptContent": MessageLookupByLibrary.simpleMessage(
      "Устанавливая, копируя или используя Программу, вы подтверждаете, что прочитали и приняли это заявление полностью. Если вы не согласны с каким-либо его условием, немедленно прекратите использование и удалите Программу.",
    ),
    "disclaimerAcceptTitle": MessageLookupByLibrary.simpleMessage(
      "Принятие условий",
    ),
    "disclaimerAcknowledgeLabel": MessageLookupByLibrary.simpleMessage(
      "Я прочитал(а) и понимаю это заявление",
    ),
    "disclaimerAcknowledgeTip": MessageLookupByLibrary.simpleMessage(
      "Чтобы подтвердить, что вы ознакомились с ним, прочитайте следующее заявление и отметьте пункт ниже:",
    ),
    "disclaimerAcknowledgeTitle": MessageLookupByLibrary.simpleMessage(
      "Подтвердите заявление",
    ),
    "disclaimerChangesContent": MessageLookupByLibrary.simpleMessage(
      "Разработчики могут изменять это заявление в любом выпуске; изменения вступают в силу с момента публикации выпуска. Продолжая пользоваться Программой после обновления, вы принимаете изменённое заявление.",
    ),
    "disclaimerChangesTitle": MessageLookupByLibrary.simpleMessage(
      "Изменения заявления",
    ),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "Перед использованием FlClash (далее — «Программа») внимательно прочитайте это заявление и убедитесь, что понимаете его полностью. Нажимая «Согласен», вы подтверждаете, что прочитали, поняли и принимаете все приведённые ниже условия. Если вы не согласны, нажмите «Выход» и прекратите использование Программы.",
    ),
    "disclaimerLiabilityContent": MessageLookupByLibrary.simpleMessage(
      "В максимальной степени, допустимой применимым законодательством, ни разработчики, ни участники проекта не несут ответственности за любой прямой, косвенный, случайный, особый, штрафной или последующий ущерб, возникший в результате использования или невозможности использования Программы, включая, помимо прочего, потерю данных, повреждение устройства, сбои сети, прерывание деятельности, упущенную выгоду или связанные с этим правовые споры, даже если они были предупреждены о возможности такого ущерба.",
    ),
    "disclaimerLiabilityTitle": MessageLookupByLibrary.simpleMessage(
      "Ограничение ответственности",
    ),
    "disclaimerLicenseContent": MessageLookupByLibrary.simpleMessage(
      "Программа распространяется с открытым исходным кодом по лицензии GPL-3.0. Вы можете свободно использовать, изменять и распространять её при соблюдении этой лицензии: производные работы также должны распространяться по GPL-3.0 с сохранением уведомлений об авторских правах.\n\nСторонние компоненты Программы, включая ядро Clash.Meta, распространяются по своим собственным лицензиям. Авторы оригинала не несут ответственности за проблемы, возникшие в изменённых или распространяемых третьими лицами версиях.",
    ),
    "disclaimerLicenseTitle": MessageLookupByLibrary.simpleMessage(
      "Лицензия с открытым исходным кодом",
    ),
    "disclaimerNoServiceStatement": MessageLookupByLibrary.simpleMessage(
      "Сама Программа не предоставляет прокси-серверы, узлы, подписки или услуги доступа к сети и не состоит в партнёрских, агентских или гарантийных отношениях с поставщиками таких услуг.",
    ),
    "disclaimerPrivacyContent": MessageLookupByLibrary.simpleMessage(
      "Программа не собирает и не отправляет адреса ваших подписок, сведения об узлах, содержимое конфигураций, посещённые сайты, записи о подключениях, содержимое трафика и журналы. Эти данные хранятся только на вашем устройстве, и у разработчиков нет к ним доступа.\n\nПрограмма обращается к сети только при использовании соответствующих функций, например загружает указанный вами адрес подписки при обновлении профиля или обращается к GitHub при проверке обновлений.\n\nПрограмма не содержит никаких сервисов статистики или отчётов о сбоях ни на одной платформе.",
    ),
    "disclaimerPrivacyTitle": MessageLookupByLibrary.simpleMessage(
      "Сбор данных и конфиденциальность",
    ),
    "disclaimerResponsibilityContent": MessageLookupByLibrary.simpleMessage(
      "Вы самостоятельно убеждаетесь, что использование Программы законно в вашей стране или регионе, и единолично несёте юридическую ответственность за все действия с ней и их последствия.\n\nПодписки, узлы и конфигурации, которые вы импортируете, выбираете вы сами. Законность их источника, безопасность содержимого и надёжность сервиса — вопрос между вами и их поставщиками.",
    ),
    "disclaimerResponsibilityTitle": MessageLookupByLibrary.simpleMessage(
      "Ваша ответственность",
    ),
    "disclaimerRestateHint": MessageLookupByLibrary.simpleMessage(
      "Введите заявление выше",
    ),
    "disclaimerRestateMismatch": MessageLookupByLibrary.simpleMessage(
      "Не совпадает с текстом заявления",
    ),
    "disclaimerRestateTip": MessageLookupByLibrary.simpleMessage(
      "Чтобы подтвердить, что вы ознакомились с ним, полностью введите следующее заявление в поле ниже:",
    ),
    "disclaimerRestateTitle": MessageLookupByLibrary.simpleMessage(
      "Повторите заявление",
    ),
    "disclaimerSoftwareContent": MessageLookupByLibrary.simpleMessage(
      "Программа — это клиент сетевого прокси с открытым исходным кодом на основе ядра Clash.Meta (mihomo). Она предоставляет только локальные инструменты: управление конфигурациями, маршрутизацию по правилам и пересылку трафика.",
    ),
    "disclaimerSoftwareTitle": MessageLookupByLibrary.simpleMessage(
      "Характер программы",
    ),
    "disclaimerThirdPartyContent": MessageLookupByLibrary.simpleMessage(
      "Ссылки на подписки, файлы конфигурации, наборы правил, скрипты, внешние ресурсы и внешние ссылки предоставляются третьими лицами. Разработчики не могут проверять и не проверяют их законность, точность, безопасность и доступность и не дают на них никаких гарантий.\n\nУтечка данных, финансовые потери, блокировка аккаунта или иной ущерб, вызванные сторонним контентом, урегулируются между вами и третьим лицом; разработчики не несут за это никакой ответственности.",
    ),
    "disclaimerThirdPartyTitle": MessageLookupByLibrary.simpleMessage(
      "Сторонний контент",
    ),
    "disclaimerUsageContent": MessageLookupByLibrary.simpleMessage(
      "Программа предназначена только для некоммерческого использования: обучения, обмена опытом и технических исследований. Любое коммерческое использование строго запрещено, включая, помимо прочего, платное распространение, продажу в комплекте, использование в составе коммерческого сервиса или ведение деятельности от имени Программы. Любая коммерческая деятельность не имеет отношения к Программе и её разработчикам.\n\nСтрого запрещено использовать Программу для действий, нарушающих законы вашей страны или региона, включая, помимо прочего, обход законно установленных ограничений доступа к сети, распространение незаконной информации, сетевые атаки и нарушение законных прав других лиц.",
    ),
    "disclaimerUsageTitle": MessageLookupByLibrary.simpleMessage(
      "Ограничения использования",
    ),
    "disclaimerWarrantyContent": MessageLookupByLibrary.simpleMessage(
      "Программа предоставляется «как есть» и «по мере доступности», без каких-либо явных или подразумеваемых гарантий, включая, помимо прочего, гарантии товарной пригодности, пригодности для определённой цели, ненарушения прав, бесперебойной работы, отсутствия ошибок и уязвимостей.\n\nРазработчики не гарантируют, что Программа будет соответствовать вашим потребностям или работать без сбоев и ошибок.",
    ),
    "disclaimerWarrantyTitle": MessageLookupByLibrary.simpleMessage(
      "Отсутствие гарантий",
    ),
    "disconnected": MessageLookupByLibrary.simpleMessage("Отключено"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "Доступна новая версия",
    ),
    "dnsDesc": MessageLookupByLibrary.simpleMessage(
      "Настройки, связанные с DNS",
    ),
    "dnsHijack": MessageLookupByLibrary.simpleMessage("Перехват DNS"),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "Без этого параметра TUN перехватывает все DNS-запросы на порт 53 (any:53).",
    ),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("Перехват DNS"),
    "dnsIPv6Desc": MessageLookupByLibrary.simpleMessage(
      "Если выключено, запросы AAAA возвращают пустой результат",
    ),
    "dnsMode": MessageLookupByLibrary.simpleMessage("Режим DNS"),
    "dnsOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Добавленные здесь параметры заменяют DNS всех профилей из URL и файлов; остальные остаются такими, как в профиле. DNS пользовательского профиля задаётся в его содержимом.",
    ),
    "dnsQueries": MessageLookupByLibrary.simpleMessage("DNS-запросы"),
    "dnsQueriesDesc": MessageLookupByLibrary.simpleMessage(
      "Записи DNS-разрешения ядра",
    ),
    "docked": MessageLookupByLibrary.simpleMessage("Закреплённая"),
    "domain": MessageLookupByLibrary.simpleMessage("Домен"),
    "done": MessageLookupByLibrary.simpleMessage("Готово"),
    "download": MessageLookupByLibrary.simpleMessage("Загрузка"),
    "downloadBandwidth": MessageLookupByLibrary.simpleMessage(
      "Скорость загрузки",
    ),
    "downloadSpeed": MessageLookupByLibrary.simpleMessage(
      "Скорость скачивания",
    ),
    "downloadTraffic": MessageLookupByLibrary.simpleMessage("Входящий трафик"),
    "duration": MessageLookupByLibrary.simpleMessage("Длительность"),
    "easyTierConnectionLatency": MessageLookupByLibrary.simpleMessage(
      "Задержка соединения",
    ),
    "easyTierDnsZone": MessageLookupByLibrary.simpleMessage("DNS-зона"),
    "easyTierFeatureFlags": MessageLookupByLibrary.simpleMessage(
      "Флаги функций",
    ),
    "easyTierInstanceId": MessageLookupByLibrary.simpleMessage("ID экземпляра"),
    "easyTierLatencyFirstPathLatency": MessageLookupByLibrary.simpleMessage(
      "Задержка пути (приоритет задержки)",
    ),
    "easyTierListeners": MessageLookupByLibrary.simpleMessage(
      "Адреса прослушивания",
    ),
    "easyTierLocalEndpoint": MessageLookupByLibrary.simpleMessage(
      "Локальная конечная точка",
    ),
    "easyTierLossRate": MessageLookupByLibrary.simpleMessage("Потери пакетов"),
    "easyTierMinDirectLatency": MessageLookupByLibrary.simpleMessage(
      "Минимальная задержка прямого соединения",
    ),
    "easyTierNextHop": MessageLookupByLibrary.simpleMessage(
      "ID следующего узла",
    ),
    "easyTierPathLatency": MessageLookupByLibrary.simpleMessage(
      "Задержка пути (приоритет числа переходов)",
    ),
    "easyTierPeerId": MessageLookupByLibrary.simpleMessage("ID узла"),
    "easyTierProtocol": MessageLookupByLibrary.simpleMessage(
      "Транспортный протокол",
    ),
    "easyTierPublicServer": MessageLookupByLibrary.simpleMessage(
      "Публичный сервер",
    ),
    "easyTierRemoteEndpoint": MessageLookupByLibrary.simpleMessage(
      "Удалённая конечная точка",
    ),
    "easyTierRouteCost": MessageLookupByLibrary.simpleMessage(
      "Стоимость маршрута",
    ),
    "easyTierRxPackets": MessageLookupByLibrary.simpleMessage(
      "Получено пакетов",
    ),
    "easyTierTxPackets": MessageLookupByLibrary.simpleMessage(
      "Отправлено пакетов",
    ),
    "edit": MessageLookupByLibrary.simpleMessage("Редактировать"),
    "editDashboard": MessageLookupByLibrary.simpleMessage("Изменить панель"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage(
      "Редактировать глобальные правила",
    ),
    "editProxy": MessageLookupByLibrary.simpleMessage("Редактировать прокси"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Редактировать группу прокси",
    ),
    "editRule": MessageLookupByLibrary.simpleMessage("Редактировать правило"),
    "editSsid": MessageLookupByLibrary.simpleMessage("Изменить SSID"),
    "editorUnavailable": MessageLookupByLibrary.simpleMessage(
      "Редактор недоступен",
    ),
    "elapsed": MessageLookupByLibrary.simpleMessage("Время"),
    "emptyFallback": MessageLookupByLibrary.simpleMessage(
      "Резерв для пустой группы",
    ),
    "emptyTip": m23,
    "en": MessageLookupByLibrary.simpleMessage("Английский"),
    "enableExternalController": MessageLookupByLibrary.simpleMessage(
      "Включить внешний контроллер",
    ),
    "enabled": MessageLookupByLibrary.simpleMessage("Включено"),
    "endpointIndependentNat": MessageLookupByLibrary.simpleMessage(
      "Улучшенный NAT",
    ),
    "endpointIndependentNatDesc": MessageLookupByLibrary.simpleMessage(
      "Оптимизировать подключения приложений UDP и P2P",
    ),
    "endpoints": MessageLookupByLibrary.simpleMessage("Конечные точки"),
    "enforceRoutes": MessageLookupByLibrary.simpleMessage(
      "Принудительная маршрутизация",
    ),
    "enforceRoutesDesc": MessageLookupByLibrary.simpleMessage(
      "Направлять трафик через туннель, даже если существуют более конкретные маршруты",
    ),
    "entries": MessageLookupByLibrary.simpleMessage(" записей"),
    "entriesCount": m24,
    "error": MessageLookupByLibrary.simpleMessage("Ошибка"),
    "errorDetails": MessageLookupByLibrary.simpleMessage("Подробности ошибки"),
    "es": MessageLookupByLibrary.simpleMessage("Испанский"),
    "exclude": MessageLookupByLibrary.simpleMessage("Скрыть из недавних задач"),
    "excludeAPNs": MessageLookupByLibrary.simpleMessage("Исключить APNs"),
    "excludeAPNsDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить трафику Apple Push-уведомлений обходить туннель",
    ),
    "excludeCellularServices": MessageLookupByLibrary.simpleMessage(
      "Исключить сотовые сервисы",
    ),
    "excludeCellularServicesDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить трафику сотовых сервисов, таких как Wi-Fi вызовы, обходить туннель",
    ),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "Скрывать приложение из недавних задач, когда оно в фоне",
    ),
    "excludeDeviceCommunication": MessageLookupByLibrary.simpleMessage(
      "Исключить межустройственную связь",
    ),
    "excludeDeviceCommunicationDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить трафику AirDrop, AirPlay и другой межустройственной связи обходить туннель",
    ),
    "excludeDstPort": MessageLookupByLibrary.simpleMessage(
      "Исключённые порты назначения",
    ),
    "excludeDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "Трафик на исключённые порты назначения идёт в обход TUN.",
    ),
    "excludeFilter": MessageLookupByLibrary.simpleMessage("Фильтр исключения"),
    "excludeInterface": MessageLookupByLibrary.simpleMessage(
      "Исключённые интерфейсы",
    ),
    "excludeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "Трафик с исключённых интерфейсов, например с docker0, идёт в обход TUN.",
    ),
    "excludeLocalNetworks": MessageLookupByLibrary.simpleMessage(
      "Исключить локальные сети",
    ),
    "excludeLocalNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить прямой доступ к устройствам в локальной сети",
    ),
    "excludeProxyFilter": MessageLookupByLibrary.simpleMessage(
      "Фильтр исключения узлов",
    ),
    "excludeSrcPort": MessageLookupByLibrary.simpleMessage(
      "Исключённые исходные порты",
    ),
    "excludeSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "Трафик с исключённых исходных портов идёт в обход TUN.",
    ),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("Исключённые SSID"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "При подключении к Wi-Fi с исключённым SSID состояние работы приложения переключается автоматически.",
    ),
    "excludeType": MessageLookupByLibrary.simpleMessage("Исключаемые типы"),
    "excludeUid": MessageLookupByLibrary.simpleMessage(
      "Исключённые ID пользователей",
    ),
    "excludeUidDesc": MessageLookupByLibrary.simpleMessage(
      "Трафик процессов исключённых ID пользователей идёт в обход TUN.",
    ),
    "existsTip": m25,
    "exit": MessageLookupByLibrary.simpleMessage("Выход"),
    "exitFullScreen": MessageLookupByLibrary.simpleMessage(
      "Выйти из полноэкранного режима",
    ),
    "exitNodes": MessageLookupByLibrary.simpleMessage("Выходные узлы"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("Ожидаемый статус"),
    "expireTime": MessageLookupByLibrary.simpleMessage("Срок действия"),
    "exportFile": MessageLookupByLibrary.simpleMessage("Экспорт файла"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("Экспорт логов"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("Экспорт выполнен"),
    "extend": MessageLookupByLibrary.simpleMessage("Расширение"),
    "extendMode": MessageLookupByLibrary.simpleMessage("Режим расширения"),
    "extendScript": MessageLookupByLibrary.simpleMessage("Скрипт расширения"),
    "externalController": MessageLookupByLibrary.simpleMessage(
      "Внешний контроллер",
    ),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "Внешний контроллер позволяет управлять ядром через порт 9090.",
    ),
    "externalControllerSecret": MessageLookupByLibrary.simpleMessage(
      "Секрет внешнего контроллера",
    ),
    "externalFetch": MessageLookupByLibrary.simpleMessage("Внешнее получение"),
    "externalLink": MessageLookupByLibrary.simpleMessage("Внешняя ссылка"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("Очень крупный"),
    "fade": MessageLookupByLibrary.simpleMessage("Растворение"),
    "failedCount": m26,
    "failedItem": m27,
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Фильтр Fake-IP"),
    "fakeipFilterDesc": MessageLookupByLibrary.simpleMessage(
      "Совпавшие домены в режиме Fake IP получают реальные IP-адреса вместо Fake IP",
    ),
    "fakeipFilterMode": MessageLookupByLibrary.simpleMessage(
      "Режим фильтра Fake-IP",
    ),
    "fakeipFilterModeDesc": MessageLookupByLibrary.simpleMessage(
      "В режиме фильтра Fake-IP blacklist исключает совпадения, whitelist применяется только к ним, rule — по правилам.",
    ),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Диапазон Fake-IP"),
    "fakeipRange6": MessageLookupByLibrary.simpleMessage(
      "Диапазон Fake-IP (IPv6)",
    ),
    "fakeipTtl": MessageLookupByLibrary.simpleMessage("TTL Fake-IP"),
    "fallback": MessageLookupByLibrary.simpleMessage("Fallback"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Обычно зарубежный DNS",
    ),
    "fallbackDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Совпавшие домены используют fallback напрямую, без запроса к nameserver",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("Фильтр fallback"),
    "fallbackGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Проверяет результаты nameserver по коду GeoIP; для адресов вне этого региона используется fallback",
    ),
    "fallbackGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Домены из этих категорий GeoSite напрямую используют fallback",
    ),
    "fallbackIpcidrDesc": MessageLookupByLibrary.simpleMessage(
      "Результаты nameserver из этих префиксов CIDR заменяются результатами fallback",
    ),
    "features": MessageLookupByLibrary.simpleMessage("Возможности"),
    "file": MessageLookupByLibrary.simpleMessage("Файл"),
    "fileDesc": MessageLookupByLibrary.simpleMessage(
      "Загрузить файл профиля напрямую",
    ),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "Файл изменён. Сохранить изменения?",
    ),
    "fileName": MessageLookupByLibrary.simpleMessage("Имя файла"),
    "filter": MessageLookupByLibrary.simpleMessage("Фильтр"),
    "filters": MessageLookupByLibrary.simpleMessage("Фильтры"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("Поиск процесса"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "При включении возможна небольшая потеря производительности",
    ),
    "floating": MessageLookupByLibrary.simpleMessage("Плавающая"),
    "followProfile": MessageLookupByLibrary.simpleMessage("Как в профиле"),
    "followSystem": MessageLookupByLibrary.simpleMessage("Как в системе"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("Шрифт"),
    "fontSize": MessageLookupByLibrary.simpleMessage("Размер"),
    "forceDnsMapping": MessageLookupByLibrary.simpleMessage(
      "Принудительно для DNS-сопоставлений",
    ),
    "forceDnsMappingDesc": MessageLookupByLibrary.simpleMessage(
      "«Принудительно для DNS-сопоставлений» анализирует и соединения, домен которых получен из DNS-сопоставления.",
    ),
    "forceDomain": MessageLookupByLibrary.simpleMessage(
      "Принудительные домены",
    ),
    "forceDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Принудительные домены тоже анализируются; остальные соединения с доменом не затрагиваются.",
    ),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите принудительно перезапустить ядро?",
    ),
    "fr": MessageLookupByLibrary.simpleMessage("Французский"),
    "general": MessageLookupByLibrary.simpleMessage("Общие"),
    "generalDesc": MessageLookupByLibrary.simpleMessage(
      "Общие настройки приложения и ядра",
    ),
    "generateFromPrivateKey": MessageLookupByLibrary.simpleMessage(
      "Создать из закрытого ключа Age",
    ),
    "generateSecret": MessageLookupByLibrary.simpleMessage("Создать"),
    "geoAutoUpdate": MessageLookupByLibrary.simpleMessage("Автообновление"),
    "geoAutoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал автообновления",
    ),
    "geoAutoUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "Интервал автообновления должен быть больше 0",
    ),
    "geoOptions": MessageLookupByLibrary.simpleMessage("Настройки Geo"),
    "geoResources": MessageLookupByLibrary.simpleMessage("Geo"),
    "geoSkipped": m28,
    "geoUpdated": m29,
    "geoUpdating": m30,
    "geodataLoader": MessageLookupByLibrary.simpleMessage(
      "Geo: экономия памяти",
    ),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "При включении используется Geo-загрузчик с низким потреблением памяти",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("Код GeoIP"),
    "geositeMatcher": MessageLookupByLibrary.simpleMessage(
      "Высокопроизводительный Geo-сопоставитель",
    ),
    "geositeMatcherDesc": MessageLookupByLibrary.simpleMessage(
      "При включении для сопоставления используется алгоритм минимального совершенного хеша",
    ),
    "global": MessageLookupByLibrary.simpleMessage("Глобальный"),
    "go": MessageLookupByLibrary.simpleMessage("Перейти"),
    "goDownload": MessageLookupByLibrary.simpleMessage("Скачать"),
    "goToConfigureAddedRules": MessageLookupByLibrary.simpleMessage(
      "Перейти к настройке добавленных правил",
    ),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage(
      "Перейти к настройке скрипта",
    ),
    "goroutineInfo": MessageLookupByLibrary.simpleMessage("Количество горутин"),
    "grid": MessageLookupByLibrary.simpleMessage("Сетка"),
    "groupCount": m31,
    "groupCountUnit": MessageLookupByLibrary.simpleMessage("групп"),
    "groupTimeoutCount": m32,
    "hasCacheChange": MessageLookupByLibrary.simpleMessage(
      "Кэшировать изменения?",
    ),
    "hashByInUser": MessageLookupByLibrary.simpleMessage(
      "Хешировать по пользователю входящего подключения",
    ),
    "header": MessageLookupByLibrary.simpleMessage("Заголовок"),
    "healthCheck": MessageLookupByLibrary.simpleMessage("Проверка состояния"),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "Служба Helper недоступна, поэтому TUN-режим включить нельзя. Переустановите FlClash.",
    ),
    "hex": MessageLookupByLibrary.simpleMessage("Hex"),
    "hide": MessageLookupByLibrary.simpleMessage("Скрыть"),
    "hideFromList": MessageLookupByLibrary.simpleMessage("Скрыть из списка"),
    "hideIp": MessageLookupByLibrary.simpleMessage("Скрыть IP"),
    "hidePassword": MessageLookupByLibrary.simpleMessage("Скрыть пароль"),
    "hideTimeoutProxies": MessageLookupByLibrary.simpleMessage(
      "Скрывать прокси с таймаутом",
    ),
    "hideTimeoutProxiesDesc": MessageLookupByLibrary.simpleMessage(
      "Не показывать прокси, у которых последний тест задержки завершился таймаутом",
    ),
    "hideUnavailable": MessageLookupByLibrary.simpleMessage("Скрыть таймаут"),
    "highPriorityAutoLaunch": MessageLookupByLibrary.simpleMessage(
      "Автозапуск с высоким приоритетом",
    ),
    "highPriorityAutoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Использовать задачу Windows для более раннего запуска",
    ),
    "hopInterval": MessageLookupByLibrary.simpleMessage("Интервал перескока"),
    "host": MessageLookupByLibrary.simpleMessage("Хост"),
    "hostname": MessageLookupByLibrary.simpleMessage("Имя хоста"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("Добавить записи hosts"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage(
      "Конфликт горячих клавиш",
    ),
    "hotkeyConflictWith": m33,
    "hotkeyDesc": MessageLookupByLibrary.simpleMessage(
      "Глобальные горячие клавиши работают, даже когда окно скрыто. Нажмите на действие, чтобы записать сочетание клавиш.",
    ),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage("Горячие клавиши"),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "Управление приложением с клавиатуры",
    ),
    "hotkeyNeedsModifier": m34,
    "hotkeyNotSet": MessageLookupByLibrary.simpleMessage("Не задано"),
    "hotkeyUnavailable": MessageLookupByLibrary.simpleMessage(
      "Не зарегистрировано: сочетание может быть занято другим приложением",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("часов"),
    "hoursAgo": m35,
    "hoursAgoShort": m36,
    "hue": MessageLookupByLibrary.simpleMessage("Оттенок"),
    "icmpForwarding": MessageLookupByLibrary.simpleMessage("Пересылка ICMP"),
    "icmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "Включить поддержку ICMP Ping",
    ),
    "icon": MessageLookupByLibrary.simpleMessage("Значок"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("История значков"),
    "iconSets": MessageLookupByLibrary.simpleMessage("Наборы значков"),
    "iconSetsEmptyTip": MessageLookupByLibrary.simpleMessage(
      "Наборов значков пока нет. Добавьте их в разделе «Ресурсы пользовательских профилей → Наборы значков»",
    ),
    "iconSource": MessageLookupByLibrary.simpleMessage("Источник иконки"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("Стиль значков"),
    "iconStyleFilled": MessageLookupByLibrary.simpleMessage("С подложкой"),
    "iconStyleHidden": MessageLookupByLibrary.simpleMessage("Скрыто"),
    "iconStylePlain": MessageLookupByLibrary.simpleMessage("Без подложки"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("URL значка"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "Игнорировать оптимизацию батареи",
    ),
    "ignoreCertificateErrors": MessageLookupByLibrary.simpleMessage(
      "Игнорировать проверку сертификатов",
    ),
    "ignoreCertificateErrorsDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить HTTPS-соединения с недействительными сертификатами. Это снижает безопасность",
    ),
    "import": MessageLookupByLibrary.simpleMessage("Импорт"),
    "importConfigInvalid": MessageLookupByLibrary.simpleMessage(
      "Этот файл не является конфигурацией, которую можно импортировать",
    ),
    "importConfigReplaceTip": MessageLookupByLibrary.simpleMessage(
      "Импорт заменит текущие группы прокси, правила и настройки этого профиля",
    ),
    "importFile": MessageLookupByLibrary.simpleMessage("Импорт из файла"),
    "importFromLink": MessageLookupByLibrary.simpleMessage("Импорт по ссылке"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("Импорт из URL"),
    "importUrl": MessageLookupByLibrary.simpleMessage("Импорт по URL"),
    "inbound": MessageLookupByLibrary.simpleMessage("Входящие"),
    "includeAllNetworks": MessageLookupByLibrary.simpleMessage(
      "Включить все сети",
    ),
    "includeAllNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "Маршрутизировать весь сетевой трафик через туннель, включая локальные и сотовые сервисы",
    ),
    "includeAllProxies": MessageLookupByLibrary.simpleMessage(
      "Включить все прокси",
    ),
    "includeAllProxiesTip": MessageLookupByLibrary.simpleMessage(
      "Подключает все прокси вне групп; ниже можно добавить дополнительные группы прокси",
    ),
    "includeAllProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Включить всех провайдеров прокси",
    ),
    "includeAllProxyProvidersTip": MessageLookupByLibrary.simpleMessage(
      "При включении переопределяет подключённых провайдеров прокси",
    ),
    "includeInterface": MessageLookupByLibrary.simpleMessage(
      "Включённые интерфейсы",
    ),
    "includeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "Через TUN идёт только трафик с включённых интерфейсов, а исключённые интерфейсы больше не действуют.",
    ),
    "includeUid": MessageLookupByLibrary.simpleMessage(
      "Включённые ID пользователей",
    ),
    "includeUidDesc": MessageLookupByLibrary.simpleMessage(
      "Через TUN идёт только трафик процессов включённых ID пользователей.",
    ),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("Бессрочно"),
    "init": MessageLookupByLibrary.simpleMessage("Инициализация"),
    "initFailed": MessageLookupByLibrary.simpleMessage("Не удалось запустить"),
    "initFailedTip": MessageLookupByLibrary.simpleMessage(
      "При запуске FlClash произошла ошибка, и работа не может быть продолжена. Скопируйте подробности, чтобы сообщить о проблеме. Если ошибка повторяется, очистка данных обычно позволяет снова запустить приложение.",
    ),
    "initialize": MessageLookupByLibrary.simpleMessage("Инициализировать"),
    "initiator": MessageLookupByLibrary.simpleMessage("Инициатор"),
    "initiatorShort": MessageLookupByLibrary.simpleMessage("Источник"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage(
      "Введите корректную горячую клавишу",
    ),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage(
      "Введите название группы прокси",
    ),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage(
      "Введите содержимое правила",
    ),
    "installedAppsPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "Разрешение на список приложений отклонено, поэтому установленные приложения недоступны. Предоставьте его вручную в системных настройках.",
    ),
    "installedAppsPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Эта система не выдаёт список установленных приложений без разрешения. Предоставьте его, чтобы настроить прокси для отдельных приложений.",
    ),
    "installedAppsPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Требуется разрешение на список приложений",
    ),
    "installedFonts": MessageLookupByLibrary.simpleMessage(
      "Установленные шрифты",
    ),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage("Умный выбор"),
    "interfaceName": MessageLookupByLibrary.simpleMessage("Имя интерфейса"),
    "interfaceNameDesc": MessageLookupByLibrary.simpleMessage(
      "Имя интерфейса задаёт сетевой интерфейс для исходящих соединений.",
    ),
    "interfaceNameMode": MessageLookupByLibrary.simpleMessage(
      "Исходящий интерфейс",
    ),
    "interfaceNameModeClear": MessageLookupByLibrary.simpleMessage("Очистить"),
    "interfaceNameModeCustom": MessageLookupByLibrary.simpleMessage("Вручную"),
    "interfaceNameModeFollow": MessageLookupByLibrary.simpleMessage(
      "Как в конфигурации",
    ),
    "internet": MessageLookupByLibrary.simpleMessage("Интернет"),
    "interval": MessageLookupByLibrary.simpleMessage("Интервал"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("Внутренний IP"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage(
      "Недопустимый файл резервной копии",
    ),
    "invalidBackupFileName": MessageLookupByLibrary.simpleMessage(
      "Введите допустимое имя файла без разделителей пути и специальных символов, длиной до 255 байт.",
    ),
    "invalidCidrContent": MessageLookupByLibrary.simpleMessage(
      "Введите диапазон IP в формате CIDR, например 192.168.0.0/16",
    ),
    "invalidDavDirectory": MessageLookupByLibrary.simpleMessage(
      "Введите допустимый каталог без сегментов . или .., обратных косых черт и специальных символов.",
    ),
    "invalidDscpContent": MessageLookupByLibrary.simpleMessage(
      "Метка DSCP не может превышать 63",
    ),
    "invalidHostContent": MessageLookupByLibrary.simpleMessage(
      "Введите домен или IP-адрес",
    ),
    "invalidIconSet": MessageLookupByLibrary.simpleMessage(
      "Это не набор значков",
    ),
    "invalidLinkTip": MessageLookupByLibrary.simpleMessage(
      "Это не ссылка на подписку и не ссылка на прокси",
    ),
    "invalidListenContent": MessageLookupByLibrary.simpleMessage(
      "Введите адрес и порт, например 0.0.0.0:1053",
    ),
    "invalidNetworkContent": MessageLookupByLibrary.simpleMessage(
      "Поддерживаются только tcp и udp",
    ),
    "invalidPolicy": m37,
    "invalidPortRangeContent": MessageLookupByLibrary.simpleMessage(
      "Введите порт или диапазон, например 443 или 8000-9000",
    ),
    "invalidProfileQrcode": MessageLookupByLibrary.simpleMessage(
      "Этот QR-код не содержит ссылку на профиль",
    ),
    "invalidProxy": m38,
    "invalidProxyProvider": m39,
    "invalidRangeContent": MessageLookupByLibrary.simpleMessage(
      "Введите числа или диапазоны, например 80 или 8000-9000, через /",
    ),
    "invalidRuleSet": m40,
    "invalidSubRule": m41,
    "ipAddress": MessageLookupByLibrary.simpleMessage("IP-адрес"),
    "ipAsn": MessageLookupByLibrary.simpleMessage("ASN"),
    "ipFlagAbuser": MessageLookupByLibrary.simpleMessage("Злоупотребления"),
    "ipFlagProxy": MessageLookupByLibrary.simpleMessage("Прокси"),
    "ipFlagTor": MessageLookupByLibrary.simpleMessage("Tor"),
    "ipFlagVpn": MessageLookupByLibrary.simpleMessage("VPN"),
    "ipFlags": MessageLookupByLibrary.simpleMessage("Метки"),
    "ipOrganization": MessageLookupByLibrary.simpleMessage("Организация"),
    "ipQualityFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось определить тип IP",
    ),
    "ipQualityGood": MessageLookupByLibrary.simpleMessage("Хороший"),
    "ipQualityLevel": MessageLookupByLibrary.simpleMessage("Уровень"),
    "ipQualityNormal": MessageLookupByLibrary.simpleMessage("Обычный"),
    "ipQualityRetry": MessageLookupByLibrary.simpleMessage("Проверить снова"),
    "ipQualityRisky": MessageLookupByLibrary.simpleMessage("Рискованный"),
    "ipQualityShort": MessageLookupByLibrary.simpleMessage("Качество"),
    "ipQualitySource": MessageLookupByLibrary.simpleMessage("Источник ответа"),
    "ipQualitySources": MessageLookupByLibrary.simpleMessage("Источники"),
    "ipSourceIpMismatch": MessageLookupByLibrary.simpleMessage(
      "Другой исходящий IP",
    ),
    "ipSourceNoType": MessageLookupByLibrary.simpleMessage("Тип не определён"),
    "ipSourceRateLimited": MessageLookupByLibrary.simpleMessage(
      "Лимит запросов",
    ),
    "ipType": MessageLookupByLibrary.simpleMessage("Тип"),
    "ipTypeBusiness": MessageLookupByLibrary.simpleMessage("Бизнес"),
    "ipTypeHosting": MessageLookupByLibrary.simpleMessage("Дата-центр"),
    "ipTypeMobile": MessageLookupByLibrary.simpleMessage("Мобильная сеть"),
    "ipTypeResidential": MessageLookupByLibrary.simpleMessage("Домашний"),
    "ipTypeUnknown": MessageLookupByLibrary.simpleMessage("Тип неизвестен"),
    "ipVersion": MessageLookupByLibrary.simpleMessage("Версия IP"),
    "ipcidr": MessageLookupByLibrary.simpleMessage("IP/CIDR"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "Трафик IPv6 принимается, только когда IPv6 включён.",
    ),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "При включённом IPv6 VPN принимает входящий IPv6.",
    ),
    "ipv6Timeout": MessageLookupByLibrary.simpleMessage("Тайм-аут IPv6 (мс)"),
    "itemsCount": m42,
    "ja": MessageLookupByLibrary.simpleMessage("Японский"),
    "justNow": MessageLookupByLibrary.simpleMessage("Только что"),
    "keepAliveIdle": MessageLookupByLibrary.simpleMessage(
      "Простой TCP keep-alive",
    ),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "Интервал TCP keep-alive",
    ),
    "key": MessageLookupByLibrary.simpleMessage("Ключ"),
    "ko": MessageLookupByLibrary.simpleMessage("Корейский"),
    "label": MessageLookupByLibrary.simpleMessage("Метка"),
    "language": MessageLookupByLibrary.simpleMessage("Язык"),
    "large": MessageLookupByLibrary.simpleMessage("Крупный"),
    "lastUpdated": MessageLookupByLibrary.simpleMessage("Последнее обновление"),
    "launchInterrupted": MessageLookupByLibrary.simpleMessage(
      "Запуск не завершён",
    ),
    "launchInterruptedTip": MessageLookupByLibrary.simpleMessage(
      "В прошлый раз приложение неожиданно завершилось во время запуска. Автоматическая настройка для этого запуска пропущена; вы можете запустить её вручную.",
    ),
    "layout": MessageLookupByLibrary.simpleMessage("Макет"),
    "level": MessageLookupByLibrary.simpleMessage("Уровень"),
    "light": MessageLookupByLibrary.simpleMessage("Светлая"),
    "lineHeight": MessageLookupByLibrary.simpleMessage("Интервал"),
    "lineIssueTip": m43,
    "lineWrap": MessageLookupByLibrary.simpleMessage("Перенос строк"),
    "link": MessageLookupByLibrary.simpleMessage("Ссылка"),
    "linkDesc": MessageLookupByLibrary.simpleMessage(
      "Получить профиль по ссылке на подписку или на прокси",
    ),
    "liquidGlass": MessageLookupByLibrary.simpleMessage("Жидкое стекло"),
    "list": MessageLookupByLibrary.simpleMessage("Список"),
    "listen": MessageLookupByLibrary.simpleMessage("Прослушивание"),
    "listenRoutingMark": MessageLookupByLibrary.simpleMessage(
      "Метка маршрутизации",
    ),
    "listenRoutingMarkDesc": MessageLookupByLibrary.simpleMessage(
      "Метка маршрутизации действует только в Linux.",
    ),
    "listeningPort": MessageLookupByLibrary.simpleMessage("Порт прослушивания"),
    "liveConnections": MessageLookupByLibrary.simpleMessage(
      "Активные соединения",
    ),
    "loading": MessageLookupByLibrary.simpleMessage("Загрузка…"),
    "local": MessageLookupByLibrary.simpleMessage("Локально"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Резервное копирование данных локально",
    ),
    "localImage": MessageLookupByLibrary.simpleMessage("Локальное изображение"),
    "localNetworkDeniedTip": MessageLookupByLibrary.simpleMessage(
      "Доступ к локальной сети запрещён: используется стек gvisor, локальная сеть недоступна.",
    ),
    "localProxies": MessageLookupByLibrary.simpleMessage("Локальные прокси"),
    "locationPermission": MessageLookupByLibrary.simpleMessage(
      "Разрешение на геолокацию",
    ),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "Разрешение на геолокацию отклонено, поэтому невозможно получить имя текущей сети Wi-Fi. Включите разрешение на геолокацию вручную в системных настройках.",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "По требованию системы для получения имени сети Wi-Fi необходимо разрешение на геолокацию. На Android выберите «Разрешить всегда», иначе имя сети Wi-Fi нельзя получить, пока приложение в фоне.",
    ),
    "locationPermissionGuide": m44,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Требуется разрешение на геолокацию",
    ),
    "log": MessageLookupByLibrary.simpleMessage("Лог"),
    "logLevel": MessageLookupByLibrary.simpleMessage("Уровень логов"),
    "logcat": MessageLookupByLibrary.simpleMessage("Захват логов"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "При отключении захвата логов раздел логов скрывается.",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("Логи"),
    "logsAndDiagnostics": MessageLookupByLibrary.simpleMessage(
      "Логи и диагностика",
    ),
    "logsDesc": MessageLookupByLibrary.simpleMessage(
      "Записи захваченных логов",
    ),
    "logsTest": MessageLookupByLibrary.simpleMessage("Тест логов"),
    "loopback": MessageLookupByLibrary.simpleMessage(
      "Снятие ограничения loopback для UWP",
    ),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage(
      "Для снятия ограничения loopback у UWP-приложений",
    ),
    "loose": MessageLookupByLibrary.simpleMessage("Свободный"),
    "manual": MessageLookupByLibrary.simpleMessage("Вручную"),
    "matchCase": MessageLookupByLibrary.simpleMessage("Учитывать регистр"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage(
      "Сопоставлять IP источника",
    ),
    "matchTarget": MessageLookupByLibrary.simpleMessage("MATCH-TARGET"),
    "matchTargetDesc": MessageLookupByLibrary.simpleMessage(
      "Куда направляются правила с целью MATCH-TARGET. По умолчанию — цель последнего правила MATCH этого профиля.",
    ),
    "matchTargetTitle": MessageLookupByLibrary.simpleMessage("Цель MATCH"),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage(
      "Макс. число неудач",
    ),
    "maxLengthTip": m45,
    "maximize": MessageLookupByLibrary.simpleMessage("Развернуть"),
    "memoryApp": MessageLookupByLibrary.simpleMessage("Память приложения"),
    "memoryAppResident": MessageLookupByLibrary.simpleMessage(
      "Резидентная память",
    ),
    "memoryAppShared": MessageLookupByLibrary.simpleMessage(
      "Приложение и общая",
    ),
    "memoryCleanup": MessageLookupByLibrary.simpleMessage("Очистить"),
    "memoryCoreHeapIdle": MessageLookupByLibrary.simpleMessage(
      "Свободная куча",
    ),
    "memoryCoreHeapInuse": MessageLookupByLibrary.simpleMessage(
      "Используемая куча",
    ),
    "memoryCoreNotRunning": MessageLookupByLibrary.simpleMessage(
      "Ядро не запущено",
    ),
    "memoryCoreRuntime": MessageLookupByLibrary.simpleMessage(
      "Накладные расходы среды",
    ),
    "memoryCoreStack": MessageLookupByLibrary.simpleMessage("Стеки горутин"),
    "memoryEstimateDesc": MessageLookupByLibrary.simpleMessage(
      "Оценка по резидентной памяти процессов; может отличаться от данных системы.",
    ),
    "memoryEstimateSharedDesc": MessageLookupByLibrary.simpleMessage(
      "Ядро работает в процессе приложения. Его доля оценивается по статистике среды выполнения, остальное относится к приложению и общей памяти.",
    ),
    "memoryFootprint": MessageLookupByLibrary.simpleMessage(
      "Объём занимаемой памяти",
    ),
    "memoryGC": MessageLookupByLibrary.simpleMessage("Метаданные GC"),
    "memoryHeapIdle": MessageLookupByLibrary.simpleMessage(
      "Удерживаемая свободная куча",
    ),
    "memoryHeapObjects": MessageLookupByLibrary.simpleMessage("Объекты в куче"),
    "memoryHeapReleased": MessageLookupByLibrary.simpleMessage("Возвращено ОС"),
    "memoryHeapUnused": MessageLookupByLibrary.simpleMessage(
      "Свободное место в блоках кучи",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("Память"),
    "memoryInfoDesc": MessageLookupByLibrary.simpleMessage(
      "Память приложения и ядра",
    ),
    "memoryMetadata": MessageLookupByLibrary.simpleMessage(
      "Метаданные среды выполнения",
    ),
    "memoryOther": MessageLookupByLibrary.simpleMessage(
      "Прочая память среды выполнения",
    ),
    "memoryReadFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось прочитать данные памяти. Повторная попытка…",
    ),
    "memoryReleased": MessageLookupByLibrary.simpleMessage(
      "Память освобождена",
    ),
    "memoryReleasedSize": m46,
    "memoryStacks": MessageLookupByLibrary.simpleMessage("Стеки"),
    "memoryTotal": MessageLookupByLibrary.simpleMessage(
      "Использование памяти Go",
    ),
    "messageTest": MessageLookupByLibrary.simpleMessage("Тест сообщения"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage("Это сообщение."),
    "minimize": MessageLookupByLibrary.simpleMessage("Свернуть"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage(
      "Сворачивать при выходе",
    ),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "Изменяет стандартное поведение при выходе",
    ),
    "minutes": MessageLookupByLibrary.simpleMessage("минут"),
    "minutesAgo": m47,
    "minutesAgoShort": m48,
    "mixedPort": MessageLookupByLibrary.simpleMessage("Смешанный порт"),
    "mode": MessageLookupByLibrary.simpleMessage("Режим"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("Монохром"),
    "monochromeTrayIcon": MessageLookupByLibrary.simpleMessage(
      "Монохромный значок в трее",
    ),
    "monthsAgo": m49,
    "monthsAgoShort": m50,
    "more": MessageLookupByLibrary.simpleMessage("Ещё"),
    "mtu": MessageLookupByLibrary.simpleMessage("MTU"),
    "mtuRangeTip": MessageLookupByLibrary.simpleMessage(
      "MTU должен быть целым числом от 1 до 65535",
    ),
    "multipleValuesTip": MessageLookupByLibrary.simpleMessage(
      "Разделяйте несколько значений запятыми",
    ),
    "name": MessageLookupByLibrary.simpleMessage("Название"),
    "nameserver": MessageLookupByLibrary.simpleMessage("DNS-сервер"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Используется для разрешения доменов",
    ),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "Политика DNS-серверов",
    ),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Назначает DNS-серверы совпавшим доменам, категориям GeoSite или наборам правил",
    ),
    "navigationBarStyle": MessageLookupByLibrary.simpleMessage("Нижняя панель"),
    "needsLogin": MessageLookupByLibrary.simpleMessage("Требуется вход"),
    "network": MessageLookupByLibrary.simpleMessage("Сеть"),
    "networkAccessDeniedError": m51,
    "networkBadResponseError": m52,
    "networkCancelledError": MessageLookupByLibrary.simpleMessage(
      "Запрос отменён",
    ),
    "networkConnectionError": MessageLookupByLibrary.simpleMessage(
      "Не удалось подключиться к серверу. Проверьте подключение к сети или настройки прокси",
    ),
    "networkDesc": MessageLookupByLibrary.simpleMessage(
      "Настройки, связанные с сетью",
    ),
    "networkException": MessageLookupByLibrary.simpleMessage(
      "Ошибка сети. Проверьте подключение и повторите попытку",
    ),
    "networkExtension": MessageLookupByLibrary.simpleMessage(
      "Сетевое расширение",
    ),
    "networkHostLookupError": MessageLookupByLibrary.simpleMessage(
      "Не удалось определить адрес сервера. Проверьте правильность URL и работу DNS",
    ),
    "networkId": MessageLookupByLibrary.simpleMessage("Идентификатор сети"),
    "networkName": MessageLookupByLibrary.simpleMessage("Имя сети"),
    "networkNotFound": MessageLookupByLibrary.simpleMessage("Сеть не найдена"),
    "networkNotFoundError": m53,
    "networkRateLimitedError": MessageLookupByLibrary.simpleMessage(
      "Слишком много запросов (HTTP 429). Подождите немного и повторите попытку",
    ),
    "networkRequestFailed": m54,
    "networkSecret": MessageLookupByLibrary.simpleMessage("Секрет сети"),
    "networkServerError": m55,
    "networkSpeed": MessageLookupByLibrary.simpleMessage("Скорость сети"),
    "networkSpeedNotification": MessageLookupByLibrary.simpleMessage(
      "Показывать скорость сети в реальном времени",
    ),
    "networkSpeedNotificationDesc": MessageLookupByLibrary.simpleMessage(
      "Показывать скорость сети в реальном времени в области состояния системы; энергопотребление может немного увеличиться",
    ),
    "networkTakeover": MessageLookupByLibrary.simpleMessage("Перехват трафика"),
    "networkTimeoutError": MessageLookupByLibrary.simpleMessage(
      "Время ожидания запроса истекло. Проверьте сеть или прокси и повторите попытку",
    ),
    "networkTlsError": MessageLookupByLibrary.simpleMessage(
      "Не удалось установить защищённое соединение. Сертификат сервера может быть недействителен, или соединение перехватывается",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("Тип сети"),
    "networking": MessageLookupByLibrary.simpleMessage("Оверлейные сети"),
    "networkingDesc": MessageLookupByLibrary.simpleMessage(
      "Просмотр состояния P2P-сетей",
    ),
    "networkingError": MessageLookupByLibrary.simpleMessage("Ошибка"),
    "networkingNoOutbounds": MessageLookupByLibrary.simpleMessage(
      "В текущей конфигурации нет исходящих P2P-подключений",
    ),
    "newProfile": MessageLookupByLibrary.simpleMessage("Новый"),
    "newProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Создать профиль вручную",
    ),
    "nextMatch": MessageLookupByLibrary.simpleMessage("Следующее совпадение"),
    "no": MessageLookupByLibrary.simpleMessage("Нет"),
    "noData": MessageLookupByLibrary.simpleMessage("Нет данных"),
    "noDirectories": MessageLookupByLibrary.simpleMessage("Нет подкаталогов"),
    "noFilterCondition": MessageLookupByLibrary.simpleMessage(
      "Нет условий фильтрации",
    ),
    "noHotKey": MessageLookupByLibrary.simpleMessage("Горячих клавиш пока нет"),
    "noInfo": MessageLookupByLibrary.simpleMessage("Нет информации"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage(
      "Больше не напоминать",
    ),
    "noNetwork": MessageLookupByLibrary.simpleMessage("Нет сети"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("Приложения без сети"),
    "noRemoteBackups": MessageLookupByLibrary.simpleMessage(
      "Удалённые резервные копии не найдены",
    ),
    "noResolve": MessageLookupByLibrary.simpleMessage("Не разрешать IP"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage(
      "Не разрешать имя хоста",
    ),
    "noSearchResults": MessageLookupByLibrary.simpleMessage(
      "Ничего не найдено",
    ),
    "nodeTrafficReadFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось получить трафик. Повторная попытка…",
    ),
    "nodeTrafficUsage": MessageLookupByLibrary.simpleMessage("Трафик узлов"),
    "nodes": MessageLookupByLibrary.simpleMessage("Узлы"),
    "nonTextProviderFile": MessageLookupByLibrary.simpleMessage(
      "Этот внешний ресурс не является текстовым файлом",
    ),
    "none": MessageLookupByLibrary.simpleMessage("Нет"),
    "notRunning": MessageLookupByLibrary.simpleMessage("Не запущено"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "Текущую группу прокси нельзя выбрать",
    ),
    "ntpDesc": MessageLookupByLibrary.simpleMessage(
      "Настройки, связанные с NTP",
    ),
    "ntpInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал синхронизации (минуты)",
    ),
    "ntpStatusDesc": MessageLookupByLibrary.simpleMessage(
      "NTP берёт время с NTP-сервера, а не из системных часов.",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Добавьте профиль, чтобы начать",
    ),
    "nullTip": m56,
    "numberRangeTip": m57,
    "numberTip": m58,
    "obfs": MessageLookupByLibrary.simpleMessage("Обфускация"),
    "obfsHost": MessageLookupByLibrary.simpleMessage("Хост обфускации"),
    "obfsMode": MessageLookupByLibrary.simpleMessage("Режим обфускации"),
    "obfsParam": MessageLookupByLibrary.simpleMessage("Параметр обфускации"),
    "obfsPassword": MessageLookupByLibrary.simpleMessage("Пароль обфускации"),
    "offline": MessageLookupByLibrary.simpleMessage("Не в сети"),
    "onDemand": MessageLookupByLibrary.simpleMessage("По условию"),
    "onDemandDesc": MessageLookupByLibrary.simpleMessage(
      "«По условию» приостанавливает прокси в исключённых сетях Wi-Fi.",
    ),
    "online": MessageLookupByLibrary.simpleMessage("В сети"),
    "onlyConfig": MessageLookupByLibrary.simpleMessage("Только конфигурация"),
    "onlyEmoji": MessageLookupByLibrary.simpleMessage("Только Emoji"),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("Только значок"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "Учитывать только трафик прокси",
    ),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "При включении учитывается только трафик через прокси",
    ),
    "openInGitHub": MessageLookupByLibrary.simpleMessage("Открыть в GitHub"),
    "optional": MessageLookupByLibrary.simpleMessage("Необязательно"),
    "options": MessageLookupByLibrary.simpleMessage("Опции"),
    "other": MessageLookupByLibrary.simpleMessage("Другое"),
    "otherContributors": MessageLookupByLibrary.simpleMessage(
      "Другие участники",
    ),
    "outbound": MessageLookupByLibrary.simpleMessage("Исходящие"),
    "outboundExit": MessageLookupByLibrary.simpleMessage("Выход"),
    "outboundIp": MessageLookupByLibrary.simpleMessage("Исходящий IP"),
    "outboundMode": MessageLookupByLibrary.simpleMessage(
      "Режим исходящего трафика",
    ),
    "override": MessageLookupByLibrary.simpleMessage("Переопределение"),
    "overrideDestination": MessageLookupByLibrary.simpleMessage(
      "Подменять адрес назначения",
    ),
    "overrideDestinationDesc": MessageLookupByLibrary.simpleMessage(
      "«Подменять адрес назначения» подключается к обнаруженному домену вместо исходного адреса.",
    ),
    "overrideDns": MessageLookupByLibrary.simpleMessage("Переопределить DNS"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "При включении настройки DNS профиля переопределяются",
    ),
    "overrideEntries": MessageLookupByLibrary.simpleMessage(
      "Переопределяемые параметры",
    ),
    "overrideMode": MessageLookupByLibrary.simpleMessage(
      "Режим переопределения",
    ),
    "overrideNtp": MessageLookupByLibrary.simpleMessage("Переопределить NTP"),
    "overrideNtpDesc": MessageLookupByLibrary.simpleMessage(
      "При включении настройки NTP профиля переопределяются",
    ),
    "overrideScript": MessageLookupByLibrary.simpleMessage(
      "Скрипт переопределения",
    ),
    "overwriteTypeCustom": MessageLookupByLibrary.simpleMessage(
      "Пользовательский",
    ),
    "overwriteTypeCustomDesc": MessageLookupByLibrary.simpleMessage(
      "Пользовательский режим: полная настройка групп прокси и правил",
    ),
    "parentDirectory": MessageLookupByLibrary.simpleMessage(
      "Родительский каталог",
    ),
    "parsePureIp": MessageLookupByLibrary.simpleMessage("Разбирать чистые IP"),
    "parsePureIpDesc": MessageLookupByLibrary.simpleMessage(
      "«Разбирать чистые IP» анализирует соединения, у которых есть только IP-адрес.",
    ),
    "password": MessageLookupByLibrary.simpleMessage("Пароль"),
    "paste": MessageLookupByLibrary.simpleMessage("Вставить"),
    "peers": MessageLookupByLibrary.simpleMessage("Пиры"),
    "pickFromAlbum": MessageLookupByLibrary.simpleMessage("Выбрать из галереи"),
    "pinWindow": MessageLookupByLibrary.simpleMessage(
      "Закрепить поверх всех окон",
    ),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "Привяжите WebDAV",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "Введите название скрипта",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "Загрузите корректный QR-код",
    ),
    "plugin": MessageLookupByLibrary.simpleMessage("Плагин"),
    "pluginHost": MessageLookupByLibrary.simpleMessage("Хост плагина"),
    "pluginMode": MessageLookupByLibrary.simpleMessage("Режим плагина"),
    "port": MessageLookupByLibrary.simpleMessage("Порт"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "Введите другой порт",
    ),
    "portHopping": MessageLookupByLibrary.simpleMessage("Перескок портов"),
    "portTip": m59,
    "portValue": m60,
    "ports": MessageLookupByLibrary.simpleMessage("Порты"),
    "positiveIntegerTip": MessageLookupByLibrary.simpleMessage(
      "Введите целое число больше 0",
    ),
    "preSharedKey": MessageLookupByLibrary.simpleMessage("Общий ключ"),
    "predictiveBack": MessageLookupByLibrary.simpleMessage(
      "Предиктивный возврат",
    ),
    "preferH3": MessageLookupByLibrary.simpleMessage("Предпочитать HTTP/3"),
    "preferH3Desc": MessageLookupByLibrary.simpleMessage(
      "Предпочитать HTTP/3 для DoH",
    ),
    "prerequisites": MessageLookupByLibrary.simpleMessage(
      "Предварительные условия",
    ),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage(
      "Нажмите сочетание клавиш",
    ),
    "preview": MessageLookupByLibrary.simpleMessage("Предпросмотр"),
    "previousMatch": MessageLookupByLibrary.simpleMessage(
      "Предыдущее совпадение",
    ),
    "privateKey": MessageLookupByLibrary.simpleMessage("Закрытый ключ"),
    "privateKeyPassphrase": MessageLookupByLibrary.simpleMessage(
      "Пароль закрытого ключа",
    ),
    "process": MessageLookupByLibrary.simpleMessage("Процесс"),
    "profile": MessageLookupByLibrary.simpleMessage("Профиль"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("Введите корректный интервал"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("Введите интервал автообновления"),
    "profileDaysLeft": m61,
    "profileExpiresIn": m62,
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "Профиль изменён. Отключить автообновление?",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Введите название профиля",
    ),
    "profileSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Действует только для этого профиля; не добавленные параметры используют значения по умолчанию.",
    ),
    "profileTunSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Действует только для этого профиля и имеет приоритет над переопределяемыми параметрами TUN в настройках сети.",
    ),
    "profileUpdatedAt": m63,
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Введите корректный URL профиля",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Введите URL профиля",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("Профили"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("Сортировка профилей"),
    "project": MessageLookupByLibrary.simpleMessage("Проект"),
    "promptCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Запрос на закрытие соединений",
    ),
    "promptCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Спрашивать о закрытии соединений после смены узла",
    ),
    "protocol": MessageLookupByLibrary.simpleMessage("Протокол"),
    "protocolParam": MessageLookupByLibrary.simpleMessage("Параметр протокола"),
    "protocolVersion": MessageLookupByLibrary.simpleMessage("Версия протокола"),
    "providerInUse": m64,
    "providerUrlTip": MessageLookupByLibrary.simpleMessage(
      "Поддерживаются только удалённые ресурсы",
    ),
    "providers": MessageLookupByLibrary.simpleMessage("Внешние ресурсы"),
    "proxies": MessageLookupByLibrary.simpleMessage("Прокси"),
    "proxiesCount": m65,
    "proxiesProfileLabel": m66,
    "proxiesRemovedTip": m67,
    "proxiesReplacedTip": m68,
    "proxy": MessageLookupByLibrary.simpleMessage("Прокси"),
    "proxyChains": MessageLookupByLibrary.simpleMessage("Цепочка прокси"),
    "proxyDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Обнаружены отклонения в выбранных прокси",
    ),
    "proxyFilter": MessageLookupByLibrary.simpleMessage("Фильтр узлов"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("Группа прокси"),
    "proxyGroupDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Обнаружены отклонения в текущей группе прокси",
    ),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage(
      "Группа прокси пуста",
    ),
    "proxyGroupInUse": m69,
    "proxyGroupNameEmpty": MessageLookupByLibrary.simpleMessage(
      "Название группы прокси не может быть пустым",
    ),
    "proxyGroupsAfterStart": MessageLookupByLibrary.simpleMessage(
      "Группы появятся здесь после запуска ядра",
    ),
    "proxyGroupsCount": m70,
    "proxyNameserver": MessageLookupByLibrary.simpleMessage(
      "DNS-сервер для прокси",
    ),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Используется для разрешения доменов прокси-узлов",
    ),
    "proxyNameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "Политика прокси-сервера имен",
    ),
    "proxyNameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Указать политику сервера имен для прокси-узлов",
    ),
    "proxyProvider": MessageLookupByLibrary.simpleMessage("Провайдер прокси"),
    "proxyProviderDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Обнаружены отклонения в выбранных провайдерах прокси",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("Провайдеры прокси"),
    "proxyType": MessageLookupByLibrary.simpleMessage("Тип прокси"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("Очистить кэш"),
    "publicKey": MessageLookupByLibrary.simpleMessage("Открытый ключ"),
    "pureBlack": MessageLookupByLibrary.simpleMessage("Чисто чёрный"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("Чисто чёрный режим"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QR-код"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "Сканируйте QR-код, чтобы получить профиль",
    ),
    "query": MessageLookupByLibrary.simpleMessage("Запросить"),
    "queryDns": MessageLookupByLibrary.simpleMessage("DNS-запрос"),
    "queryRule": MessageLookupByLibrary.simpleMessage("Проверить правила"),
    "quickActions": MessageLookupByLibrary.simpleMessage("Быстрые действия"),
    "quickEdit": MessageLookupByLibrary.simpleMessage("Быстрое редактирование"),
    "quickFill": MessageLookupByLibrary.simpleMessage("Быстрое заполнение"),
    "random": MessageLookupByLibrary.simpleMessage("Случайный"),
    "recentRequests": MessageLookupByLibrary.simpleMessage("Последние запросы"),
    "recommendedIcons": MessageLookupByLibrary.simpleMessage("Рекомендуемые"),
    "recordType": MessageLookupByLibrary.simpleMessage("Тип записи"),
    "recvMsgX": MessageLookupByLibrary.simpleMessage("Включить RecvMsgX"),
    "recvMsgXDesc": MessageLookupByLibrary.simpleMessage(
      "Пакетный приём пакетов в Darwin",
    ),
    "redirPort": MessageLookupByLibrary.simpleMessage("Порт Redir"),
    "redo": MessageLookupByLibrary.simpleMessage("Повторить"),
    "regex": MessageLookupByLibrary.simpleMessage("Регулярное выражение"),
    "regexSearch": MessageLookupByLibrary.simpleMessage("Поиск по regex"),
    "relayed": MessageLookupByLibrary.simpleMessage("Через ретранслятор"),
    "releaseMemory": MessageLookupByLibrary.simpleMessage("Освободить память"),
    "releaseMemoryFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось освободить память",
    ),
    "remote": MessageLookupByLibrary.simpleMessage("Удалённо"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Резервное копирование данных в WebDAV",
    ),
    "remoteDestination": MessageLookupByLibrary.simpleMessage(
      "Удалённое назначение",
    ),
    "remoteDnsResolve": MessageLookupByLibrary.simpleMessage(
      "Удалённое разрешение DNS",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("Убрать"),
    "rename": MessageLookupByLibrary.simpleMessage("Переименовать"),
    "replace": MessageLookupByLibrary.simpleMessage("Заменить"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("Заменить все"),
    "request": MessageLookupByLibrary.simpleMessage("Запрос"),
    "requests": MessageLookupByLibrary.simpleMessage("Запросы"),
    "requestsAndUpdates": MessageLookupByLibrary.simpleMessage(
      "Запросы и обновления",
    ),
    "requestsDesc": MessageLookupByLibrary.simpleMessage(
      "Просмотр последних запросов",
    ),
    "required": MessageLookupByLibrary.simpleMessage("Обязательно"),
    "reset": MessageLookupByLibrary.simpleMessage("Сброс"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "На этой странице есть изменения. Вы уверены, что хотите выполнить сброс?",
    ),
    "resetProfilesAndScripts": MessageLookupByLibrary.simpleMessage(
      "Профили и скрипты",
    ),
    "resetSettingsData": MessageLookupByLibrary.simpleMessage(
      "Настройки приложения",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите выполнить сброс?",
    ),
    "resourceUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал автообновления",
    ),
    "resourceUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "Интервал автообновления должен быть больше 0",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("Ресурсы"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage(
      "Сведения о внешних ресурсах",
    ),
    "respectRules": MessageLookupByLibrary.simpleMessage("Соблюдать правила"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "«Соблюдать правила» направляет DNS-соединения по правилам; нужен Proxy Server Nameserver.",
    ),
    "responseCode": MessageLookupByLibrary.simpleMessage("Код ответа"),
    "restart": MessageLookupByLibrary.simpleMessage("Перезапустить"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите перезапустить ядро?",
    ),
    "restore": MessageLookupByLibrary.simpleMessage("Восстановить"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage(
      "Восстановить все данные",
    ),
    "restoreException": MessageLookupByLibrary.simpleMessage(
      "Ошибка восстановления",
    ),
    "restoreFromFileDesc": MessageLookupByLibrary.simpleMessage(
      "Восстановить данные из файла",
    ),
    "restoreFromWebDAVDesc": MessageLookupByLibrary.simpleMessage(
      "Восстановить данные из WebDAV",
    ),
    "restoreHiddenGroups": MessageLookupByLibrary.simpleMessage(
      "Снова скрывать группы",
    ),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage(
      "Восстановить только профили",
    ),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage(
      "Стратегия восстановления",
    ),
    "restoreStrategyCompatible": MessageLookupByLibrary.simpleMessage(
      "Совместимость",
    ),
    "restoreStrategyOverride": MessageLookupByLibrary.simpleMessage(
      "Перезапись",
    ),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage(
      "Восстановление выполнено",
    ),
    "result": MessageLookupByLibrary.simpleMessage("Результат"),
    "retry": MessageLookupByLibrary.simpleMessage("Повторить"),
    "role": MessageLookupByLibrary.simpleMessage("Роль"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("Адреса маршрутов"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage(
      "Настроить прослушиваемые адреса маршрутов",
    ),
    "routeExcludeAddress": MessageLookupByLibrary.simpleMessage(
      "Исключённые адреса маршрутов",
    ),
    "routeMode": MessageLookupByLibrary.simpleMessage("Режим маршрутизации"),
    "routeModeBypassPrivate": MessageLookupByLibrary.simpleMessage(
      "Обходить частные адреса",
    ),
    "routeModeConfig": MessageLookupByLibrary.simpleMessage(
      "Использовать конфигурацию",
    ),
    "routes": MessageLookupByLibrary.simpleMessage("Маршруты"),
    "routingMark": MessageLookupByLibrary.simpleMessage("Метка маршрутизации"),
    "ru": MessageLookupByLibrary.simpleMessage("Русский"),
    "rule": MessageLookupByLibrary.simpleMessage("Правило"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage(
      "Логическое правило AND",
    ),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить полный домен",
    ),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить ключевое слово в домене",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по регулярному выражению домена",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить суффикс домена",
    ),
    "ruleActionDomainWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставление по маске; поддерживаются только * и ?",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить метку DSCP (только для входящих tproxy UDP)",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон портов назначения",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить код страны IP-адреса",
    ),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить домены из Geosite",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить имя входящего подключения",
    ),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить входящий порт",
    ),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить тип входящего подключения",
    ),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить имя пользователя входящего подключения; несколько имён разделяются /",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить ASN, которой принадлежит IP",
    ),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон IP-адресов; IP-CIDR6 — просто псевдоним",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон IP-адресов",
    ),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон суффиксов IP",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставляет все запросы, условия не нужны",
    ),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить TCP или UDP",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage(
      "Логическое правило NOT",
    ),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage(
      "Логическое правило OR",
    ),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по имени процесса; на Android соответствует имени пакета",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по регулярному выражению имени процесса; на Android соответствует имени пакета",
    ),
    "ruleActionProcessNameWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по маске имени процесса; поддерживаются только * и ?",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по полному пути процесса",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по регулярному выражению пути процесса",
    ),
    "ruleActionProcessPathWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по маске пути процесса; поддерживаются только * и ?",
    ),
    "ruleActionRematchNameDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить имя повторного сопоставления; несколько имён разделяются /",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "Ссылка на набор правил; требуется настроить rule-providers",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить код страны IP источника",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить ASN IP источника",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон IP-адресов источника",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон суффиксов IP источника",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон портов источника",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "Переход к подправилу; обратите внимание на скобки",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить Linux USER ID",
    ),
    "ruleDisabled": MessageLookupByLibrary.simpleMessage("Отключено"),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("Правило пусто"),
    "ruleEnabled": MessageLookupByLibrary.simpleMessage("Включено"),
    "ruleHits": MessageLookupByLibrary.simpleMessage("Совпадения"),
    "ruleLastHit": MessageLookupByLibrary.simpleMessage("Последнее совпадение"),
    "ruleLastMiss": MessageLookupByLibrary.simpleMessage(
      "Последнее несовпадение",
    ),
    "ruleListInvalid": MessageLookupByLibrary.simpleMessage(
      "Правила должны быть YAML-списком, по одному правилу в элементе, например - DOMAIN,example.com,DIRECT",
    ),
    "ruleMisses": MessageLookupByLibrary.simpleMessage("Несовпадения"),
    "rulePresetBittorrentDirect": MessageLookupByLibrary.simpleMessage(
      "BitTorrent напрямую",
    ),
    "rulePresetBlockDot": MessageLookupByLibrary.simpleMessage(
      "Блокировать DNS over TLS",
    ),
    "rulePresetBlockLoopback": MessageLookupByLibrary.simpleMessage(
      "Защита от петли прокси",
    ),
    "rulePresetBlockQuic": MessageLookupByLibrary.simpleMessage(
      "Блокировать QUIC",
    ),
    "rulePresetBlockStun": MessageLookupByLibrary.simpleMessage(
      "Блокировать STUN",
    ),
    "rulePresetLanDirect": MessageLookupByLibrary.simpleMessage(
      "Локальная сеть напрямую",
    ),
    "rulePresetSystemServicesDirect": MessageLookupByLibrary.simpleMessage(
      "Apple и Microsoft напрямую",
    ),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("Провайдеры правил"),
    "ruleQueryDestinationIP": MessageLookupByLibrary.simpleMessage(
      "IP назначения",
    ),
    "ruleQueryInboundName": MessageLookupByLibrary.simpleMessage(
      "Имя входящего подключения",
    ),
    "ruleQueryInboundUser": MessageLookupByLibrary.simpleMessage(
      "Пользователь входящего подключения",
    ),
    "ruleQueryInvalidIP": MessageLookupByLibrary.simpleMessage(
      "Введите корректный IP-адрес.",
    ),
    "ruleQueryNoMatch": MessageLookupByLibrary.simpleMessage(
      "Нет совпадений (политика режима или DIRECT)",
    ),
    "ruleQueryNumberRange": m71,
    "ruleQueryPortInvalid": MessageLookupByLibrary.simpleMessage(
      "Введите порт от 1 до 65535.",
    ),
    "ruleQueryProcessPath": MessageLookupByLibrary.simpleMessage(
      "Путь процесса",
    ),
    "ruleQuerySniffHost": MessageLookupByLibrary.simpleMessage(
      "Обнаруженный домен",
    ),
    "ruleQuerySourcePort": MessageLookupByLibrary.simpleMessage(
      "Порт источника",
    ),
    "ruleQueryTarget": MessageLookupByLibrary.simpleMessage(
      "Домен или IP-адрес",
    ),
    "ruleSet": MessageLookupByLibrary.simpleMessage("Набор правил"),
    "ruleSetEmptyTip": MessageLookupByLibrary.simpleMessage(
      "В наборе правил нет пригодных записей",
    ),
    "ruleSetInvalidTip": MessageLookupByLibrary.simpleMessage(
      "Не удаётся прочитать этот файл mrs",
    ),
    "ruleSetMixedTip": MessageLookupByLibrary.simpleMessage(
      "Набор правил смешивает домены и диапазоны IP, поэтому его тип не определить",
    ),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("Цель правила"),
    "ruleTextInvalid": MessageLookupByLibrary.simpleMessage(
      "Правило должно начинаться с поддерживаемого типа, например DOMAIN,example.com,DIRECT",
    ),
    "ruleType": MessageLookupByLibrary.simpleMessage("Тип правила"),
    "ruleUpdateFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось изменить правило. Возможно, конфигурация изменилась. Обновите список и повторите попытку.",
    ),
    "rules": MessageLookupByLibrary.simpleMessage("Правила"),
    "rulesCount": m72,
    "rulesDesc": MessageLookupByLibrary.simpleMessage(
      "Просмотр правил и статистики совпадений",
    ),
    "runTime": MessageLookupByLibrary.simpleMessage("Время работы"),
    "running": MessageLookupByLibrary.simpleMessage("Работает"),
    "runtimeConfig": MessageLookupByLibrary.simpleMessage(
      "Конфигурация выполнения",
    ),
    "safeMode": MessageLookupByLibrary.simpleMessage("Безопасный режим"),
    "safeModeAppTitle": m73,
    "saturation": MessageLookupByLibrary.simpleMessage("Насыщенность"),
    "save": MessageLookupByLibrary.simpleMessage("Сохранить"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("Сохранить изменения?"),
    "script": MessageLookupByLibrary.simpleMessage("Скрипт"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "Режим скрипта: переписывает весь профиль скриптом расширения",
    ),
    "scrollToSelected": MessageLookupByLibrary.simpleMessage(
      "Прокрутить к выбранному",
    ),
    "search": MessageLookupByLibrary.simpleMessage("Поиск"),
    "seconds": MessageLookupByLibrary.simpleMessage("секунд"),
    "secondsCount": m74,
    "secretKey": MessageLookupByLibrary.simpleMessage("Ключ"),
    "sectionsInEffect": m75,
    "selectAll": MessageLookupByLibrary.simpleMessage("Выбрать всё"),
    "selectMatchTarget": MessageLookupByLibrary.simpleMessage(
      "Выбрать MATCH-TARGET",
    ),
    "selectRemoteBackup": MessageLookupByLibrary.simpleMessage(
      "Выберите резервную копию",
    ),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage(
      "Выберите набор правил",
    ),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage(
      "Выберите стратегию распределения",
    ),
    "selected": MessageLookupByLibrary.simpleMessage("Выбрано"),
    "sendMsgX": MessageLookupByLibrary.simpleMessage("Включить SendMsgX"),
    "sendMsgXDesc": MessageLookupByLibrary.simpleMessage(
      "Пакетная отправка пакетов в Darwin",
    ),
    "server": MessageLookupByLibrary.simpleMessage("Сервер"),
    "serviceAbnormalCount": m76,
    "serviceAllAvailable": MessageLookupByLibrary.simpleMessage("Все доступны"),
    "serviceAvailable": MessageLookupByLibrary.simpleMessage("Доступен"),
    "serviceBlocked": MessageLookupByLibrary.simpleMessage("Заблокировано"),
    "serviceCheck": MessageLookupByLibrary.simpleMessage("Проверить"),
    "serviceCheckAll": MessageLookupByLibrary.simpleMessage("Проверить все"),
    "serviceCheckedAt": m77,
    "serviceComingSoon": MessageLookupByLibrary.simpleMessage("Скоро появится"),
    "serviceDisallowedIsp": MessageLookupByLibrary.simpleMessage(
      "Недопустимый провайдер",
    ),
    "serviceFailed": MessageLookupByLibrary.simpleMessage("Ошибка проверки"),
    "serviceManage": MessageLookupByLibrary.simpleMessage(
      "Управление сервисами",
    ),
    "serviceOriginalsOnly": MessageLookupByLibrary.simpleMessage(
      "Только оригиналы",
    ),
    "servicePending": MessageLookupByLibrary.simpleMessage("Не проверено"),
    "serviceRestricted": MessageLookupByLibrary.simpleMessage(
      "Доступ ограничен",
    ),
    "serviceShownOnDashboard": MessageLookupByLibrary.simpleMessage(
      "Показан на панели",
    ),
    "serviceStatus": MessageLookupByLibrary.simpleMessage("Состояние сервисов"),
    "serviceUnavailable": MessageLookupByLibrary.simpleMessage("Недоступен"),
    "serviceUnsupportedRegion": MessageLookupByLibrary.simpleMessage(
      "Регион не поддерживается",
    ),
    "settingEntries": MessageLookupByLibrary.simpleMessage("параметры"),
    "settings": MessageLookupByLibrary.simpleMessage("Настройки"),
    "settingsCount": m78,
    "shareLinkUnreadable": m79,
    "shareLinksInvalid": MessageLookupByLibrary.simpleMessage(
      "Не удалось прочитать прокси из ссылок",
    ),
    "show": MessageLookupByLibrary.simpleMessage("Показать"),
    "showHiddenGroups": MessageLookupByLibrary.simpleMessage(
      "Показать скрытые группы",
    ),
    "showLess": MessageLookupByLibrary.simpleMessage("Свернуть"),
    "showMore": MessageLookupByLibrary.simpleMessage("Развернуть"),
    "showNotificationStopAction": MessageLookupByLibrary.simpleMessage(
      "Кнопка остановки в уведомлении",
    ),
    "showNotificationStopActionDesc": MessageLookupByLibrary.simpleMessage(
      "Показывать кнопку остановки в постоянном уведомлении. Отключите, если из-за неё система всегда разворачивает уведомление",
    ),
    "showPassword": MessageLookupByLibrary.simpleMessage("Показать пароль"),
    "showQuickSettingsProfileName": MessageLookupByLibrary.simpleMessage(
      "Показывать имя текущего профиля",
    ),
    "showQuickSettingsProfileNameDesc": MessageLookupByLibrary.simpleMessage(
      "Показывать имя профиля на быстром переключателе при подключении",
    ),
    "showTrayProxySelection": MessageLookupByLibrary.simpleMessage(
      "Показывать выбор прокси в трее",
    ),
    "showTrayProxySelectionDesc": MessageLookupByLibrary.simpleMessage(
      "Показывать группы и узлы прокси в меню трея для быстрого переключения",
    ),
    "showUnavailable": MessageLookupByLibrary.simpleMessage("Показать таймаут"),
    "sidebarBlur": MessageLookupByLibrary.simpleMessage(
      "Размытие боковой панели",
    ),
    "sidebarBlurDesc": MessageLookupByLibrary.simpleMessage(
      "Показывать сквозь боковую панель размытый рабочий стол за окном",
    ),
    "signIn": MessageLookupByLibrary.simpleMessage("Войти"),
    "signOut": MessageLookupByLibrary.simpleMessage("Выйти"),
    "signedIn": MessageLookupByLibrary.simpleMessage("Вход выполнен"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("Тихий запуск"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Тихий запуск не показывает окно.",
    ),
    "singleAdd": MessageLookupByLibrary.simpleMessage("По одному"),
    "singleImport": MessageLookupByLibrary.simpleMessage("По одному"),
    "singleShareLinkOnly": MessageLookupByLibrary.simpleMessage(
      "Здесь укажите одну ссылку, несколько можно задать в быстром редактировании списка",
    ),
    "singleValueTip": m80,
    "size": MessageLookupByLibrary.simpleMessage("Размер"),
    "skipCertVerify": MessageLookupByLibrary.simpleMessage(
      "Пропускать проверку сертификата",
    ),
    "skipDomain": MessageLookupByLibrary.simpleMessage("Пропускаемые домены"),
    "skipDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Обнаруженный домен из пропускаемых доменов не используется.",
    ),
    "skipDstAddress": MessageLookupByLibrary.simpleMessage(
      "Пропускаемые адреса назначения",
    ),
    "skipSrcAddress": MessageLookupByLibrary.simpleMessage(
      "Пропускаемые адреса источника",
    ),
    "slide": MessageLookupByLibrary.simpleMessage("Сдвиг"),
    "sliders": MessageLookupByLibrary.simpleMessage("Ползунки"),
    "small": MessageLookupByLibrary.simpleMessage("Мелкий"),
    "sniffProtocols": MessageLookupByLibrary.simpleMessage("Протоколы"),
    "sniffer": MessageLookupByLibrary.simpleMessage("Сниффер"),
    "snifferStatusDesc": MessageLookupByLibrary.simpleMessage(
      "Сниффер определяет домен по трафику TLS, HTTP и QUIC, чтобы правила могли его сопоставить.",
    ),
    "socksPort": MessageLookupByLibrary.simpleMessage("Порт SOCKS"),
    "softStyle": MessageLookupByLibrary.simpleMessage("Мягкий"),
    "sort": MessageLookupByLibrary.simpleMessage("Сортировка"),
    "source": MessageLookupByLibrary.simpleMessage("Источник"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("IP источника"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("Специальный прокси"),
    "specialRules": MessageLookupByLibrary.simpleMessage("Специальные правила"),
    "spectrum": MessageLookupByLibrary.simpleMessage("Спектр"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage(
      "Статистика скорости",
    ),
    "splitStrategy": MessageLookupByLibrary.simpleMessage(
      "Стратегия распределения",
    ),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Стратегия распределения не может быть пустой",
    ),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("Список SSID пуст"),
    "stackMode": MessageLookupByLibrary.simpleMessage("Режим стека"),
    "stackTrace": MessageLookupByLibrary.simpleMessage("Трассировка стека"),
    "standard": MessageLookupByLibrary.simpleMessage("Стандартный"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "Стандартный режим: добавляет правила поверх профиля",
    ),
    "start": MessageLookupByLibrary.simpleMessage("Старт"),
    "startFromScratch": MessageLookupByLibrary.simpleMessage("С нуля"),
    "startVpn": MessageLookupByLibrary.simpleMessage("Запуск VPN…"),
    "startupAndBackground": MessageLookupByLibrary.simpleMessage(
      "Запуск и фоновая работа",
    ),
    "status": MessageLookupByLibrary.simpleMessage("Статус"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "При отключённом DNS используется системный DNS.",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("Стоп"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("Остановка VPN…"),
    "stopped": MessageLookupByLibrary.simpleMessage("Остановлено"),
    "strategy": MessageLookupByLibrary.simpleMessage("Стратегия"),
    "strictRoute": MessageLookupByLibrary.simpleMessage(
      "Строгая маршрутизация",
    ),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "Строгая маршрутизация не даёт трафику вроде DNS обходить TUN, а при выключенном IPv6 блокирует IPv6-соединения этого устройства.",
    ),
    "style": MessageLookupByLibrary.simpleMessage("Стиль"),
    "styleSettings": MessageLookupByLibrary.simpleMessage("Настройки стиля"),
    "submit": MessageLookupByLibrary.simpleMessage("Отправить"),
    "subscriptionInfo": MessageLookupByLibrary.simpleMessage(
      "Информация о подписке",
    ),
    "sudoPasswordTitle": MessageLookupByLibrary.simpleMessage(
      "Введите пароль для sudo",
    ),
    "suspendSupport": MessageLookupByLibrary.simpleMessage(
      "Поддержка приостановки",
    ),
    "suspendSupportDesc": MessageLookupByLibrary.simpleMessage(
      "Приостанавливать ядро при простое устройства, чтобы снизить расход батареи",
    ),
    "suspended": MessageLookupByLibrary.simpleMessage("Приостановлено…"),
    "swipeToSwitchPage": MessageLookupByLibrary.simpleMessage(
      "Переключение страниц свайпом",
    ),
    "switchProfile": MessageLookupByLibrary.simpleMessage("Сменить профиль"),
    "sync": MessageLookupByLibrary.simpleMessage("Синхронизация"),
    "system": MessageLookupByLibrary.simpleMessage("Система"),
    "systemApp": MessageLookupByLibrary.simpleMessage("Системные приложения"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("Системный прокси"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Настроить системный HTTP-прокси",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("Вкладки"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("Анимация вкладок"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage(
      "Действует только в мобильном виде",
    ),
    "tailscaleActive": MessageLookupByLibrary.simpleMessage("Активен"),
    "tailscaleCurrentEndpoint": MessageLookupByLibrary.simpleMessage(
      "Текущая конечная точка",
    ),
    "tailscaleDnsName": MessageLookupByLibrary.simpleMessage("DNS-имя"),
    "tailscaleEndpoints": MessageLookupByLibrary.simpleMessage(
      "Конечные точки",
    ),
    "tailscaleExitNode": MessageLookupByLibrary.simpleMessage("Выходной узел"),
    "tailscaleExitNodeAvailable": MessageLookupByLibrary.simpleMessage(
      "Доступен как выходной узел",
    ),
    "tailscaleHealth": MessageLookupByLibrary.simpleMessage("Состояние"),
    "tailscaleHealthWarnings": MessageLookupByLibrary.simpleMessage(
      "Предупреждения о состоянии",
    ),
    "tailscaleKeyExpired": MessageLookupByLibrary.simpleMessage(
      "Срок действия ключа истёк",
    ),
    "tailscaleKeyExpiry": MessageLookupByLibrary.simpleMessage(
      "Срок действия ключа",
    ),
    "tailscaleLastHandshake": MessageLookupByLibrary.simpleMessage(
      "Последнее рукопожатие",
    ),
    "tailscaleLastSeen": MessageLookupByLibrary.simpleMessage(
      "Последняя активность",
    ),
    "tailscaleNeedsMachineAuth": MessageLookupByLibrary.simpleMessage(
      "Требуется одобрение устройства",
    ),
    "tailscaleNodeKey": MessageLookupByLibrary.simpleMessage("Ключ узла"),
    "tailscaleRelay": MessageLookupByLibrary.simpleMessage("Ретранслятор DERP"),
    "tailscaleSubnets": MessageLookupByLibrary.simpleMessage("Подсети"),
    "tailscaleTags": MessageLookupByLibrary.simpleMessage("Теги"),
    "tapIconToRetry": MessageLookupByLibrary.simpleMessage(
      "Нажмите на значок, чтобы повторить",
    ),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage(
      "Нажмите, чтобы разрешить",
    ),
    "target": MessageLookupByLibrary.simpleMessage("Цель"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("Параллельный TCP"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "При включении разрешает параллельные TCP-подключения",
    ),
    "testInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал тестирования",
    ),
    "testUrl": MessageLookupByLibrary.simpleMessage("URL для теста"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage(
      "Тестировать при использовании",
    ),
    "textReplacement": MessageLookupByLibrary.simpleMessage(
      "Подстановка текста:",
    ),
    "textScale": MessageLookupByLibrary.simpleMessage("Масштаб текста"),
    "textScalePreview": MessageLookupByLibrary.simpleMessage(
      "Так будет выглядеть текст в приложении",
    ),
    "theme": MessageLookupByLibrary.simpleMessage("Тема"),
    "themeColor": MessageLookupByLibrary.simpleMessage("Цвет темы"),
    "themeMode": MessageLookupByLibrary.simpleMessage("Режим темы"),
    "tight": MessageLookupByLibrary.simpleMessage("Плотный"),
    "time": MessageLookupByLibrary.simpleMessage("Время"),
    "timeout": MessageLookupByLibrary.simpleMessage("Тайм-аут"),
    "tintedStyle": MessageLookupByLibrary.simpleMessage("Тонированный"),
    "tip": MessageLookupByLibrary.simpleMessage("Подсказка"),
    "toggle": MessageLookupByLibrary.simpleMessage("Переключить"),
    "toggleLabel": MessageLookupByLibrary.simpleMessage("Переключить подписи"),
    "tolerance": MessageLookupByLibrary.simpleMessage("Допуск"),
    "tools": MessageLookupByLibrary.simpleMessage("Инструменты"),
    "torch": MessageLookupByLibrary.simpleMessage("Фонарик"),
    "total": MessageLookupByLibrary.simpleMessage("Всего"),
    "totalDownload": MessageLookupByLibrary.simpleMessage("Загружено"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("Общий трафик"),
    "totalUpload": MessageLookupByLibrary.simpleMessage("Отдано"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Порт TProxy"),
    "traffic": MessageLookupByLibrary.simpleMessage("Трафик"),
    "trafficBoth": MessageLookupByLibrary.simpleMessage("Оба"),
    "trafficPeak": m81,
    "trafficTotal": m82,
    "trafficUsage": MessageLookupByLibrary.simpleMessage("Статистика трафика"),
    "transport": MessageLookupByLibrary.simpleMessage("Транспорт"),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunAuthorizationFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось получить права для TUN, поэтому он выключен.",
    ),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "TUN работает только в режиме администратора.",
    ),
    "tunDnsMode": MessageLookupByLibrary.simpleMessage("Режим системного DNS"),
    "tunDnsModeDisabled": MessageLookupByLibrary.simpleMessage("Отключено"),
    "tunDnsModeHijack": MessageLookupByLibrary.simpleMessage("Перехват"),
    "tunDnsModeNative": MessageLookupByLibrary.simpleMessage("Нативный"),
    "tunOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Добавленные здесь параметры заменяют настройки TUN всех профилей; остальные остаются такими, как в профиле. Параметры, добавленные в самом пользовательском профиле, имеют приоритет.",
    ),
    "turnOff": MessageLookupByLibrary.simpleMessage("Выключить"),
    "turnOn": MessageLookupByLibrary.simpleMessage("Включить"),
    "tvMode": MessageLookupByLibrary.simpleMessage("Режим ТВ"),
    "tvModeDesc": MessageLookupByLibrary.simpleMessage(
      "Использовать раскладку для пульта на этом устройстве",
    ),
    "udpRelayMode": MessageLookupByLibrary.simpleMessage(
      "Режим ретрансляции UDP",
    ),
    "udpTimeout": MessageLookupByLibrary.simpleMessage("Тайм-аут UDP"),
    "udpTimeoutDesc": MessageLookupByLibrary.simpleMessage(
      "Тайм-аут UDP задаётся в секундах и действует только со стеками gvisor, system и mixed.",
    ),
    "uiUpdateIdleInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал обновления в бездействии",
    ),
    "uiUpdateIdleWhenUnfocused": MessageLookupByLibrary.simpleMessage(
      "Бездействие без фокуса",
    ),
    "uiUpdateIdleWhenUnfocusedDesc": MessageLookupByLibrary.simpleMessage(
      "Использовать интервал бездействия, когда окно приложения теряет фокус",
    ),
    "uiUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал обновления информации UI",
    ),
    "uiUpdateIntervalDesc": m83,
    "uiUpdateIntervalIdleDisabledDesc": m84,
    "ultra": MessageLookupByLibrary.simpleMessage("Максимум"),
    "unauthorized": MessageLookupByLibrary.simpleMessage("Не разрешено"),
    "undo": MessageLookupByLibrary.simpleMessage("Отменить"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("Единая задержка"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "Убирает лишние задержки, например рукопожатие",
    ),
    "uninitialized": MessageLookupByLibrary.simpleMessage(
      "Не инициализировано",
    ),
    "unknown": MessageLookupByLibrary.simpleMessage("Неизвестно"),
    "unknownBackupVariable": MessageLookupByLibrary.simpleMessage(
      "Неизвестная переменная. Выберите одну из переменных ниже.",
    ),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage(
      "Неизвестная сетевая ошибка",
    ),
    "unmaximize": MessageLookupByLibrary.simpleMessage("Свернуть в окно"),
    "unnamed": MessageLookupByLibrary.simpleMessage("Без названия"),
    "unpinWindow": MessageLookupByLibrary.simpleMessage("Открепить окно"),
    "update": MessageLookupByLibrary.simpleMessage("Обновить"),
    "updateChecksumMismatch": MessageLookupByLibrary.simpleMessage(
      "Загруженный файл не совпадает с опубликованной контрольной суммой и был удалён.",
    ),
    "updateDownloading": MessageLookupByLibrary.simpleMessage(
      "Загрузка обновления",
    ),
    "updateInstallFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось запустить установщик.",
    ),
    "updateInstallPermission": MessageLookupByLibrary.simpleMessage(
      "FlClash не получил разрешение на установку приложений, поэтому обновление не установлено.",
    ),
    "updateNotWritable": MessageLookupByLibrary.simpleMessage(
      "FlClash не может записывать в папку установки. Загрузите обновление вручную.",
    ),
    "updateNow": MessageLookupByLibrary.simpleMessage("Обновить сейчас"),
    "upload": MessageLookupByLibrary.simpleMessage("Отдача"),
    "uploadBandwidth": MessageLookupByLibrary.simpleMessage("Скорость отдачи"),
    "uploadSpeed": MessageLookupByLibrary.simpleMessage("Скорость загрузки"),
    "uploadTraffic": MessageLookupByLibrary.simpleMessage("Исходящий трафик"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage("Получить профиль по URL"),
    "urlTip": m85,
    "useHosts": MessageLookupByLibrary.simpleMessage("Использовать hosts"),
    "useHostsDesc": MessageLookupByLibrary.simpleMessage(
      "Проверяет записи hosts из конфигурации перед запросом к вышестоящим DNS-серверам",
    ),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage(
      "Использовать системный hosts",
    ),
    "useSystemHostsDesc": MessageLookupByLibrary.simpleMessage(
      "Проверяет системный файл Hosts при разрешении доменных имен",
    ),
    "usedShort": MessageLookupByLibrary.simpleMessage("использовано"),
    "usedTraffic": MessageLookupByLibrary.simpleMessage(
      "Использованный трафик",
    ),
    "userAgent": MessageLookupByLibrary.simpleMessage("User-Agent"),
    "username": MessageLookupByLibrary.simpleMessage("Имя пользователя"),
    "value": MessageLookupByLibrary.simpleMessage("Значение"),
    "version": MessageLookupByLibrary.simpleMessage("Версия"),
    "view": MessageLookupByLibrary.simpleMessage("Просмотр"),
    "virtualIpv4": MessageLookupByLibrary.simpleMessage("Виртуальный IPv4"),
    "vividStyle": MessageLookupByLibrary.simpleMessage("Яркий"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "Обнаружено изменение настроек VPN",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "VPN автоматически направляет весь системный трафик через VpnService.",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage(
      "Настройка WebDAV",
    ),
    "whitelistMode": MessageLookupByLibrary.simpleMessage(
      "Режим белого списка",
    ),
    "writeToSystem": MessageLookupByLibrary.simpleMessage(
      "Записывать в систему",
    ),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage(
      "«Записывать в систему» также устанавливает системные часы; Android это игнорирует.",
    ),
    "yearsAgo": m86,
    "yearsAgoShort": m87,
    "yes": MessageLookupByLibrary.simpleMessage("Да"),
    "zhCN": MessageLookupByLibrary.simpleMessage("Упрощённый китайский"),
    "zhTW": MessageLookupByLibrary.simpleMessage("Традиционный китайский"),
    "zolnitAccountHelpHint": MessageLookupByLibrary.simpleMessage(
      "Есть вопросы? Мы на связи",
    ),
    "zolnitAccountOrdersHint": MessageLookupByLibrary.simpleMessage(
      "Просмотр заказов на подключение и продление",
    ),
    "zolnitAccountPassword": MessageLookupByLibrary.simpleMessage(
      "Пароль для входа",
    ),
    "zolnitAccountPreferencesHint": MessageLookupByLibrary.simpleMessage(
      "Подключайтесь по-своему",
    ),
    "zolnitAccountSubtitle": MessageLookupByLibrary.simpleMessage(
      "Ваше пространство подключения.",
    ),
    "zolnitAccountTitle": MessageLookupByLibrary.simpleMessage("Мой аккаунт"),
    "zolnitActivating": MessageLookupByLibrary.simpleMessage("Активация"),
    "zolnitAdvanced": MessageLookupByLibrary.simpleMessage(
      "Дополнительные настройки",
    ),
    "zolnitAdvancedHint": MessageLookupByLibrary.simpleMessage(
      "Просмотр профилей подключения и других параметров",
    ),
    "zolnitAllNodes": MessageLookupByLibrary.simpleMessage("Все узлы"),
    "zolnitAllRegions": MessageLookupByLibrary.simpleMessage("Все регионы"),
    "zolnitAmountDue": MessageLookupByLibrary.simpleMessage("К оплате"),
    "zolnitBalance": MessageLookupByLibrary.simpleMessage("Баланс аккаунта"),
    "zolnitBilledMonthly": MessageLookupByLibrary.simpleMessage(
      "Оплата помесячно — удобное начало",
    ),
    "zolnitBilledOnce": m88,
    "zolnitBillingUnavailable": MessageLookupByLibrary.simpleMessage(
      "Данные о продлении временно недоступны.",
    ),
    "zolnitBuy": MessageLookupByLibrary.simpleMessage("Создать заказ"),
    "zolnitCancelOrder": MessageLookupByLibrary.simpleMessage("Отменить заказ"),
    "zolnitCancelOrderTip": MessageLookupByLibrary.simpleMessage(
      "Отменить этот неоплаченный заказ?",
    ),
    "zolnitCancelRenewal": MessageLookupByLibrary.simpleMessage(
      "Отменить автопродление",
    ),
    "zolnitCancelRenewalTip": MessageLookupByLibrary.simpleMessage(
      "Будущие автоматические списания прекратятся. Неоплаченный первый заказ тоже будет отменён. Оплаченный доступ определяется результатом сервера.",
    ),
    "zolnitCanceled": MessageLookupByLibrary.simpleMessage("Отменён"),
    "zolnitChangePassword": MessageLookupByLibrary.simpleMessage(
      "Изменить пароль",
    ),
    "zolnitCheckoutExists": MessageLookupByLibrary.simpleMessage(
      "Оплата уже обрабатывается. Проверьте статус в разделе «Аккаунт» и не отправляйте повторно.",
    ),
    "zolnitCheckoutProcessing": MessageLookupByLibrary.simpleMessage(
      "Оплата готовится или проверяется. Повторите попытку чуть позже.",
    ),
    "zolnitChoosePlan": MessageLookupByLibrary.simpleMessage("Выбрать тариф"),
    "zolnitCompleted": MessageLookupByLibrary.simpleMessage("Завершён"),
    "zolnitConnectHeadline": MessageLookupByLibrary.simpleMessage(
      "Одно касание — и вы на связи",
    ),
    "zolnitConnectOnLaunch": MessageLookupByLibrary.simpleMessage(
      "Автоподключение при запуске",
    ),
    "zolnitConnectOnLaunchHint": MessageLookupByLibrary.simpleMessage(
      "Используется последний выбранный профиль подписки.",
    ),
    "zolnitConnectSub": MessageLookupByLibrary.simpleMessage(
      "Выберите маршрут, остальное сделает ZolNit.",
    ),
    "zolnitCopyCode": MessageLookupByLibrary.simpleMessage("Копировать код"),
    "zolnitCopyLink": MessageLookupByLibrary.simpleMessage("Копировать ссылку"),
    "zolnitCredentialsInvalid": MessageLookupByLibrary.simpleMessage(
      "Введите действующий адрес почты и пароль не короче восьми символов.",
    ),
    "zolnitCredited": MessageLookupByLibrary.simpleMessage("Зачтён"),
    "zolnitCurrentBadge": MessageLookupByLibrary.simpleMessage("Текущий тариф"),
    "zolnitCurrentPlanHint": m89,
    "zolnitCurrentPlanLine": m90,
    "zolnitCurrentSelection": MessageLookupByLibrary.simpleMessage("Выбрано"),
    "zolnitCycleHalfYear": MessageLookupByLibrary.simpleMessage("полгода"),
    "zolnitCycleQuarter": MessageLookupByLibrary.simpleMessage("квартал"),
    "zolnitCycleThreeYears": MessageLookupByLibrary.simpleMessage("три года"),
    "zolnitCycleTwoYears": MessageLookupByLibrary.simpleMessage("два года"),
    "zolnitCycleYear": MessageLookupByLibrary.simpleMessage("год"),
    "zolnitDaysLeftLabel": m91,
    "zolnitDaysUnit": MessageLookupByLibrary.simpleMessage("дн."),
    "zolnitDevicesHint": MessageLookupByLibrary.simpleMessage(
      "Здесь показаны сеансы входа в аккаунт; это не то же самое, что число онлайн-IP узла.",
    ),
    "zolnitDevicesTitle": MessageLookupByLibrary.simpleMessage("Сеансы входа"),
    "zolnitDevicesUnavailable": MessageLookupByLibrary.simpleMessage(
      "Сейчас не удаётся загрузить сеансы входа. Повторите попытку.",
    ),
    "zolnitEmail": MessageLookupByLibrary.simpleMessage("Электронная почта"),
    "zolnitEveryScreen": MessageLookupByLibrary.simpleMessage(
      "Привычный интерфейс на каждом экране",
    ),
    "zolnitExpiresOn": m92,
    "zolnitFailure": MessageLookupByLibrary.simpleMessage(
      "Не удалось завершить запрос. Проверьте данные и соединение и повторите попытку.",
    ),
    "zolnitFeatureDevices": m93,
    "zolnitFeatureSpeed": m94,
    "zolnitFeatureTraffic": m95,
    "zolnitFirstCharge": MessageLookupByLibrary.simpleMessage("Первый платёж"),
    "zolnitFollowingCharge": MessageLookupByLibrary.simpleMessage(
      "Последующие платежи",
    ),
    "zolnitForgotPassword": MessageLookupByLibrary.simpleMessage(
      "Забыли пароль?",
    ),
    "zolnitGift": MessageLookupByLibrary.simpleMessage("Подарочный доступ"),
    "zolnitGiftReplacement": MessageLookupByLibrary.simpleMessage(
      "Платный период начинается после подтверждения первого платежа и заменяет оставшееся подарочное время.",
    ),
    "zolnitGlobalRoutes": MessageLookupByLibrary.simpleMessage(
      "Отобранные маршруты по всему миру",
    ),
    "zolnitGreeting": m96,
    "zolnitGreetingSub": MessageLookupByLibrary.simpleMessage(
      "Готовы открыть для себя мир шире.",
    ),
    "zolnitHalfYearly": MessageLookupByLibrary.simpleMessage("Раз в полгода"),
    "zolnitHelpSupport": MessageLookupByLibrary.simpleMessage(
      "Помощь и поддержка",
    ),
    "zolnitInviteCode": MessageLookupByLibrary.simpleMessage("Код приглашения"),
    "zolnitInviteCodeCopied": MessageLookupByLibrary.simpleMessage(
      "Код скопирован",
    ),
    "zolnitInviteCommissionAvailable": MessageLookupByLibrary.simpleMessage(
      "Доступная комиссия",
    ),
    "zolnitInviteCommissionConfirmed": MessageLookupByLibrary.simpleMessage(
      "Подтверждённая комиссия",
    ),
    "zolnitInviteCommissionPending": MessageLookupByLibrary.simpleMessage(
      "Ожидающая комиссия",
    ),
    "zolnitInviteCommissionRate": MessageLookupByLibrary.simpleMessage(
      "Ставка комиссии",
    ),
    "zolnitInviteCopied": MessageLookupByLibrary.simpleMessage(
      "Ссылка скопирована",
    ),
    "zolnitInviteCreateCode": MessageLookupByLibrary.simpleMessage(
      "Создать код приглашения",
    ),
    "zolnitInviteCreateFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось создать код приглашения. Попробуйте ещё раз.",
    ),
    "zolnitInviteHeadline": MessageLookupByLibrary.simpleMessage(
      "Делитесь подключением — получайте бонус.",
    ),
    "zolnitInviteLink": MessageLookupByLibrary.simpleMessage(
      "Ссылка-приглашение",
    ),
    "zolnitInviteLoadFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось загрузить данные приглашений. Попробуйте ещё раз.",
    ),
    "zolnitInviteNoData": MessageLookupByLibrary.simpleMessage(
      "Пригласите друзей, чтобы начать.",
    ),
    "zolnitInvitePeople": MessageLookupByLibrary.simpleMessage("чел."),
    "zolnitInviteRegistered": MessageLookupByLibrary.simpleMessage(
      "Зарегистрировано",
    ),
    "zolnitInviteRules": MessageLookupByLibrary.simpleMessage(
      "Правила приглашений",
    ),
    "zolnitInviteShare": MessageLookupByLibrary.simpleMessage(
      "Ваше приглашение",
    ),
    "zolnitInviteShareHint": MessageLookupByLibrary.simpleMessage(
      "Друзья регистрируются по ссылке. Вы получаете вознаграждение после их подписки.",
    ),
    "zolnitInviteSubtitle": MessageLookupByLibrary.simpleMessage(
      "Пригласите друзей зарегистрироваться и подписаться по вашей ссылке.",
    ),
    "zolnitLatency": MessageLookupByLibrary.simpleMessage("Задержка"),
    "zolnitLatestNotices": MessageLookupByLibrary.simpleMessage(
      "Последние объявления",
    ),
    "zolnitLoginDescription": MessageLookupByLibrary.simpleMessage(
      "Без сложных настроек. Весь мир — в одном подключении.",
    ),
    "zolnitLoginEyebrow": MessageLookupByLibrary.simpleMessage(
      "Чуть ближе к вашему миру",
    ),
    "zolnitLoginSubtitle": MessageLookupByLibrary.simpleMessage(
      "Войдите, чтобы управлять тарифом и подключениями.",
    ),
    "zolnitLoginWebsite": MessageLookupByLibrary.simpleMessage(
      "Регистрация или восстановление пароля",
    ),
    "zolnitMembershipEyebrow": MessageLookupByLibrary.simpleMessage(
      "YOUR MEMBERSHIP",
    ),
    "zolnitModeGlobal": MessageLookupByLibrary.simpleMessage("Глобальный"),
    "zolnitModeSmart": MessageLookupByLibrary.simpleMessage(
      "Умная маршрутизация",
    ),
    "zolnitMonthly": MessageLookupByLibrary.simpleMessage("Ежемесячно"),
    "zolnitMonthlyEnrollment": MessageLookupByLibrary.simpleMessage(
      "Ежемесячная автоматическая оплата",
    ),
    "zolnitMySpace": MessageLookupByLibrary.simpleMessage("Моё пространство"),
    "zolnitNewPassword": MessageLookupByLibrary.simpleMessage("Новый пароль"),
    "zolnitNextRenewal": MessageLookupByLibrary.simpleMessage(
      "Следующее продление",
    ),
    "zolnitNoCurrentPlanHint": MessageLookupByLibrary.simpleMessage(
      "У вас пока нет активного тарифа. Выберите его ниже, чтобы начать.",
    ),
    "zolnitNoDevices": MessageLookupByLibrary.simpleMessage(
      "Нет сеансов входа для отображения.",
    ),
    "zolnitNoMatchingNodes": MessageLookupByLibrary.simpleMessage(
      "Подходящих узлов нет. Попробуйте другие ключевые слова или регионы.",
    ),
    "zolnitNoMethods": MessageLookupByLibrary.simpleMessage(
      "Нет доступных способов оплаты",
    ),
    "zolnitNoNodes": MessageLookupByLibrary.simpleMessage(
      "Для этой подписки нет доступных узлов.",
    ),
    "zolnitNoNotices": MessageLookupByLibrary.simpleMessage(
      "Объявлений пока нет",
    ),
    "zolnitNoOrders": MessageLookupByLibrary.simpleMessage("Заказов пока нет"),
    "zolnitNoPlan": MessageLookupByLibrary.simpleMessage(
      "Нет активного тарифа",
    ),
    "zolnitNoRenewals": MessageLookupByLibrary.simpleMessage(
      "Нет договоров автопродления",
    ),
    "zolnitNodeMeasurementHint": MessageLookupByLibrary.simpleMessage(
      "Задержка показывает результат последней реальной проверки; если проверки не было, отображается —.",
    ),
    "zolnitNodeMultiplier": m97,
    "zolnitNodeName": MessageLookupByLibrary.simpleMessage("Узел"),
    "zolnitNodeSyncHint": MessageLookupByLibrary.simpleMessage(
      "После синхронизации подписки выберите узел из профиля.",
    ),
    "zolnitNodesCount": m98,
    "zolnitNodesHeadline": MessageLookupByLibrary.simpleMessage(
      "Ваш мир начинается здесь.",
    ),
    "zolnitNodesSubtitle": MessageLookupByLibrary.simpleMessage(
      "Выберите подходящий маршрут и подключайтесь без усилий.",
    ),
    "zolnitNotConnected": MessageLookupByLibrary.simpleMessage(
      "Подключение пока не выполнено",
    ),
    "zolnitNotices": MessageLookupByLibrary.simpleMessage("Объявления"),
    "zolnitOldPassword": MessageLookupByLibrary.simpleMessage("Текущий пароль"),
    "zolnitOneTime": MessageLookupByLibrary.simpleMessage("Разовый платёж"),
    "zolnitOnlineDevices": MessageLookupByLibrary.simpleMessage(
      "Устройства онлайн",
    ),
    "zolnitOrders": MessageLookupByLibrary.simpleMessage("Заказы"),
    "zolnitOutOfDevices": m99,
    "zolnitPaid": MessageLookupByLibrary.simpleMessage("Оплаченный доступ"),
    "zolnitPaidThrough": MessageLookupByLibrary.simpleMessage("Оплачено до"),
    "zolnitPasswordInvalid": MessageLookupByLibrary.simpleMessage(
      "Введите текущий пароль и другой новый пароль не короче восьми символов.",
    ),
    "zolnitPasswordUpdated": MessageLookupByLibrary.simpleMessage(
      "Пароль обновлён.",
    ),
    "zolnitPay": MessageLookupByLibrary.simpleMessage("Оплатить заказ"),
    "zolnitPaymentReturn": MessageLookupByLibrary.simpleMessage(
      "После возвращения с оплаты статус заказа ещё нужно подтвердить.",
    ),
    "zolnitPaymentStatus": MessageLookupByLibrary.simpleMessage(
      "Статус оплаты",
    ),
    "zolnitPaymentUnavailable": MessageLookupByLibrary.simpleMessage(
      "Этот способ оплаты пока недоступен.",
    ),
    "zolnitPending": MessageLookupByLibrary.simpleMessage("Ожидает оплаты"),
    "zolnitPendingOrder": MessageLookupByLibrary.simpleMessage(
      "У вас есть неоплаченный заказ. Продолжите оплату или закройте его в разделе «Заказы», прежде чем оформлять новый.",
    ),
    "zolnitPerMonth": MessageLookupByLibrary.simpleMessage("/ мес."),
    "zolnitPlanSwitch": MessageLookupByLibrary.simpleMessage(
      "Новый тариф начинается после подтверждения первого платежа или зачёта остаточной стоимости.",
    ),
    "zolnitPlanValidity": MessageLookupByLibrary.simpleMessage(
      "Срок действия тарифа",
    ),
    "zolnitPlans": MessageLookupByLibrary.simpleMessage("Тарифы"),
    "zolnitPlansHeadline": MessageLookupByLibrary.simpleMessage(
      "Подходящий тариф — подходящая свобода.",
    ),
    "zolnitPlansSub": MessageLookupByLibrary.simpleMessage(
      "От повседневного просмотра сайтов до плавного стриминга — выберите подходящее подключение.",
    ),
    "zolnitPreferences": MessageLookupByLibrary.simpleMessage("Настройки"),
    "zolnitPreferencesHeadline": MessageLookupByLibrary.simpleMessage(
      "Подключайтесь по-своему.",
    ),
    "zolnitPreferencesSafeHint": MessageLookupByLibrary.simpleMessage(
      "Безопасный режим сохраняет настройки, но не подключается автоматически и не меняет сеть системы.",
    ),
    "zolnitPreferencesSubtitle": MessageLookupByLibrary.simpleMessage(
      "Только действительно нужные настройки.",
    ),
    "zolnitProfileSource": MessageLookupByLibrary.simpleMessage(
      "Узлы и правила маршрутизации автоматически синхронизируются с ZolNit.",
    ),
    "zolnitQuarterly": MessageLookupByLibrary.simpleMessage("Раз в три месяца"),
    "zolnitQuoteBeforeConsent": MessageLookupByLibrary.simpleMessage(
      "Проверьте расчёт сервера перед согласием на автопродление.",
    ),
    "zolnitQuoteExpired": MessageLookupByLibrary.simpleMessage(
      "Расчёт устарел. Вернитесь к тарифам и выберите снова.",
    ),
    "zolnitRateLimited": MessageLookupByLibrary.simpleMessage(
      "Слишком много попыток. Повторите чуть позже.",
    ),
    "zolnitRecommendedNodes": MessageLookupByLibrary.simpleMessage(
      "Рекомендуемые узлы",
    ),
    "zolnitRecommendedNodesSub": MessageLookupByLibrary.simpleMessage(
      "Сначала ближайшие — подключение быстрее",
    ),
    "zolnitRecommendedRoute": MessageLookupByLibrary.simpleMessage(
      "Рекомендуется",
    ),
    "zolnitRecurringConsent": MessageLookupByLibrary.simpleMessage(
      "Я согласен на регулярную оплату этого тарифа по указанным условиям первого платежа и продления.",
    ),
    "zolnitRecurringUnavailable": MessageLookupByLibrary.simpleMessage(
      "Ежемесячная автоматическая оплата для этого тарифа сейчас недоступна.",
    ),
    "zolnitRefresh": MessageLookupByLibrary.simpleMessage("Обновить"),
    "zolnitRegister": MessageLookupByLibrary.simpleMessage("Регистрация"),
    "zolnitRegistrationWebsiteHint": MessageLookupByLibrary.simpleMessage(
      "Регистрация и восстановление пароля выполняются на сайте ZolNit с проверкой почты и безопасности.",
    ),
    "zolnitRenewCurrent": MessageLookupByLibrary.simpleMessage(
      "Продлить текущий тариф",
    ),
    "zolnitRenewPlan": MessageLookupByLibrary.simpleMessage("Продлить тариф"),
    "zolnitRenewals": MessageLookupByLibrary.simpleMessage(
      "Автоматическое продление",
    ),
    "zolnitResetInDays": m100,
    "zolnitResetTraffic": MessageLookupByLibrary.simpleMessage(
      "Сбросить трафик",
    ),
    "zolnitResumeRenewal": MessageLookupByLibrary.simpleMessage(
      "Возобновить автопродление",
    ),
    "zolnitResumeRenewalTip": MessageLookupByLibrary.simpleMessage(
      "Возобновить автоматические списания по одобренному тарифу.",
    ),
    "zolnitRevokeDevice": MessageLookupByLibrary.simpleMessage(
      "Выйти из этого сеанса",
    ),
    "zolnitRevokeDeviceDone": MessageLookupByLibrary.simpleMessage(
      "Сеанс входа завершён.",
    ),
    "zolnitRevokeDeviceTip": MessageLookupByLibrary.simpleMessage(
      "Завершить этот сеанс входа? Чтобы управлять аккаунтом, на этом устройстве потребуется войти снова.",
    ),
    "zolnitSafeModeConnect": MessageLookupByLibrary.simpleMessage(
      "Безопасный режим не меняет сетевые настройки системы.",
    ),
    "zolnitSavePercent": m101,
    "zolnitSearchNodes": MessageLookupByLibrary.simpleMessage(
      "Поиск узлов или регионов",
    ),
    "zolnitSelectColumn": MessageLookupByLibrary.simpleMessage("Выбор"),
    "zolnitSessionOnly": MessageLookupByLibrary.simpleMessage(
      "Вы останетесь в аккаунте до закрытия приложения.",
    ),
    "zolnitSignIn": MessageLookupByLibrary.simpleMessage("Войти"),
    "zolnitSignOut": MessageLookupByLibrary.simpleMessage("Выйти"),
    "zolnitStartOnBoot": MessageLookupByLibrary.simpleMessage(
      "Запускать ZolNit при старте системы",
    ),
    "zolnitStartOnBootHint": MessageLookupByLibrary.simpleMessage(
      "ZolNit будет готов сразу после включения устройства.",
    ),
    "zolnitStatusActive": MessageLookupByLibrary.simpleMessage("Активен"),
    "zolnitStatusExpired": MessageLookupByLibrary.simpleMessage("Истёк"),
    "zolnitStatusNoPlan": MessageLookupByLibrary.simpleMessage("Нет тарифа"),
    "zolnitSubscribePlan": MessageLookupByLibrary.simpleMessage(
      "Выбрать тариф",
    ),
    "zolnitSync": MessageLookupByLibrary.simpleMessage(
      "Синхронизировать профиль подключения",
    ),
    "zolnitSynced": MessageLookupByLibrary.simpleMessage(
      "Профиль подключения синхронизирован",
    ),
    "zolnitSyncing": MessageLookupByLibrary.simpleMessage(
      "Синхронизация профиля подключения…",
    ),
    "zolnitTabAccount": MessageLookupByLibrary.simpleMessage("Аккаунт"),
    "zolnitTabInvite": MessageLookupByLibrary.simpleMessage("Приглашения"),
    "zolnitTabOrders": MessageLookupByLibrary.simpleMessage("Заказы"),
    "zolnitTagline": MessageLookupByLibrary.simpleMessage(
      "Подключение без лишних сложностей.",
    ),
    "zolnitThreeYearly": MessageLookupByLibrary.simpleMessage("Раз в три года"),
    "zolnitTrafficLeft": MessageLookupByLibrary.simpleMessage(
      "Остаток трафика",
    ),
    "zolnitTrafficUsed": MessageLookupByLibrary.simpleMessage(
      "Использовано за период",
    ),
    "zolnitTwoYearly": MessageLookupByLibrary.simpleMessage("Раз в два года"),
    "zolnitUnknownDevice": MessageLookupByLibrary.simpleMessage("Сеанс входа"),
    "zolnitViewMonthlyQuote": MessageLookupByLibrary.simpleMessage(
      "Посмотреть месячный расчёт",
    ),
    "zolnitWebsite": MessageLookupByLibrary.simpleMessage(
      "Открыть сайт ZolNit",
    ),
    "zolnitWelcome": MessageLookupByLibrary.simpleMessage("С возвращением"),
    "zolnitWorkspace": MessageLookupByLibrary.simpleMessage("YOUR WORKSPACE"),
    "zolnitYearly": MessageLookupByLibrary.simpleMessage("Ежегодно"),
  };
}
