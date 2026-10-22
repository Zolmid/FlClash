// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a es locale. All the
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
  String get localeName => 'es';

  static String m0(count, skipped) =>
      "${count} por añadir, ${skipped} omitidos por ya existir";

  static String m1(detail) => "No se pudieron borrar los datos: ${detail}";

  static String m2(code) =>
      "Windows se negó a ejecutar FlClashCore.exe (error ${code}). Una directiva de control de aplicaciones, como Smart App Control o AppLocker, bloquea los programas sin firmar; permite FlClash en esa directiva o desactívala e inténtalo de nuevo.";

  static String m3(name) =>
      "La app no pudo terminar de iniciarse dos veces seguidas. Para romper el ciclo, se ha deseleccionado el perfil ${name} y se ha omitido la configuración automática. Puedes volver a seleccionarlo en cualquier momento.";

  static String m4(url) => "¿Quieres crear un perfil a partir de ${url}?";

  static String m5(count, label) =>
      "${Intl.plural(count, one: 'Se descartó 1 regla SUB-RULE, porque los perfiles personalizados no admiten subreglas', other: 'Se descartaron ${label} reglas SUB-RULE, porque los perfiles personalizados no admiten subreglas')}";

  static String m6(message) =>
      "El núcleo no puede interpretar este proxy: ${message}";

  static String m7(proxy, target) =>
      "${proxy} marca a través de ${target}, que lleva de vuelta a ${proxy}, por lo que la marcación entra en bucle";

  static String m8(name) =>
      "El nombre ${name} ya lo usa otro proxy o grupo de proxies";

  static String m9(path) =>
      "Los grupos de proxies se referencian entre sí en bucle: ${path}";

  static String m10(name) =>
      "El respaldo si está vacío debe ser un proxy, pero ${name} no existe o es un grupo de proxies";

  static String m11(name, message) =>
      "${name} no es una expresión regular válida: ${message}";

  static String m12(name) => "El proxy de marcación ${name} no existe";

  static String m13(names) =>
      "Estos proveedores de proxies no existen: ${names}";

  static String m14(names) => "Estos proxies o políticas no existen: ${names}";

  static String m15(name) =>
      "${name} es un nombre de política integrada y no se puede usar aquí";

  static String m16(count) =>
      "${count} elementos tienen problemas, y aplicar este perfil puede fallar";

  static String m17(count) =>
      "${Intl.plural(count, one: 'hace 1 día', other: 'hace ${count} días')}";

  static String m18(count) => "${Intl.plural(count, other: 'hace ${count} d')}";

  static String m19(label) =>
      "¿Seguro que quieres eliminar los elementos seleccionados (${label})?";

  static String m20(label) =>
      "¿Seguro que quieres eliminar este elemento (${label})?";

  static String m21(label) => "Detalles de ${label}";

  static String m22(name) =>
      "La marcación a través de ${name} lleva de vuelta al proxy que lo usa, por lo que se detuvo la conexión";

  static String m23(label) => "${label} no puede estar vacío";

  static String m24(count) =>
      "${Intl.plural(count, one: '1 entrada', other: '${count} entradas')}";

  static String m25(label) => "${label} ya existe";

  static String m26(count) => "${count} elementos fallaron";

  static String m27(label, message) => "${label}: ${message}";

  static String m28(name) => "${name} ya está actualizado";

  static String m29(name) => "${name} actualizado";

  static String m30(name) => "Actualizando ${name}…";

  static String m31(count) =>
      "${Intl.plural(count, one: '1 grupo', other: '${count} grupos')}";

  static String m32(count) => "${count} sin respuesta";

  static String m33(action) =>
      "Ya lo usa “${action}”. Al guardar, pasará a este.";

  static String m34(modifiers) =>
      "Incluye al menos una de estas teclas: ${modifiers}";

  static String m35(count) =>
      "${Intl.plural(count, one: 'hace 1 hora', other: 'hace ${count} horas')}";

  static String m36(count) => "${Intl.plural(count, other: 'hace ${count} h')}";

  static String m37(target) => "${target} no es una política válida";

  static String m38(proxyName) => "${proxyName} no es un proxy válido";

  static String m39(providerName) =>
      "${providerName} no es un proveedor de proxies válido";

  static String m40(ruleSet) => "${ruleSet} no es un conjunto de reglas válido";

  static String m41(subRule) => "${subRule} no es una SUB_RULE válida";

  static String m42(count) =>
      "${Intl.plural(count, one: '1 elemento', other: '${count} elementos')}";

  static String m43(line, message) => "Línea ${line}: ${message}";

  static String m44(appName) =>
      "1. Abre Ajustes del sistema > Privacidad y seguridad\n2. Elige Servicios de localización\n3. Busca ${appName} en la lista y márcalo\n\nCuando termines, vuelve a la app para continuar. Gracias por tu colaboración.";

  static String m45(label, max) =>
      "${label} debe tener como máximo ${max} caracteres";

  static String m46(size) => "Liberado: ${size}";

  static String m47(count) =>
      "${Intl.plural(count, one: 'hace 1 minuto', other: 'hace ${count} minutos')}";

  static String m48(count) =>
      "${Intl.plural(count, other: 'hace ${count} min')}";

  static String m49(count) =>
      "${Intl.plural(count, one: 'hace 1 mes', other: 'hace ${count} meses')}";

  static String m50(count) => "${Intl.plural(count, other: 'hace ${count} m')}";

  static String m51(code) =>
      "El servidor denegó el acceso (HTTP ${code}). Puede que el enlace haya caducado o que las credenciales sean incorrectas";

  static String m52(code) => "El servidor rechazó la solicitud (HTTP ${code})";

  static String m53(code) =>
      "No se encontró nada en esta dirección (HTTP ${code}). Comprueba que la URL sea correcta";

  static String m54(detail) => "Falló la solicitud de red: ${detail}";

  static String m55(code) =>
      "El servidor tuvo un problema (HTTP ${code}). Inténtalo de nuevo más tarde";

  static String m56(label) => "Aún no hay ningún elemento (${label})";

  static String m57(label, min, max) =>
      "${label} debe estar entre ${min} y ${max}";

  static String m58(label) => "${label} debe ser un número";

  static String m59(label) => "${label} debe estar entre 1024 y 49151";

  static String m60(port) => "Puerto ${port}";

  static String m61(days) =>
      "${Intl.plural(days, one: 'Queda 1 día', other: 'Quedan ${days} días')}";

  static String m62(date, days) =>
      "Vence el ${date}, ${Intl.plural(days, one: 'queda 1 día', other: 'quedan ${days} días')}";

  static String m63(time) => "Actualizado ${time}";

  static String m64(label, profiles) =>
      "${label} sigue en uso en ${profiles}, que dejarán de funcionar correctamente si se elimina. ¿Seguro que quieres eliminarlo?";

  static String m65(count, label) =>
      "${Intl.plural(count, one: '1 proxy', other: '${label} proxies')}";

  static String m66(name, count) => "${name} y otros (${count} proxies)";

  static String m67(removed) =>
      "Se eliminarán estos proxies: ${removed}. Una línea cuyo nombre cambió cuenta como un proxy nuevo, y los perfiles personalizados que mencionen los eliminados los marcarán como ausentes. ¿Aplicar de todos modos?";

  static String m68(removed, added) =>
      "Se eliminarán estos proxies: ${removed}. Se añadirán estos: ${added}. Una línea cuyo nombre cambió cuenta como un proxy nuevo, y los perfiles personalizados que mencionen los eliminados los marcarán como ausentes. ¿Aplicar de todos modos?";

  static String m69(label) =>
      "${label} sigue mencionado por reglas, grupos de proxies, proxies de marcación, DNS o NTP de este perfil, que dejarán de funcionar si se elimina. ¿Seguro que quieres eliminarlo?";

  static String m70(count, label) =>
      "${Intl.plural(count, one: '1 grupo de proxies', other: '${label} grupos de proxies')}";

  static String m71(maximum) => "Introduce un entero entre 0 y ${maximum}.";

  static String m72(count, label) =>
      "${Intl.plural(count, one: '1 regla', other: '${label} reglas')}";

  static String m73(appName) => "${appName} (Modo seguro)";

  static String m74(count) =>
      "${Intl.plural(count, one: '1 segundo', other: '${count} segundos')}";

  static String m75(count) => "${count} en vigor";

  static String m76(count) =>
      "${Intl.plural(count, one: '1 problema', other: '${count} problemas')}";

  static String m77(time) => "Comprobado a las ${time}";

  static String m78(count) =>
      "${Intl.plural(count, one: '1 ajuste', other: '${count} ajustes')}";

  static String m79(link) => "No se pudo leer ningún proxy de ${link}";

  static String m80(label) => "${label} debe ser un solo elemento";

  static String m81(value) => "Pico: ${value}";

  static String m82(value) => "Total: ${value}";

  static String m83(interval, idleInterval) =>
      "${interval} · Inactividad ${idleInterval}";

  static String m84(interval) =>
      "${interval} · Reducción en inactividad desactivada";

  static String m85(label) => "${label} debe ser una URL";

  static String m86(count) =>
      "${Intl.plural(count, one: 'hace 1 año', other: 'hace ${count} años')}";

  static String m87(count) => "${Intl.plural(count, other: 'hace ${count} a')}";

  static String m88(amount, cycle) => "${amount} por ${cycle}, pago único";

  static String m89(date) =>
      "Caduca el ${date}. Mejora o renueva tu plan desde aquí.";

  static String m90(plan) => "Plan actual · ${plan}";

  static String m91(days) => "Quedan ${days} días";

  static String m92(date) => "Caduca el ${date}";

  static String m93(count) => "Hasta ${count} dispositivos en línea a la vez";

  static String m94(mbps) => "Velocidad de hasta ${mbps} Mbps";

  static String m95(gb) => "${gb} GB de datos de alta velocidad al mes";

  static String m96(name) => "Hola, ${name}.";

  static String m97(count) => "/ ${count}";

  static String m98(days) => "Se restablece en ${days} días";

  static String m99(percent) => "Ahorra un ${percent} %";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("Acerca de"),
    "accessControl": MessageLookupByLibrary.simpleMessage("Control de acceso"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Solo las apps seleccionadas usan la VPN",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "El control de acceso elige qué apps usan el proxy.",
    ),
    "accessControlDisabledDesc": MessageLookupByLibrary.simpleMessage(
      "El control de acceso de apps está desactivado",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Las apps seleccionadas quedan excluidas de la VPN",
    ),
    "accessControlSettings": MessageLookupByLibrary.simpleMessage(
      "Ajustes de control de acceso",
    ),
    "accessDenied": MessageLookupByLibrary.simpleMessage("Acceso denegado"),
    "account": MessageLookupByLibrary.simpleMessage("Cuenta"),
    "action": MessageLookupByLibrary.simpleMessage("Acción"),
    "actionDelayTest": MessageLookupByLibrary.simpleMessage(
      "Probar la latencia de todos",
    ),
    "actionDirectMode": MessageLookupByLibrary.simpleMessage("Modo directo"),
    "actionGlobalMode": MessageLookupByLibrary.simpleMessage("Modo global"),
    "actionMode": MessageLookupByLibrary.simpleMessage("Cambiar modo"),
    "actionProxy": MessageLookupByLibrary.simpleMessage("Proxy del sistema"),
    "actionRuleMode": MessageLookupByLibrary.simpleMessage("Modo regla"),
    "actionStart": MessageLookupByLibrary.simpleMessage("Iniciar/Detener"),
    "actionTun": MessageLookupByLibrary.simpleMessage("TUN"),
    "actionUpdateProfiles": MessageLookupByLibrary.simpleMessage(
      "Actualizar perfiles",
    ),
    "actionView": MessageLookupByLibrary.simpleMessage("Mostrar/Ocultar"),
    "add": MessageLookupByLibrary.simpleMessage("Añadir"),
    "addCustomProxy": MessageLookupByLibrary.simpleMessage("Añadir proxy"),
    "addFilters": MessageLookupByLibrary.simpleMessage("Añadir filtros"),
    "addNodes": MessageLookupByLibrary.simpleMessage("Añadir nodos"),
    "addOverrideEntry": MessageLookupByLibrary.simpleMessage(
      "Añadir entrada de sobrescritura",
    ),
    "addProfile": MessageLookupByLibrary.simpleMessage("Añadir perfil"),
    "addProxies": MessageLookupByLibrary.simpleMessage("Añadir proxies"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Añadir grupo de proxies",
    ),
    "addRule": MessageLookupByLibrary.simpleMessage("Añadir regla"),
    "addSettingEntry": MessageLookupByLibrary.simpleMessage("Añadir ajuste"),
    "addSsid": MessageLookupByLibrary.simpleMessage("Añadir SSID"),
    "addedRules": MessageLookupByLibrary.simpleMessage("Reglas añadidas"),
    "additionalParameters": MessageLookupByLibrary.simpleMessage(
      "Parámetros adicionales",
    ),
    "additionalPrefix": MessageLookupByLibrary.simpleMessage(
      "Prefijo del nombre",
    ),
    "additionalSuffix": MessageLookupByLibrary.simpleMessage(
      "Sufijo del nombre",
    ),
    "address": MessageLookupByLibrary.simpleMessage("Dirección"),
    "addressHelp": MessageLookupByLibrary.simpleMessage(
      "Dirección del servidor WebDAV",
    ),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "Introduce una dirección WebDAV válida",
    ),
    "advancedConfig": MessageLookupByLibrary.simpleMessage(
      "Configuración avanzada",
    ),
    "advancedConfigDesc": MessageLookupByLibrary.simpleMessage(
      "La configuración avanzada incluye la red, el DNS, las reglas añadidas y los scripts.",
    ),
    "ageEncryptedProfile": MessageLookupByLibrary.simpleMessage(
      "Perfil cifrado",
    ),
    "ageKeyGenerateTitle": MessageLookupByLibrary.simpleMessage(
      "Generación de claves Age",
    ),
    "ageKeyPairGeneratedSuccess": MessageLookupByLibrary.simpleMessage(
      "Se ha generado el par de claves X25519. Guárdalo en un lugar seguro",
    ),
    "agePrivateKeyLabel": MessageLookupByLibrary.simpleMessage(
      "Clave privada Age",
    ),
    "agePrivateKeyRequired": MessageLookupByLibrary.simpleMessage(
      "Introduce primero una clave privada Age correcta",
    ),
    "agePublicKeyLabel": MessageLookupByLibrary.simpleMessage(
      "Clave pública Age",
    ),
    "ageSecretKey": MessageLookupByLibrary.simpleMessage(
      "Clave secreta de age",
    ),
    "ageSecretKeyInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Introduce una clave secreta Age válida (debe empezar por AGE-SECRET-KEY-)",
    ),
    "ageSecretKeyOptional": MessageLookupByLibrary.simpleMessage(
      "Clave secreta Age (opcional)",
    ),
    "ageSecretKeyRequiredTip": MessageLookupByLibrary.simpleMessage(
      "Este perfil está cifrado con age y necesita una clave secreta de age para descifrarse",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("Aceptar"),
    "allData": MessageLookupByLibrary.simpleMessage("Todos los datos"),
    "allReferencedProxies": MessageLookupByLibrary.simpleMessage(
      "Todos los proxies referenciados",
    ),
    "allReferencedProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Todos los proveedores de proxies referenciados",
    ),
    "allowBypass": MessageLookupByLibrary.simpleMessage(
      "Permitir que las apps eludan la VPN",
    ),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "Permitir que algunas aplicaciones eviten la VPN",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("Permitir LAN"),
    "allowLanAccess": MessageLookupByLibrary.simpleMessage(
      "Permitir acceso desde la LAN",
    ),
    "allowLanAccessDesc": MessageLookupByLibrary.simpleMessage(
      "Permitir el acceso al controlador externo desde la LAN",
    ),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage(
      "Permitir el acceso al proxy desde la LAN",
    ),
    "allowedIps": MessageLookupByLibrary.simpleMessage("IP permitidas"),
    "alwaysOn": MessageLookupByLibrary.simpleMessage("Siempre activo"),
    "alwaysOnDesc": MessageLookupByLibrary.simpleMessage(
      "Mantener la VPN conectada en cualquier condición de red",
    ),
    "answers": MessageLookupByLibrary.simpleMessage("Respuestas"),
    "app": MessageLookupByLibrary.simpleMessage("App"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "Control de acceso de apps",
    ),
    "appIconDesign": MessageLookupByLibrary.simpleMessage(
      "Diseño del icono de la app",
    ),
    "appProxiesEmpty": MessageLookupByLibrary.simpleMessage(
      "No hay proxies locales",
    ),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage(
      "Añadir DNS del sistema",
    ),
    "appendSystemDnsTip": MessageLookupByLibrary.simpleMessage(
      "Añadir forzosamente el DNS del sistema a la configuración",
    ),
    "application": MessageLookupByLibrary.simpleMessage("Aplicación"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage(
      "Ajustar la configuración de la aplicación",
    ),
    "ascending": MessageLookupByLibrary.simpleMessage("Ascendente"),
    "authentication": MessageLookupByLibrary.simpleMessage("Autenticación"),
    "authenticationDesc": MessageLookupByLibrary.simpleMessage(
      "La autenticación pide usuario y contraseña en el puerto del proxy local.",
    ),
    "authenticationSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "El proxy del sistema no se aplica mientras la autenticación esté activada.",
    ),
    "authorize": MessageLookupByLibrary.simpleMessage("Autorizar"),
    "authorized": MessageLookupByLibrary.simpleMessage("Autorizado"),
    "auto": MessageLookupByLibrary.simpleMessage("Automático"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage(
      "Buscar actualizaciones automáticamente",
    ),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "Buscar actualizaciones automáticamente al iniciar la aplicación",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Cerrar conexiones automáticamente",
    ),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Cerrar conexiones automáticamente corta las conexiones abiertas al cambiar de proxy.",
    ),
    "autoInclude": MessageLookupByLibrary.simpleMessage(
      "Incluir automáticamente",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("Inicio automático"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Iniciar automáticamente al arrancar el sistema",
    ),
    "autoRun": MessageLookupByLibrary.simpleMessage("Ejecución automática"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "La ejecución automática inicia el proxy al abrir la app.",
    ),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage(
      "Configurar DNS del sistema automáticamente",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage(
      "Actualización automática",
    ),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Intervalo de actualización automática",
    ),
    "back": MessageLookupByLibrary.simpleMessage("Atrás"),
    "backToDashboard": MessageLookupByLibrary.simpleMessage("Volver al panel"),
    "backToDashboardDesc": MessageLookupByLibrary.simpleMessage(
      "Volver al panel antes de salir",
    ),
    "backup": MessageLookupByLibrary.simpleMessage("Copia de seguridad"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage(
      "Copia de seguridad y restauración",
    ),
    "backupDateDescription": MessageLookupByLibrary.simpleMessage(
      "Fecha local (AAAA-MM-DD)",
    ),
    "backupFromNewerVersion": MessageLookupByLibrary.simpleMessage(
      "Esta copia de seguridad procede de una versión más reciente de la app. Actualiza la app antes de restaurarla",
    ),
    "backupPlatformDescription": MessageLookupByLibrary.simpleMessage(
      "Plataforma actual",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage(
      "Copia de seguridad completada",
    ),
    "backupTimeDescription": MessageLookupByLibrary.simpleMessage(
      "Hora local (HHmmss)",
    ),
    "backupVersionDescription": MessageLookupByLibrary.simpleMessage(
      "Versión de la aplicación",
    ),
    "basicConfig": MessageLookupByLibrary.simpleMessage("Configuración básica"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage(
      "Modificar globalmente la configuración básica",
    ),
    "basicInfo": MessageLookupByLibrary.simpleMessage("Información básica"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage(
      "Estrategias básicas",
    ),
    "batchAdd": MessageLookupByLibrary.simpleMessage("Añadir en lote"),
    "batchImport": MessageLookupByLibrary.simpleMessage("Importar en lote"),
    "batchLinkInputTip": MessageLookupByLibrary.simpleMessage(
      "Un enlace por línea",
    ),
    "batchListInputTip": MessageLookupByLibrary.simpleMessage(
      "Un elemento por línea, o separados por comas",
    ),
    "batchMapInputTip": MessageLookupByLibrary.simpleMessage(
      "Una entrada por línea: clave, un espacio y el valor",
    ),
    "batchPreviewTip": m0,
    "batchUrlInputTip": MessageLookupByLibrary.simpleMessage(
      "Una URL por línea",
    ),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "Ignorar la optimización de batería mantiene la app en ejecución en segundo plano.",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("Vincular"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("Modo lista negra"),
    "blockConnection": MessageLookupByLibrary.simpleMessage(
      "Bloquear conexión",
    ),
    "brightness": MessageLookupByLibrary.simpleMessage("Brillo"),
    "browse": MessageLookupByLibrary.simpleMessage("Explorar"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("Dominios excluidos"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Los dominios excluidos solo se aplican mientras el proxy del sistema esté activado.",
    ),
    "bypassPrivateRoute": MessageLookupByLibrary.simpleMessage(
      "Omitir direcciones privadas",
    ),
    "bypassPrivateRouteDesc": MessageLookupByLibrary.simpleMessage(
      "Con Omitir direcciones privadas activado, las direcciones de LAN, loopback y multidifusión no pasan por TUN.",
    ),
    "cache": MessageLookupByLibrary.simpleMessage("Caché"),
    "cacheAlgorithm": MessageLookupByLibrary.simpleMessage(
      "Algoritmo de caché",
    ),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "La caché está dañada. ¿Borrarla?",
    ),
    "cacheMaxSize": MessageLookupByLibrary.simpleMessage("Tamaño de caché"),
    "cameraPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Permite el acceso a la cámara en los ajustes del sistema para escanear códigos QR, o elige una imagen de código QR del álbum.",
    ),
    "cameraPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Se requiere permiso de cámara",
    ),
    "cameraUnavailable": MessageLookupByLibrary.simpleMessage(
      "Cámara no disponible",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancelar"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage(
      "Deseleccionar todo",
    ),
    "cannotSave": MessageLookupByLibrary.simpleMessage("No se puede guardar"),
    "captureDns": MessageLookupByLibrary.simpleMessage(
      "Capturar el DNS del sistema",
    ),
    "captureDnsDesc": MessageLookupByLibrary.simpleMessage(
      "Redirigir todas las consultas DNS del sistema al módulo DNS interno",
    ),
    "changeProxyFailedTip": MessageLookupByLibrary.simpleMessage(
      "No se pudo cambiar de proxy; se ha restaurado la selección anterior",
    ),
    "changelogBreaking": MessageLookupByLibrary.simpleMessage(
      "Cambios incompatibles",
    ),
    "changelogFeatures": MessageLookupByLibrary.simpleMessage("Novedades"),
    "changelogFixes": MessageLookupByLibrary.simpleMessage("Correcciones"),
    "changelogPerformance": MessageLookupByLibrary.simpleMessage("Rendimiento"),
    "changelogReverts": MessageLookupByLibrary.simpleMessage("Reversiones"),
    "checkCertificate": MessageLookupByLibrary.simpleMessage(
      "Verificar certificados TLS",
    ),
    "checkCertificateDesc": MessageLookupByLibrary.simpleMessage(
      "Con la verificación TLS desactivada, las suscripciones y las copias de seguridad quedan expuestas a ataques de intermediario.",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage(
      "Buscar actualizaciones",
    ),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "La app ya está actualizada",
    ),
    "cipher": MessageLookupByLibrary.simpleMessage("Cifrado"),
    "clear": MessageLookupByLibrary.simpleMessage("Borrar"),
    "clearData": MessageLookupByLibrary.simpleMessage("Borrar datos"),
    "clearDataAndExitTip": MessageLookupByLibrary.simpleMessage(
      "Esto elimina todos los perfiles, ajustes y datos locales, y luego cierra la app. Ábrela de nuevo para empezar de cero.",
    ),
    "clearDataFailed": m1,
    "clearSearch": MessageLookupByLibrary.simpleMessage("Borrar búsqueda"),
    "clientFingerprint": MessageLookupByLibrary.simpleMessage(
      "Huella del cliente",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage(
      "Exportar al portapapeles",
    ),
    "clipboardImport": MessageLookupByLibrary.simpleMessage(
      "Importar desde el portapapeles",
    ),
    "clipboardWriteFailed": MessageLookupByLibrary.simpleMessage(
      "No se pudo copiar al portapapeles. Puede que la selección sea demasiado grande",
    ),
    "close": MessageLookupByLibrary.simpleMessage("Cerrar"),
    "closeAll": MessageLookupByLibrary.simpleMessage("Cerrar todo"),
    "closeConnections": MessageLookupByLibrary.simpleMessage(
      "Cerrar conexiones",
    ),
    "closeConnectionsPrompt": MessageLookupByLibrary.simpleMessage(
      "¿Cerrar las conexiones que usan el proxy anterior?",
    ),
    "collapse": MessageLookupByLibrary.simpleMessage("Contraer"),
    "collapseProxyChains": MessageLookupByLibrary.simpleMessage(
      "Contraer cadenas de proxies",
    ),
    "collapseProxyChainsDesc": MessageLookupByLibrary.simpleMessage(
      "Ocultar los nodos intermedios cuando una cadena de proxies tenga más de tres nodos",
    ),
    "collapseQuickSettingsPanel": MessageLookupByLibrary.simpleMessage(
      "Contraer el panel de ajustes rápidos",
    ),
    "collapseQuickSettingsPanelDesc": MessageLookupByLibrary.simpleMessage(
      "Contraer después de tocar el mosaico",
    ),
    "color": MessageLookupByLibrary.simpleMessage("Color"),
    "colorStyle": MessageLookupByLibrary.simpleMessage("Estilo de color"),
    "columns": MessageLookupByLibrary.simpleMessage("Columnas"),
    "compact": MessageLookupByLibrary.simpleMessage("Compacto"),
    "compatible": MessageLookupByLibrary.simpleMessage(
      "Modo de compatibilidad",
    ),
    "configDataDetected": MessageLookupByLibrary.simpleMessage(
      "Se detectaron datos en la configuración",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("Confirmar"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage(
      "¿Seguro que quieres borrar todos los datos?",
    ),
    "confirmClearSelectedData": MessageLookupByLibrary.simpleMessage(
      "¿Seguro que quieres borrar los datos seleccionados?",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "¿Seguro que quieres eliminar este grupo de proxies?",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage(
      "¿Seguro que quieres salir de la ventana actual?",
    ),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "¿Seguro que quieres forzar el fallo del núcleo?",
    ),
    "confirmOverwriteTip": MessageLookupByLibrary.simpleMessage(
      "Al confirmar se sobrescribirán los datos existentes",
    ),
    "congestionControl": MessageLookupByLibrary.simpleMessage(
      "Control de congestión",
    ),
    "congestionController": MessageLookupByLibrary.simpleMessage(
      "Control de congestión TCP",
    ),
    "congestionControllerDesc": MessageLookupByLibrary.simpleMessage(
      "El control de congestión TCP solo funciona con la pila mips.",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("Conectado"),
    "connecting": MessageLookupByLibrary.simpleMessage("Conectando…"),
    "connection": MessageLookupByLibrary.simpleMessage("Conexión"),
    "connectionInfo": MessageLookupByLibrary.simpleMessage(
      "Número de conexiones",
    ),
    "connectionStats": MessageLookupByLibrary.simpleMessage(
      "Estadísticas de conexión",
    ),
    "connectionStatsDesc": MessageLookupByLibrary.simpleMessage(
      "Conexiones activas, solicitudes recientes y consultas DNS",
    ),
    "connections": MessageLookupByLibrary.simpleMessage("Conexiones"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Ver los datos de las conexiones actuales",
    ),
    "connectivity": MessageLookupByLibrary.simpleMessage("Conectividad: "),
    "content": MessageLookupByLibrary.simpleMessage("Contenido"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage(
      "El contenido no puede estar vacío",
    ),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage(
      "Controlar las reglas añadidas globales",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("Copiar"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage(
      "Copiar variables de entorno",
    ),
    "copyLink": MessageLookupByLibrary.simpleMessage("Copiar enlace"),
    "copySuccess": MessageLookupByLibrary.simpleMessage(
      "Copiado correctamente",
    ),
    "core": MessageLookupByLibrary.simpleMessage("Núcleo"),
    "coreBlockedByPolicyTip": m2,
    "coreBlockedBySmartAppControlTip": MessageLookupByLibrary.simpleMessage(
      "Smart App Control de Windows bloqueó FlClashCore.exe porque no está firmado. Abre Seguridad de Windows → Control de aplicaciones y navegador → Configuración de Smart App Control, elige Desactivado y vuelve a iniciar FlClash. Smart App Control no se puede volver a activar sin reinstalar Windows.",
    ),
    "coreStatus": MessageLookupByLibrary.simpleMessage("Estado del núcleo"),
    "country": MessageLookupByLibrary.simpleMessage("Región"),
    "crashDetected": MessageLookupByLibrary.simpleMessage("Fallo detectado"),
    "crashDetectedTip": m3,
    "crashTest": MessageLookupByLibrary.simpleMessage("Prueba de fallo"),
    "create": MessageLookupByLibrary.simpleMessage("Crear"),
    "createProfile": MessageLookupByLibrary.simpleMessage("Crear perfil"),
    "createProfileFromUrlTip": m4,
    "creationTime": MessageLookupByLibrary.simpleMessage("Fecha de creación"),
    "currentOutboundDesc": MessageLookupByLibrary.simpleMessage(
      "Contiene el botón de inicio y no se puede quitar",
    ),
    "custom": MessageLookupByLibrary.simpleMessage("Personalizado"),
    "customColor": MessageLookupByLibrary.simpleMessage("Color personalizado"),
    "customImportDroppedSubRules": m5,
    "customIssueCoreRejected": m6,
    "customIssueDialerLoop": m7,
    "customIssueDuplicateName": m8,
    "customIssueEmptyName": MessageLookupByLibrary.simpleMessage(
      "El nombre está vacío",
    ),
    "customIssueGroupLoop": m9,
    "customIssueInvalidEmptyFallback": m10,
    "customIssueInvalidFilter": m11,
    "customIssueMissingDialer": m12,
    "customIssueMissingProviders": m13,
    "customIssueMissingProxies": m14,
    "customIssueNoProxySource": MessageLookupByLibrary.simpleMessage(
      "No hay proxies ni proveedores de proxies seleccionados, por lo que el núcleo rechaza este grupo",
    ),
    "customIssueReservedName": m15,
    "customIssuesSummary": m16,
    "customProfile": MessageLookupByLibrary.simpleMessage("Personalizado"),
    "customProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Crea grupos de proxies y reglas a partir de los proxies de la app y de otros perfiles",
    ),
    "customProfileResources": MessageLookupByLibrary.simpleMessage(
      "Recursos de perfil personalizado",
    ),
    "customProfileResourcesDesc": MessageLookupByLibrary.simpleMessage(
      "Los recursos de perfil personalizado incluyen proxies, proveedores de reglas, filtros y conjuntos de iconos.",
    ),
    "cut": MessageLookupByLibrary.simpleMessage("Cortar"),
    "dark": MessageLookupByLibrary.simpleMessage("Oscuro"),
    "dashboard": MessageLookupByLibrary.simpleMessage("Panel"),
    "dashboardAddableSection": MessageLookupByLibrary.simpleMessage(
      "Disponibles para añadir",
    ),
    "dataChangedSave": MessageLookupByLibrary.simpleMessage(
      "Se detectaron cambios en los datos. ¿Guardarlos?",
    ),
    "databaseWriteFailedTip": MessageLookupByLibrary.simpleMessage(
      "No se pudo guardar el cambio; se ha revertido",
    ),
    "davDirectory": MessageLookupByLibrary.simpleMessage("Directorio"),
    "daysAgo": m17,
    "daysAgoShort": m18,
    "defaultNameserver": MessageLookupByLibrary.simpleMessage(
      "Servidor DNS predeterminado",
    ),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Se usa para resolver los servidores DNS",
    ),
    "defaultSelected": MessageLookupByLibrary.simpleMessage(
      "Selección predeterminada",
    ),
    "defaultText": MessageLookupByLibrary.simpleMessage("Predeterminado"),
    "definitionNotMap": MessageLookupByLibrary.simpleMessage(
      "La configuración debe ser un mapa YAML con un nombre y un tipo",
    ),
    "delay": MessageLookupByLibrary.simpleMessage("Latencia"),
    "delayFailed": MessageLookupByLibrary.simpleMessage("Fallido"),
    "delayTest": MessageLookupByLibrary.simpleMessage("Prueba de latencia"),
    "delete": MessageLookupByLibrary.simpleMessage("Eliminar"),
    "deleteMultipTip": m19,
    "deleteTip": m20,
    "desc": MessageLookupByLibrary.simpleMessage(
      "Un cliente proxy multiplataforma basado en ClashMeta, sencillo de usar, de código abierto y sin anuncios.",
    ),
    "descending": MessageLookupByLibrary.simpleMessage("Descendente"),
    "destination": MessageLookupByLibrary.simpleMessage("Destino"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage(
      "GeoIP de destino",
    ),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage(
      "ASN de la IP de destino",
    ),
    "details": m21,
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "Depende de una API de terceros; solo con fines informativos",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("Modo desarrollador"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "El modo desarrollador está activado.",
    ),
    "dialerProxy": MessageLookupByLibrary.simpleMessage("Proxy de marcación"),
    "dialerProxyDesc": MessageLookupByLibrary.simpleMessage(
      "El proxy de marcación es la salida que se usa para llegar al servidor NTP.",
    ),
    "dialerProxyLoopStopped": m22,
    "direct": MessageLookupByLibrary.simpleMessage("Directo"),
    "disableIcmpForwarding": MessageLookupByLibrary.simpleMessage(
      "Desactivar reenvío ICMP",
    ),
    "disableIcmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "Con el reenvío ICMP desactivado, TUN responde él mismo al ping, por lo que ping ya no muestra la latencia real.",
    ),
    "disableKeepAlive": MessageLookupByLibrary.simpleMessage(
      "Desactivar keep-alive TCP",
    ),
    "disableUDP": MessageLookupByLibrary.simpleMessage("Desactivar UDP"),
    "disabled": MessageLookupByLibrary.simpleMessage("Desactivado"),
    "discardChanges": MessageLookupByLibrary.simpleMessage(
      "¿Descartar los cambios?",
    ),
    "disclaimer": MessageLookupByLibrary.simpleMessage("Aviso legal"),
    "disclaimerAcceptContent": MessageLookupByLibrary.simpleMessage(
      "Al instalar, copiar o usar el Software, se considera que has leído y aceptado esta declaración en su totalidad. Si no estás de acuerdo con alguno de sus términos, deja de usar el Software y desinstálalo de inmediato.",
    ),
    "disclaimerAcceptTitle": MessageLookupByLibrary.simpleMessage("Aceptación"),
    "disclaimerAcknowledgeLabel": MessageLookupByLibrary.simpleMessage(
      "He leído y entiendo esta declaración",
    ),
    "disclaimerAcknowledgeTip": MessageLookupByLibrary.simpleMessage(
      "Para confirmar que lo entiendes, lee la siguiente declaración y marca la casilla de abajo:",
    ),
    "disclaimerAcknowledgeTitle": MessageLookupByLibrary.simpleMessage(
      "Confirma la declaración",
    ),
    "disclaimerChangesContent": MessageLookupByLibrary.simpleMessage(
      "Los desarrolladores pueden revisar esta declaración con cualquier versión, y la revisión entra en vigor cuando se publique dicha versión. Seguir usando el Software después de actualizar implica que aceptas la declaración revisada.",
    ),
    "disclaimerChangesTitle": MessageLookupByLibrary.simpleMessage(
      "Cambios en esta declaración",
    ),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "Antes de usar FlClash (“el Software”), lee con atención esta declaración y asegúrate de entenderla por completo. Pulsar “Aceptar” significa que has leído, comprendido y aceptado todos los términos siguientes. Si no estás de acuerdo, pulsa “Salir” y deja de usar el Software.",
    ),
    "disclaimerLiabilityContent": MessageLookupByLibrary.simpleMessage(
      "En la máxima medida permitida por la ley aplicable, ni los desarrolladores ni ningún colaborador serán responsables de ningún daño directo, indirecto, incidental, especial, punitivo o emergente derivado del uso o de la imposibilidad de usar el Software, incluidos, entre otros, la pérdida de datos, los daños al dispositivo, los fallos de red, la interrupción de la actividad, el lucro cesante o cualquier disputa legal resultante, incluso si se les hubiera advertido de la posibilidad de tales daños.",
    ),
    "disclaimerLiabilityTitle": MessageLookupByLibrary.simpleMessage(
      "Limitación de responsabilidad",
    ),
    "disclaimerLicenseContent": MessageLookupByLibrary.simpleMessage(
      "El Software es de código abierto bajo la licencia GPL-3.0. Puedes usarlo, modificarlo y distribuirlo libremente siempre que cumplas dicha licencia, que exige que las obras derivadas se publiquen también bajo GPL-3.0 y que se conserven los avisos de derechos de autor originales.\n\nLos componentes de terceros del Software, incluido el núcleo Clash.Meta, siguen sus propias licencias. Los autores originales no se hacen responsables de ningún problema derivado de versiones modificadas o redistribuidas.",
    ),
    "disclaimerLicenseTitle": MessageLookupByLibrary.simpleMessage(
      "Licencia de código abierto",
    ),
    "disclaimerNoServiceStatement": MessageLookupByLibrary.simpleMessage(
      "El Software en sí no proporciona ningún servidor proxy, nodo, suscripción ni servicio de acceso a la red, y no mantiene ninguna relación de asociación, representación ni garantía con ningún proveedor de dichos servicios.",
    ),
    "disclaimerPrivacyContent": MessageLookupByLibrary.simpleMessage(
      "El Software no recopila ni sube tus URL de suscripción, los detalles de los nodos, el contenido de las configuraciones, los sitios web visitados, los registros de conexión, el contenido del tráfico ni los registros. Estos datos permanecen en tu dispositivo y los desarrolladores no tienen acceso a ellos.\n\nEl Software solo accede a la red cuando usas una función que lo necesita, como obtener la URL de suscripción que indicaste al actualizar un perfil o conectarse a GitHub al buscar actualizaciones.\n\nEl Software no incluye ningún servicio de analítica ni de informes de fallos en ninguna plataforma.",
    ),
    "disclaimerPrivacyTitle": MessageLookupByLibrary.simpleMessage(
      "Recopilación de datos y privacidad",
    ),
    "disclaimerResponsibilityContent": MessageLookupByLibrary.simpleMessage(
      "Eres responsable de asegurarte de que el uso del Software sea legal donde vives, y asumes tú solo la responsabilidad legal de todo lo que hagas con él y de sus consecuencias.\n\nLas suscripciones, los nodos y las configuraciones que importas son decisión tuya. Que su origen sea legal, su contenido seguro y su servicio fiable es un asunto entre tú y sus proveedores.",
    ),
    "disclaimerResponsibilityTitle": MessageLookupByLibrary.simpleMessage(
      "Tu responsabilidad",
    ),
    "disclaimerRestateHint": MessageLookupByLibrary.simpleMessage(
      "Escribe la declaración anterior",
    ),
    "disclaimerRestateMismatch": MessageLookupByLibrary.simpleMessage(
      "No coincide con la declaración",
    ),
    "disclaimerRestateTip": MessageLookupByLibrary.simpleMessage(
      "Para confirmar que lo entiendes, escribe la siguiente declaración completa en el campo de abajo:",
    ),
    "disclaimerRestateTitle": MessageLookupByLibrary.simpleMessage(
      "Repite la declaración",
    ),
    "disclaimerSoftwareContent": MessageLookupByLibrary.simpleMessage(
      "El Software es un cliente proxy de red de código abierto basado en el núcleo Clash.Meta (mihomo). Solo ofrece herramientas locales como la gestión de configuración, el enrutamiento basado en reglas y el reenvío de tráfico.",
    ),
    "disclaimerSoftwareTitle": MessageLookupByLibrary.simpleMessage(
      "Naturaleza del software",
    ),
    "disclaimerThirdPartyContent": MessageLookupByLibrary.simpleMessage(
      "Los enlaces de suscripción, los archivos de configuración, los conjuntos de reglas, los scripts, los recursos externos y los enlaces externos los proporcionan terceros. Los desarrolladores no pueden revisar ni garantizar, ni lo hacen, su legalidad, exactitud, seguridad o disponibilidad.\n\nCualquier fuga de datos, pérdida económica, bloqueo de cuenta u otra pérdida causada por contenido de terceros debe resolverse entre tú y el tercero; los desarrolladores no asumen ninguna responsabilidad por ello.",
    ),
    "disclaimerThirdPartyTitle": MessageLookupByLibrary.simpleMessage(
      "Contenido de terceros",
    ),
    "disclaimerUsageContent": MessageLookupByLibrary.simpleMessage(
      "El Software está destinado únicamente a usos no comerciales, como el aprendizaje, el intercambio y la investigación técnica. Queda estrictamente prohibido usarlo con cualquier fin comercial, incluidos, entre otros, la distribución de pago, la venta en paquete, su uso como parte de un servicio comercial o hacer negocio en nombre del Software. Cualquier actividad comercial no guarda relación con el Software ni con sus desarrolladores.\n\nQueda estrictamente prohibido usar el Software para cualquier fin que infrinja las leyes y normativas de tu país o región, incluidos, entre otros, eludir restricciones de acceso a la red impuestas legalmente, difundir contenido ilegal, lanzar ataques a la red o vulnerar los derechos legítimos de otras personas.",
    ),
    "disclaimerUsageTitle": MessageLookupByLibrary.simpleMessage(
      "Restricciones de uso",
    ),
    "disclaimerWarrantyContent": MessageLookupByLibrary.simpleMessage(
      "El Software se proporciona “tal cual” y “según disponibilidad”, sin garantía de ningún tipo, expresa o implícita, incluidas, entre otras, las garantías de comerciabilidad, idoneidad para un fin concreto, no infracción, disponibilidad ininterrumpida, ausencia de errores o ausencia de vulnerabilidades de seguridad.\n\nLos desarrolladores no garantizan que el Software satisfaga tus necesidades ni que funcione sin interrupciones ni errores.",
    ),
    "disclaimerWarrantyTitle": MessageLookupByLibrary.simpleMessage(
      "Sin garantía",
    ),
    "disconnected": MessageLookupByLibrary.simpleMessage("Desconectado"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "Nueva versión disponible",
    ),
    "dnsDesc": MessageLookupByLibrary.simpleMessage(
      "Actualizar la configuración de DNS",
    ),
    "dnsHijack": MessageLookupByLibrary.simpleMessage("Intercepción DNS"),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "Sin esta entrada, TUN secuestra todas las consultas DNS al puerto 53 (any:53).",
    ),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("Secuestro de DNS"),
    "dnsIPv6Desc": MessageLookupByLibrary.simpleMessage(
      "Al desactivarlo, las consultas AAAA devuelven un resultado vacío",
    ),
    "dnsMode": MessageLookupByLibrary.simpleMessage("Modo DNS"),
    "dnsOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Las entradas añadidas aquí sustituyen el DNS de todos los perfiles de URL y de archivo; lo que no añadas conserva el ajuste del propio perfil. Los perfiles personalizados definen su DNS en su contenido.",
    ),
    "dnsQueries": MessageLookupByLibrary.simpleMessage("Consultas DNS"),
    "dnsQueriesDesc": MessageLookupByLibrary.simpleMessage(
      "Registros de resolución DNS del núcleo",
    ),
    "docked": MessageLookupByLibrary.simpleMessage("Fija"),
    "domain": MessageLookupByLibrary.simpleMessage("Dominio"),
    "done": MessageLookupByLibrary.simpleMessage("Hecho"),
    "download": MessageLookupByLibrary.simpleMessage("Descarga"),
    "downloadBandwidth": MessageLookupByLibrary.simpleMessage(
      "Ancho de banda de descarga",
    ),
    "downloadSpeed": MessageLookupByLibrary.simpleMessage(
      "Velocidad de bajada",
    ),
    "downloadTraffic": MessageLookupByLibrary.simpleMessage(
      "Tráfico de bajada",
    ),
    "duration": MessageLookupByLibrary.simpleMessage("Duración"),
    "easyTierConnectionLatency": MessageLookupByLibrary.simpleMessage(
      "Latencia de conexión",
    ),
    "easyTierDnsZone": MessageLookupByLibrary.simpleMessage("Zona DNS"),
    "easyTierFeatureFlags": MessageLookupByLibrary.simpleMessage(
      "Indicadores de funciones",
    ),
    "easyTierInstanceId": MessageLookupByLibrary.simpleMessage(
      "ID de instancia",
    ),
    "easyTierLatencyFirstPathLatency": MessageLookupByLibrary.simpleMessage(
      "Latencia de ruta (prioridad a la latencia)",
    ),
    "easyTierListeners": MessageLookupByLibrary.simpleMessage(
      "Puntos de escucha",
    ),
    "easyTierLocalEndpoint": MessageLookupByLibrary.simpleMessage(
      "Punto de conexión local",
    ),
    "easyTierLossRate": MessageLookupByLibrary.simpleMessage(
      "Pérdida de paquetes",
    ),
    "easyTierMinDirectLatency": MessageLookupByLibrary.simpleMessage(
      "Latencia directa mínima",
    ),
    "easyTierNextHop": MessageLookupByLibrary.simpleMessage(
      "ID del par del siguiente salto",
    ),
    "easyTierPathLatency": MessageLookupByLibrary.simpleMessage(
      "Latencia de ruta (prioridad al número de saltos)",
    ),
    "easyTierPeerId": MessageLookupByLibrary.simpleMessage("ID del par"),
    "easyTierProtocol": MessageLookupByLibrary.simpleMessage(
      "Protocolo de transporte",
    ),
    "easyTierPublicServer": MessageLookupByLibrary.simpleMessage(
      "Servidor público",
    ),
    "easyTierRemoteEndpoint": MessageLookupByLibrary.simpleMessage(
      "Punto de conexión remoto",
    ),
    "easyTierRouteCost": MessageLookupByLibrary.simpleMessage("Coste de ruta"),
    "easyTierRxPackets": MessageLookupByLibrary.simpleMessage(
      "Paquetes recibidos",
    ),
    "easyTierTxPackets": MessageLookupByLibrary.simpleMessage(
      "Paquetes enviados",
    ),
    "edit": MessageLookupByLibrary.simpleMessage("Editar"),
    "editDashboard": MessageLookupByLibrary.simpleMessage("Editar panel"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage(
      "Editar reglas globales",
    ),
    "editProxy": MessageLookupByLibrary.simpleMessage("Editar proxy"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Editar grupo de proxies",
    ),
    "editRule": MessageLookupByLibrary.simpleMessage("Editar regla"),
    "editSsid": MessageLookupByLibrary.simpleMessage("Editar SSID"),
    "editorUnavailable": MessageLookupByLibrary.simpleMessage(
      "Editor no disponible",
    ),
    "elapsed": MessageLookupByLibrary.simpleMessage("Tardó"),
    "emptyFallback": MessageLookupByLibrary.simpleMessage(
      "Respaldo si está vacío",
    ),
    "emptyTip": m23,
    "en": MessageLookupByLibrary.simpleMessage("Inglés"),
    "enableExternalController": MessageLookupByLibrary.simpleMessage(
      "Activar controlador externo",
    ),
    "enabled": MessageLookupByLibrary.simpleMessage("Activado"),
    "endpointIndependentNat": MessageLookupByLibrary.simpleMessage(
      "Mejora de NAT",
    ),
    "endpointIndependentNatDesc": MessageLookupByLibrary.simpleMessage(
      "Optimizar la conectividad de las aplicaciones UDP y P2P",
    ),
    "endpoints": MessageLookupByLibrary.simpleMessage("Puntos de conexión"),
    "enforceRoutes": MessageLookupByLibrary.simpleMessage("Forzar rutas"),
    "enforceRoutesDesc": MessageLookupByLibrary.simpleMessage(
      "Asegurar que el tráfico pase por el túnel aunque existan rutas más específicas",
    ),
    "entries": MessageLookupByLibrary.simpleMessage(" entradas"),
    "entriesCount": m24,
    "error": MessageLookupByLibrary.simpleMessage("Error"),
    "errorDetails": MessageLookupByLibrary.simpleMessage("Detalles del error"),
    "es": MessageLookupByLibrary.simpleMessage("Español"),
    "exclude": MessageLookupByLibrary.simpleMessage(
      "Ocultar de aplicaciones recientes",
    ),
    "excludeAPNs": MessageLookupByLibrary.simpleMessage("Excluir APNs"),
    "excludeAPNsDesc": MessageLookupByLibrary.simpleMessage(
      "Permitir que las notificaciones push de Apple eviten el túnel",
    ),
    "excludeCellularServices": MessageLookupByLibrary.simpleMessage(
      "Excluir servicios móviles",
    ),
    "excludeCellularServicesDesc": MessageLookupByLibrary.simpleMessage(
      "Permitir que servicios móviles como las llamadas Wi-Fi eviten el túnel",
    ),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "Ocultar la aplicación de las tareas recientes mientras está en segundo plano",
    ),
    "excludeDeviceCommunication": MessageLookupByLibrary.simpleMessage(
      "Excluir comunicación entre dispositivos",
    ),
    "excludeDeviceCommunicationDesc": MessageLookupByLibrary.simpleMessage(
      "Permitir que el tráfico entre dispositivos, como AirDrop y AirPlay, evite el túnel",
    ),
    "excludeDstPort": MessageLookupByLibrary.simpleMessage(
      "Puertos de destino excluidos",
    ),
    "excludeDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "El tráfico hacia los puertos de destino excluidos no pasa por TUN.",
    ),
    "excludeFilter": MessageLookupByLibrary.simpleMessage(
      "Filtro de exclusión",
    ),
    "excludeInterface": MessageLookupByLibrary.simpleMessage(
      "Interfaces excluidas",
    ),
    "excludeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "El tráfico que llega por las interfaces excluidas, como docker0, no pasa por TUN.",
    ),
    "excludeLocalNetworks": MessageLookupByLibrary.simpleMessage(
      "Excluir redes locales",
    ),
    "excludeLocalNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "Permitir el acceso directo a dispositivos de la red local",
    ),
    "excludeProxyFilter": MessageLookupByLibrary.simpleMessage(
      "Filtro de exclusión de proxies",
    ),
    "excludeSrcPort": MessageLookupByLibrary.simpleMessage(
      "Puertos de origen excluidos",
    ),
    "excludeSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "El tráfico desde los puertos de origen excluidos no pasa por TUN.",
    ),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("Excluir SSID"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "Al conectarte a una red Wi-Fi con un SSID excluido, el estado de ejecución de la app cambia automáticamente.",
    ),
    "excludeType": MessageLookupByLibrary.simpleMessage("Tipo de exclusión"),
    "excludeUid": MessageLookupByLibrary.simpleMessage(
      "ID de usuario excluidos",
    ),
    "excludeUidDesc": MessageLookupByLibrary.simpleMessage(
      "El tráfico de los procesos de los ID de usuario excluidos no pasa por TUN.",
    ),
    "existsTip": m25,
    "exit": MessageLookupByLibrary.simpleMessage("Salir"),
    "exitFullScreen": MessageLookupByLibrary.simpleMessage(
      "Salir de pantalla completa",
    ),
    "exitNodes": MessageLookupByLibrary.simpleMessage("Nodos de salida"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("Estado esperado"),
    "expireTime": MessageLookupByLibrary.simpleMessage("Fecha de vencimiento"),
    "exportFile": MessageLookupByLibrary.simpleMessage("Exportar archivo"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("Exportar registros"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage(
      "Exportación completada",
    ),
    "extend": MessageLookupByLibrary.simpleMessage("Extensión"),
    "extendMode": MessageLookupByLibrary.simpleMessage("Modo de extensión"),
    "extendScript": MessageLookupByLibrary.simpleMessage("Script de extensión"),
    "externalController": MessageLookupByLibrary.simpleMessage(
      "Controlador externo",
    ),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "El controlador externo permite controlar el núcleo en el puerto 9090.",
    ),
    "externalControllerSecret": MessageLookupByLibrary.simpleMessage(
      "Clave del controlador externo",
    ),
    "externalFetch": MessageLookupByLibrary.simpleMessage("Obtención externa"),
    "externalLink": MessageLookupByLibrary.simpleMessage("Enlace externo"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("Muy grande"),
    "fade": MessageLookupByLibrary.simpleMessage("Fundido"),
    "failedCount": m26,
    "failedItem": m27,
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Filtro Fake-IP"),
    "fakeipFilterDesc": MessageLookupByLibrary.simpleMessage(
      "Los dominios coincidentes reciben direcciones IP reales en lugar de direcciones Fake IP en este modo",
    ),
    "fakeipFilterMode": MessageLookupByLibrary.simpleMessage(
      "Modo de filtro Fake-IP",
    ),
    "fakeipFilterModeDesc": MessageLookupByLibrary.simpleMessage(
      "En el modo de filtro Fake-IP, la lista negra excluye las coincidencias, la lista blanca aplica Fake-IP solo a las coincidencias y rule coincide según las reglas.",
    ),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Rango Fake-IP"),
    "fakeipRange6": MessageLookupByLibrary.simpleMessage(
      "Rango Fake-IP (IPv6)",
    ),
    "fakeipTtl": MessageLookupByLibrary.simpleMessage("TTL de Fake-IP"),
    "fallback": MessageLookupByLibrary.simpleMessage("Alternativa"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Normalmente un DNS en el extranjero",
    ),
    "fallbackDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Los dominios coincidentes usan directamente la alternativa sin consultar el servidor DNS",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage(
      "Filtro de respaldo",
    ),
    "fallbackGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Comprobar el código GeoIP de los resultados del servidor DNS; usar la alternativa fuera de esa región",
    ),
    "fallbackGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Los dominios de estas categorías GeoSite usan directamente la alternativa",
    ),
    "fallbackIpcidrDesc": MessageLookupByLibrary.simpleMessage(
      "Sustituir por los de la alternativa los resultados del servidor DNS que coincidan con estos prefijos CIDR",
    ),
    "features": MessageLookupByLibrary.simpleMessage("Funciones"),
    "file": MessageLookupByLibrary.simpleMessage("Archivo"),
    "fileDesc": MessageLookupByLibrary.simpleMessage(
      "Sube un archivo de perfil directamente",
    ),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "El archivo se ha modificado. ¿Guardar los cambios?",
    ),
    "fileName": MessageLookupByLibrary.simpleMessage("Nombre del archivo"),
    "filter": MessageLookupByLibrary.simpleMessage("Filtro"),
    "filters": MessageLookupByLibrary.simpleMessage("Filtros"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("Buscar proceso"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "Activarlo reduce ligeramente el rendimiento",
    ),
    "floating": MessageLookupByLibrary.simpleMessage("Flotante"),
    "followProfile": MessageLookupByLibrary.simpleMessage("Seguir perfil"),
    "followSystem": MessageLookupByLibrary.simpleMessage("Seguir el sistema"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("Familia de fuente"),
    "fontSize": MessageLookupByLibrary.simpleMessage("Tamaño"),
    "forceDnsMapping": MessageLookupByLibrary.simpleMessage("Forzar mapeo DNS"),
    "forceDnsMappingDesc": MessageLookupByLibrary.simpleMessage(
      "Forzar mapeo DNS también analiza las conexiones cuyo dominio provino de un mapeo DNS.",
    ),
    "forceDomain": MessageLookupByLibrary.simpleMessage("Forzar dominios"),
    "forceDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Los dominios forzados también se analizan; las demás conexiones que ya tienen dominio se dejan como están.",
    ),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "¿Seguro que quieres forzar el reinicio del núcleo?",
    ),
    "fr": MessageLookupByLibrary.simpleMessage("Francés"),
    "general": MessageLookupByLibrary.simpleMessage("General"),
    "generalDesc": MessageLookupByLibrary.simpleMessage(
      "Configuración general de la aplicación y del núcleo",
    ),
    "generateFromPrivateKey": MessageLookupByLibrary.simpleMessage(
      "Generar desde una clave privada Age",
    ),
    "generateSecret": MessageLookupByLibrary.simpleMessage("Generar"),
    "geoAutoUpdate": MessageLookupByLibrary.simpleMessage(
      "Actualización automática",
    ),
    "geoAutoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Intervalo de actualización automática",
    ),
    "geoAutoUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "El intervalo de actualización automática debe ser mayor que 0",
    ),
    "geoOptions": MessageLookupByLibrary.simpleMessage("Opciones Geo"),
    "geoResources": MessageLookupByLibrary.simpleMessage("Geo"),
    "geoSkipped": m28,
    "geoUpdated": m29,
    "geoUpdating": m30,
    "geodataLoader": MessageLookupByLibrary.simpleMessage(
      "Modo geo de poca memoria",
    ),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "Usar el cargador Geo de bajo consumo de memoria",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("Código GeoIP"),
    "geositeMatcher": MessageLookupByLibrary.simpleMessage(
      "Motor Geo de alto rendimiento",
    ),
    "geositeMatcherDesc": MessageLookupByLibrary.simpleMessage(
      "Usar el algoritmo de hash perfecto mínimo para las coincidencias",
    ),
    "global": MessageLookupByLibrary.simpleMessage("Global"),
    "go": MessageLookupByLibrary.simpleMessage("Ir"),
    "goDownload": MessageLookupByLibrary.simpleMessage("Descargar"),
    "goToConfigureAddedRules": MessageLookupByLibrary.simpleMessage(
      "Ir a la configuración de las reglas añadidas",
    ),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage(
      "Ir a la configuración del script",
    ),
    "goroutineInfo": MessageLookupByLibrary.simpleMessage("Goroutines"),
    "grid": MessageLookupByLibrary.simpleMessage("Cuadrícula"),
    "groupCount": m31,
    "groupCountUnit": MessageLookupByLibrary.simpleMessage("grupos"),
    "groupTimeoutCount": m32,
    "hasCacheChange": MessageLookupByLibrary.simpleMessage(
      "¿Guardar los cambios en la caché?",
    ),
    "hashByInUser": MessageLookupByLibrary.simpleMessage(
      "Hash por usuario de entrada",
    ),
    "header": MessageLookupByLibrary.simpleMessage("Cabecera"),
    "healthCheck": MessageLookupByLibrary.simpleMessage(
      "Comprobación de estado",
    ),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "El servicio auxiliar (Helper) no está disponible; no se puede activar el modo TUN. Reinstala FlClash para restaurarlo.",
    ),
    "hex": MessageLookupByLibrary.simpleMessage("Hex"),
    "hide": MessageLookupByLibrary.simpleMessage("Ocultar"),
    "hideFromList": MessageLookupByLibrary.simpleMessage("Ocultar de la lista"),
    "hideIp": MessageLookupByLibrary.simpleMessage("Ocultar IP"),
    "hidePassword": MessageLookupByLibrary.simpleMessage("Ocultar contraseña"),
    "hideTimeoutProxies": MessageLookupByLibrary.simpleMessage(
      "Ocultar proxies sin respuesta",
    ),
    "hideTimeoutProxiesDesc": MessageLookupByLibrary.simpleMessage(
      "Omite los proxies cuya última prueba de latencia superó el tiempo de espera",
    ),
    "hideUnavailable": MessageLookupByLibrary.simpleMessage(
      "Ocultar tiempos de espera agotados",
    ),
    "highPriorityAutoLaunch": MessageLookupByLibrary.simpleMessage(
      "Inicio automático de alta prioridad",
    ),
    "highPriorityAutoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Usar una tarea programada de Windows para iniciar antes",
    ),
    "hopInterval": MessageLookupByLibrary.simpleMessage("Intervalo de salto"),
    "host": MessageLookupByLibrary.simpleMessage("Host"),
    "hostname": MessageLookupByLibrary.simpleMessage("Nombre de host"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("Añadir entradas hosts"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage(
      "Conflicto de atajos de teclado",
    ),
    "hotkeyConflictWith": m33,
    "hotkeyDesc": MessageLookupByLibrary.simpleMessage(
      "Los atajos globales funcionan incluso con la ventana oculta. Toca una acción para grabar su combinación de teclas.",
    ),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage(
      "Gestión de atajos",
    ),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "Controlar la aplicación con el teclado",
    ),
    "hotkeyNeedsModifier": m34,
    "hotkeyNotSet": MessageLookupByLibrary.simpleMessage("Sin asignar"),
    "hotkeyUnavailable": MessageLookupByLibrary.simpleMessage(
      "No registrado; puede que otra app lo esté usando",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("horas"),
    "hoursAgo": m35,
    "hoursAgoShort": m36,
    "hue": MessageLookupByLibrary.simpleMessage("Tono"),
    "icmpForwarding": MessageLookupByLibrary.simpleMessage("Reenvío ICMP"),
    "icmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "Activar ping ICMP",
    ),
    "icon": MessageLookupByLibrary.simpleMessage("Icono"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("Registros de iconos"),
    "iconSets": MessageLookupByLibrary.simpleMessage("Conjuntos de iconos"),
    "iconSetsEmptyTip": MessageLookupByLibrary.simpleMessage(
      "Aún no hay conjuntos de iconos. Añádelos en Recursos de perfil personalizado → Conjuntos de iconos",
    ),
    "iconSource": MessageLookupByLibrary.simpleMessage("Origen de iconos"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("Estilo de icono"),
    "iconStyleFilled": MessageLookupByLibrary.simpleMessage("Relleno"),
    "iconStyleHidden": MessageLookupByLibrary.simpleMessage("Oculto"),
    "iconStylePlain": MessageLookupByLibrary.simpleMessage("Simple"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("URL del icono"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "Ignorar optimización de batería",
    ),
    "ignoreCertificateErrors": MessageLookupByLibrary.simpleMessage(
      "Ignorar la validación de certificados",
    ),
    "ignoreCertificateErrorsDesc": MessageLookupByLibrary.simpleMessage(
      "Permitir conexiones HTTPS con certificados no válidos. Esto reduce la seguridad",
    ),
    "import": MessageLookupByLibrary.simpleMessage("Importar"),
    "importConfigInvalid": MessageLookupByLibrary.simpleMessage(
      "Este archivo no es una configuración importable",
    ),
    "importConfigReplaceTip": MessageLookupByLibrary.simpleMessage(
      "Al importar se reemplazan los grupos de proxies, las reglas y los ajustes que tiene ahora este perfil",
    ),
    "importFile": MessageLookupByLibrary.simpleMessage(
      "Importar desde archivo",
    ),
    "importFromLink": MessageLookupByLibrary.simpleMessage(
      "Importar desde enlace",
    ),
    "importFromURL": MessageLookupByLibrary.simpleMessage(
      "Importar desde una URL",
    ),
    "importUrl": MessageLookupByLibrary.simpleMessage("Importar desde URL"),
    "inbound": MessageLookupByLibrary.simpleMessage("Entrada"),
    "includeAllNetworks": MessageLookupByLibrary.simpleMessage(
      "Incluir todas las redes",
    ),
    "includeAllNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "Dirigir todo el tráfico de red por el túnel, incluidos los servicios locales y móviles",
    ),
    "includeAllProxies": MessageLookupByLibrary.simpleMessage(
      "Incluir todos los proxies",
    ),
    "includeAllProxiesTip": MessageLookupByLibrary.simpleMessage(
      "Importar todos los proxies fuera de los grupos; se pueden añadir más grupos de proxies abajo",
    ),
    "includeAllProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Incluir todos los proveedores de proxies",
    ),
    "includeAllProxyProvidersTip": MessageLookupByLibrary.simpleMessage(
      "Sobrescribir los proveedores de proxies importados cuando esté activado",
    ),
    "includeInterface": MessageLookupByLibrary.simpleMessage(
      "Interfaces incluidas",
    ),
    "includeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "Solo el tráfico que llega por las interfaces incluidas pasa por TUN, y las interfaces excluidas dejan de aplicarse.",
    ),
    "includeUid": MessageLookupByLibrary.simpleMessage(
      "ID de usuario incluidos",
    ),
    "includeUidDesc": MessageLookupByLibrary.simpleMessage(
      "Solo el tráfico de los procesos de los ID de usuario incluidos pasa por TUN.",
    ),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("No caduca"),
    "init": MessageLookupByLibrary.simpleMessage("Inicio"),
    "initFailed": MessageLookupByLibrary.simpleMessage("Error al iniciar"),
    "initFailedTip": MessageLookupByLibrary.simpleMessage(
      "FlClash encontró un error al iniciarse y no puede continuar. Copia los detalles para informar del problema. Si sigue ocurriendo, borrar los datos suele permitir que la app vuelva a iniciarse.",
    ),
    "initialize": MessageLookupByLibrary.simpleMessage("Inicializar"),
    "initiator": MessageLookupByLibrary.simpleMessage("Origen de la solicitud"),
    "initiatorShort": MessageLookupByLibrary.simpleMessage("De"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage(
      "Introduce un atajo de teclado válido",
    ),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage(
      "Introduce el nombre del grupo de proxies",
    ),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage(
      "Introduce el contenido de la regla",
    ),
    "installedAppsPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "Se denegó el permiso de lista de apps, por lo que no se pueden mostrar las apps instaladas. Concédelo manualmente en los ajustes del sistema.",
    ),
    "installedAppsPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Este sistema oculta la lista de apps instaladas hasta que se concede el permiso. Autorízalo para configurar el proxy por app.",
    ),
    "installedAppsPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Se requiere permiso de lista de apps",
    ),
    "installedFonts": MessageLookupByLibrary.simpleMessage(
      "Fuentes instaladas",
    ),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage(
      "Selección inteligente",
    ),
    "interfaceName": MessageLookupByLibrary.simpleMessage("Nombre de interfaz"),
    "interfaceNameDesc": MessageLookupByLibrary.simpleMessage(
      "El nombre de interfaz es la interfaz de red que usan las conexiones salientes.",
    ),
    "interfaceNameMode": MessageLookupByLibrary.simpleMessage(
      "Interfaz de salida",
    ),
    "interfaceNameModeClear": MessageLookupByLibrary.simpleMessage("Ninguna"),
    "interfaceNameModeCustom": MessageLookupByLibrary.simpleMessage(
      "Personalizada",
    ),
    "interfaceNameModeFollow": MessageLookupByLibrary.simpleMessage(
      "Seguir configuración",
    ),
    "internet": MessageLookupByLibrary.simpleMessage("Internet"),
    "interval": MessageLookupByLibrary.simpleMessage("Intervalo"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("IP de intranet"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage(
      "Archivo de copia de seguridad no válido",
    ),
    "invalidBackupFileName": MessageLookupByLibrary.simpleMessage(
      "Introduce un nombre de archivo válido, sin separadores de ruta ni caracteres especiales, de hasta 255 bytes.",
    ),
    "invalidCidrContent": MessageLookupByLibrary.simpleMessage(
      "Introduce un rango de IP en formato CIDR, como 192.168.0.0/16",
    ),
    "invalidDavDirectory": MessageLookupByLibrary.simpleMessage(
      "Introduce un directorio válido sin segmentos . o .., barras invertidas ni caracteres especiales.",
    ),
    "invalidDscpContent": MessageLookupByLibrary.simpleMessage(
      "Una marca DSCP no puede superar 63",
    ),
    "invalidHostContent": MessageLookupByLibrary.simpleMessage(
      "Introduce un dominio o una dirección IP",
    ),
    "invalidIconSet": MessageLookupByLibrary.simpleMessage(
      "No es un conjunto de iconos válido",
    ),
    "invalidLinkTip": MessageLookupByLibrary.simpleMessage(
      "No es un enlace de suscripción ni un enlace para compartir proxies",
    ),
    "invalidListenContent": MessageLookupByLibrary.simpleMessage(
      "Introduce una dirección y un puerto, como 0.0.0.0:1053",
    ),
    "invalidNetworkContent": MessageLookupByLibrary.simpleMessage(
      "Solo se admite tcp o udp",
    ),
    "invalidPolicy": m37,
    "invalidPortRangeContent": MessageLookupByLibrary.simpleMessage(
      "Introduce un puerto o un rango como 443 u 8000-9000",
    ),
    "invalidProfileQrcode": MessageLookupByLibrary.simpleMessage(
      "Este código QR no contiene un enlace de perfil",
    ),
    "invalidProxy": m38,
    "invalidProxyProvider": m39,
    "invalidRangeContent": MessageLookupByLibrary.simpleMessage(
      "Introduce números o rangos como 80 u 8000-9000, separados por /",
    ),
    "invalidRuleSet": m40,
    "invalidSubRule": m41,
    "ipAddress": MessageLookupByLibrary.simpleMessage("Dirección IP"),
    "ipAsn": MessageLookupByLibrary.simpleMessage("ASN"),
    "ipFlagAbuser": MessageLookupByLibrary.simpleMessage("Historial de abusos"),
    "ipFlagProxy": MessageLookupByLibrary.simpleMessage("Proxy"),
    "ipFlagTor": MessageLookupByLibrary.simpleMessage("Tor"),
    "ipFlagVpn": MessageLookupByLibrary.simpleMessage("VPN"),
    "ipFlags": MessageLookupByLibrary.simpleMessage("Indicadores"),
    "ipOrganization": MessageLookupByLibrary.simpleMessage("Organización"),
    "ipQualityFailed": MessageLookupByLibrary.simpleMessage(
      "No se pudo determinar el tipo de IP",
    ),
    "ipQualityGood": MessageLookupByLibrary.simpleMessage("Buena"),
    "ipQualityLevel": MessageLookupByLibrary.simpleMessage("Nivel"),
    "ipQualityNormal": MessageLookupByLibrary.simpleMessage("Normal"),
    "ipQualityRetry": MessageLookupByLibrary.simpleMessage(
      "Comprobar de nuevo",
    ),
    "ipQualityRisky": MessageLookupByLibrary.simpleMessage("Arriesgada"),
    "ipQualityShort": MessageLookupByLibrary.simpleMessage("Calidad"),
    "ipQualitySource": MessageLookupByLibrary.simpleMessage("Respondido por"),
    "ipQualitySources": MessageLookupByLibrary.simpleMessage("Fuentes"),
    "ipSourceIpMismatch": MessageLookupByLibrary.simpleMessage(
      "IP de salida distinta",
    ),
    "ipSourceNoType": MessageLookupByLibrary.simpleMessage("Sin tipo"),
    "ipSourceRateLimited": MessageLookupByLibrary.simpleMessage(
      "Límite de solicitudes",
    ),
    "ipType": MessageLookupByLibrary.simpleMessage("Tipo"),
    "ipTypeBusiness": MessageLookupByLibrary.simpleMessage("Empresarial"),
    "ipTypeHosting": MessageLookupByLibrary.simpleMessage("Centro de datos"),
    "ipTypeMobile": MessageLookupByLibrary.simpleMessage("Red móvil"),
    "ipTypeResidential": MessageLookupByLibrary.simpleMessage("Residencial"),
    "ipTypeUnknown": MessageLookupByLibrary.simpleMessage("Tipo desconocido"),
    "ipVersion": MessageLookupByLibrary.simpleMessage("Versión de IP"),
    "ipcidr": MessageLookupByLibrary.simpleMessage("CIDR IP"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "El tráfico IPv6 solo se recibe mientras IPv6 esté activado.",
    ),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "Con IPv6 activado, la VPN permite el tráfico IPv6 entrante.",
    ),
    "ipv6Timeout": MessageLookupByLibrary.simpleMessage(
      "Tiempo de espera IPv6 (ms)",
    ),
    "itemsCount": m42,
    "ja": MessageLookupByLibrary.simpleMessage("Japonés"),
    "justNow": MessageLookupByLibrary.simpleMessage("Ahora mismo"),
    "keepAliveIdle": MessageLookupByLibrary.simpleMessage(
      "Inactividad de keep-alive TCP",
    ),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "Intervalo de keep-alive TCP",
    ),
    "key": MessageLookupByLibrary.simpleMessage("Clave"),
    "ko": MessageLookupByLibrary.simpleMessage("Coreano"),
    "label": MessageLookupByLibrary.simpleMessage("Etiqueta"),
    "language": MessageLookupByLibrary.simpleMessage("Idioma"),
    "large": MessageLookupByLibrary.simpleMessage("Grande"),
    "lastUpdated": MessageLookupByLibrary.simpleMessage("Última actualización"),
    "launchInterrupted": MessageLookupByLibrary.simpleMessage(
      "El inicio no se completó",
    ),
    "launchInterruptedTip": MessageLookupByLibrary.simpleMessage(
      "La última vez, la app se cerró inesperadamente mientras se iniciaba. En este inicio se ha omitido la configuración automática; puedes iniciarla manualmente para reintentarlo.",
    ),
    "layout": MessageLookupByLibrary.simpleMessage("Diseño"),
    "level": MessageLookupByLibrary.simpleMessage("Nivel"),
    "light": MessageLookupByLibrary.simpleMessage("Claro"),
    "lineHeight": MessageLookupByLibrary.simpleMessage("Interlineado"),
    "lineIssueTip": m43,
    "lineWrap": MessageLookupByLibrary.simpleMessage("Ajuste de línea"),
    "link": MessageLookupByLibrary.simpleMessage("Enlace"),
    "linkDesc": MessageLookupByLibrary.simpleMessage(
      "Obtén un perfil desde un enlace de suscripción o un enlace para compartir proxies",
    ),
    "liquidGlass": MessageLookupByLibrary.simpleMessage("Liquid Glass"),
    "list": MessageLookupByLibrary.simpleMessage("Lista"),
    "listen": MessageLookupByLibrary.simpleMessage("Escucha"),
    "listenRoutingMark": MessageLookupByLibrary.simpleMessage(
      "Marca de enrutamiento de escucha",
    ),
    "listenRoutingMarkDesc": MessageLookupByLibrary.simpleMessage(
      "La marca de enrutamiento de escucha solo funciona en Linux.",
    ),
    "listeningPort": MessageLookupByLibrary.simpleMessage("Puerto de escucha"),
    "liveConnections": MessageLookupByLibrary.simpleMessage(
      "Conexiones activas",
    ),
    "loading": MessageLookupByLibrary.simpleMessage("Cargando…"),
    "local": MessageLookupByLibrary.simpleMessage("Local"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Guardar una copia de seguridad local",
    ),
    "localImage": MessageLookupByLibrary.simpleMessage("Imagen local"),
    "localNetworkDeniedTip": MessageLookupByLibrary.simpleMessage(
      "Permiso de red local denegado: con la pila gvisor, la LAN no es accesible.",
    ),
    "localProxies": MessageLookupByLibrary.simpleMessage("Proxies locales"),
    "locationPermission": MessageLookupByLibrary.simpleMessage(
      "Permiso de ubicación",
    ),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "Se denegó el permiso de ubicación, por lo que no se puede leer el nombre de la red Wi-Fi actual. Activa el permiso de ubicación manualmente en los ajustes del sistema.",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "El sistema requiere el permiso de ubicación para leer el nombre de la red Wi-Fi. En Android elige “Permitir todo el tiempo”; de lo contrario, no se podrá leer el nombre de la red Wi-Fi mientras la app esté en segundo plano.",
    ),
    "locationPermissionGuide": m44,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Se requiere permiso de ubicación",
    ),
    "log": MessageLookupByLibrary.simpleMessage("Registro"),
    "logLevel": MessageLookupByLibrary.simpleMessage("Nivel de registro"),
    "logcat": MessageLookupByLibrary.simpleMessage("Logcat"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "Si desactivas Logcat, se oculta la entrada de registros.",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("Registros"),
    "logsAndDiagnostics": MessageLookupByLibrary.simpleMessage(
      "Registros y diagnóstico",
    ),
    "logsDesc": MessageLookupByLibrary.simpleMessage("Registros capturados"),
    "logsTest": MessageLookupByLibrary.simpleMessage("Prueba de registros"),
    "loopback": MessageLookupByLibrary.simpleMessage(
      "Exención de loopback de UWP",
    ),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage(
      "Se usa para la exención de bucle invertido de UWP",
    ),
    "loose": MessageLookupByLibrary.simpleMessage("Amplio"),
    "manual": MessageLookupByLibrary.simpleMessage("Manual"),
    "matchCase": MessageLookupByLibrary.simpleMessage(
      "Coincidir mayúsculas y minúsculas",
    ),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage(
      "Coincidir con IP de origen",
    ),
    "matchTarget": MessageLookupByLibrary.simpleMessage("MATCH-TARGET"),
    "matchTargetDesc": MessageLookupByLibrary.simpleMessage(
      "Destino de las reglas que apuntan a MATCH-TARGET. Por defecto, es el destino de la última regla MATCH del perfil.",
    ),
    "matchTargetTitle": MessageLookupByLibrary.simpleMessage(
      "Destino de coincidencia",
    ),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage("Máximo de fallos"),
    "maxLengthTip": m45,
    "maximize": MessageLookupByLibrary.simpleMessage("Maximizar"),
    "memoryApp": MessageLookupByLibrary.simpleMessage(
      "Memoria de la aplicación",
    ),
    "memoryAppResident": MessageLookupByLibrary.simpleMessage(
      "Memoria residente",
    ),
    "memoryAppShared": MessageLookupByLibrary.simpleMessage("App y compartida"),
    "memoryCleanup": MessageLookupByLibrary.simpleMessage("Limpiar"),
    "memoryCoreHeapIdle": MessageLookupByLibrary.simpleMessage("Heap inactivo"),
    "memoryCoreHeapInuse": MessageLookupByLibrary.simpleMessage("Heap en uso"),
    "memoryCoreNotRunning": MessageLookupByLibrary.simpleMessage(
      "El núcleo no se está ejecutando",
    ),
    "memoryCoreRuntime": MessageLookupByLibrary.simpleMessage(
      "Sobrecarga del runtime",
    ),
    "memoryCoreStack": MessageLookupByLibrary.simpleMessage(
      "Pilas de goroutines",
    ),
    "memoryEstimateDesc": MessageLookupByLibrary.simpleMessage(
      "Estimado a partir de la memoria residente del proceso; puede diferir de lo que indica el sistema.",
    ),
    "memoryEstimateSharedDesc": MessageLookupByLibrary.simpleMessage(
      "El núcleo se ejecuta dentro del proceso de la app. Su parte se estima a partir de las estadísticas del runtime, y el resto cuenta como memoria de la app y compartida.",
    ),
    "memoryFootprint": MessageLookupByLibrary.simpleMessage(
      "Huella de memoria",
    ),
    "memoryGC": MessageLookupByLibrary.simpleMessage("Metadatos del GC"),
    "memoryHeapIdle": MessageLookupByLibrary.simpleMessage(
      "Memoria inactiva retenida del montón",
    ),
    "memoryHeapObjects": MessageLookupByLibrary.simpleMessage(
      "Objetos del montón",
    ),
    "memoryHeapReleased": MessageLookupByLibrary.simpleMessage(
      "Devuelta al sistema operativo",
    ),
    "memoryHeapUnused": MessageLookupByLibrary.simpleMessage(
      "Segmentos del montón sin usar",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage(
      "Información de memoria",
    ),
    "memoryInfoDesc": MessageLookupByLibrary.simpleMessage(
      "Memoria que usan la app y el núcleo",
    ),
    "memoryMetadata": MessageLookupByLibrary.simpleMessage(
      "Metadatos de ejecución",
    ),
    "memoryOther": MessageLookupByLibrary.simpleMessage(
      "Otra memoria de ejecución",
    ),
    "memoryReadFailed": MessageLookupByLibrary.simpleMessage(
      "No se puede leer la memoria. Reintentando…",
    ),
    "memoryReleased": MessageLookupByLibrary.simpleMessage("Memoria liberada"),
    "memoryReleasedSize": m46,
    "memoryStacks": MessageLookupByLibrary.simpleMessage("Pilas"),
    "memoryTotal": MessageLookupByLibrary.simpleMessage("Memoria usada por Go"),
    "messageTest": MessageLookupByLibrary.simpleMessage("Prueba de mensaje"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage(
      "Esto es un mensaje.",
    ),
    "minimize": MessageLookupByLibrary.simpleMessage("Minimizar"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage(
      "Minimizar al salir",
    ),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "Cambiar el comportamiento de salida predeterminado del sistema",
    ),
    "minutes": MessageLookupByLibrary.simpleMessage("minutos"),
    "minutesAgo": m47,
    "minutesAgoShort": m48,
    "mixedPort": MessageLookupByLibrary.simpleMessage("Puerto mixto"),
    "mode": MessageLookupByLibrary.simpleMessage("Modo"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("Monocromo"),
    "monochromeTrayIcon": MessageLookupByLibrary.simpleMessage(
      "Icono monocromo en la bandeja",
    ),
    "monthsAgo": m49,
    "monthsAgoShort": m50,
    "more": MessageLookupByLibrary.simpleMessage("Más"),
    "mtu": MessageLookupByLibrary.simpleMessage("MTU"),
    "mtuRangeTip": MessageLookupByLibrary.simpleMessage(
      "MTU debe ser un entero entre 1 y 65535",
    ),
    "multipleValuesTip": MessageLookupByLibrary.simpleMessage(
      "Separa los valores con comas",
    ),
    "name": MessageLookupByLibrary.simpleMessage("Nombre"),
    "nameserver": MessageLookupByLibrary.simpleMessage("Servidor DNS"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Se usa para resolver dominios",
    ),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "Política de servidores DNS",
    ),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Asignar servidores DNS específicos a los dominios, categorías geosite o conjuntos de reglas que coincidan",
    ),
    "navigationBarStyle": MessageLookupByLibrary.simpleMessage(
      "Barra inferior",
    ),
    "needsLogin": MessageLookupByLibrary.simpleMessage(
      "Se requiere iniciar sesión",
    ),
    "network": MessageLookupByLibrary.simpleMessage("Red"),
    "networkAccessDeniedError": m51,
    "networkBadResponseError": m52,
    "networkCancelledError": MessageLookupByLibrary.simpleMessage(
      "Se canceló la solicitud",
    ),
    "networkConnectionError": MessageLookupByLibrary.simpleMessage(
      "No se pudo conectar con el servidor. Comprueba tu conexión de red o los ajustes del proxy",
    ),
    "networkDesc": MessageLookupByLibrary.simpleMessage(
      "Ajustar la configuración de red",
    ),
    "networkException": MessageLookupByLibrary.simpleMessage(
      "Error de red. Comprueba la conexión y vuelve a intentarlo",
    ),
    "networkExtension": MessageLookupByLibrary.simpleMessage(
      "Extensión de red",
    ),
    "networkHostLookupError": MessageLookupByLibrary.simpleMessage(
      "No se pudo resolver la dirección del servidor. Comprueba que la URL sea correcta y que el DNS funcione",
    ),
    "networkId": MessageLookupByLibrary.simpleMessage("ID de red"),
    "networkName": MessageLookupByLibrary.simpleMessage("Nombre de la red"),
    "networkNotFound": MessageLookupByLibrary.simpleMessage(
      "No se encontró la red",
    ),
    "networkNotFoundError": m53,
    "networkRateLimitedError": MessageLookupByLibrary.simpleMessage(
      "Demasiadas solicitudes (HTTP 429). Espera un momento e inténtalo de nuevo",
    ),
    "networkRequestFailed": m54,
    "networkSecret": MessageLookupByLibrary.simpleMessage("Clave de la red"),
    "networkServerError": m55,
    "networkSpeed": MessageLookupByLibrary.simpleMessage("Velocidad de red"),
    "networkSpeedNotification": MessageLookupByLibrary.simpleMessage(
      "Mostrar la velocidad de red en tiempo real",
    ),
    "networkSpeedNotificationDesc": MessageLookupByLibrary.simpleMessage(
      "Mostrar la velocidad de red en el área de estado del sistema; puede aumentar ligeramente el consumo de energía",
    ),
    "networkTakeover": MessageLookupByLibrary.simpleMessage(
      "Control del tráfico",
    ),
    "networkTimeoutError": MessageLookupByLibrary.simpleMessage(
      "Se agotó el tiempo de espera de la solicitud. Comprueba tu red o el proxy e inténtalo de nuevo",
    ),
    "networkTlsError": MessageLookupByLibrary.simpleMessage(
      "Falló la conexión segura. Puede que el certificado del servidor no sea válido o que la conexión esté siendo interceptada",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("Tipo de red"),
    "networking": MessageLookupByLibrary.simpleMessage("Conectividad de red"),
    "networkingDesc": MessageLookupByLibrary.simpleMessage(
      "Ver el estado de las redes P2P",
    ),
    "networkingError": MessageLookupByLibrary.simpleMessage("Error"),
    "networkingNoOutbounds": MessageLookupByLibrary.simpleMessage(
      "No hay una salida P2P en la configuración actual",
    ),
    "newProfile": MessageLookupByLibrary.simpleMessage("Nuevo"),
    "newProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Escribir un perfil manualmente",
    ),
    "nextMatch": MessageLookupByLibrary.simpleMessage("Coincidencia siguiente"),
    "no": MessageLookupByLibrary.simpleMessage("No"),
    "noData": MessageLookupByLibrary.simpleMessage("Sin datos"),
    "noDirectories": MessageLookupByLibrary.simpleMessage(
      "No hay subdirectorios",
    ),
    "noFilterCondition": MessageLookupByLibrary.simpleMessage(
      "Sin condiciones de filtro",
    ),
    "noHotKey": MessageLookupByLibrary.simpleMessage(
      "Aún no hay atajos de teclado",
    ),
    "noInfo": MessageLookupByLibrary.simpleMessage("Sin información"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage(
      "No volver a recordármelo",
    ),
    "noNetwork": MessageLookupByLibrary.simpleMessage("Sin red"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("Apps sin red"),
    "noRemoteBackups": MessageLookupByLibrary.simpleMessage(
      "No se encontraron copias de seguridad remotas",
    ),
    "noResolve": MessageLookupByLibrary.simpleMessage("No resolver IP"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage(
      "No resolver nombre de host",
    ),
    "noSearchResults": MessageLookupByLibrary.simpleMessage(
      "No hay resultados",
    ),
    "nodeTrafficReadFailed": MessageLookupByLibrary.simpleMessage(
      "No se puede leer el tráfico. Reintentando…",
    ),
    "nodeTrafficUsage": MessageLookupByLibrary.simpleMessage(
      "Tráfico de nodos",
    ),
    "nodes": MessageLookupByLibrary.simpleMessage("Nodos"),
    "nonTextProviderFile": MessageLookupByLibrary.simpleMessage(
      "Este recurso externo no es un archivo de texto",
    ),
    "none": MessageLookupByLibrary.simpleMessage("Ninguno"),
    "notRunning": MessageLookupByLibrary.simpleMessage("Detenido"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "No se puede seleccionar el grupo de proxies actual",
    ),
    "ntpDesc": MessageLookupByLibrary.simpleMessage(
      "Actualizar la configuración de NTP",
    ),
    "ntpInterval": MessageLookupByLibrary.simpleMessage(
      "Intervalo de sincronización (minutos)",
    ),
    "ntpStatusDesc": MessageLookupByLibrary.simpleMessage(
      "NTP obtiene la hora de un servidor NTP en lugar del reloj del sistema.",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Añade un perfil para empezar",
    ),
    "nullTip": m56,
    "numberRangeTip": m57,
    "numberTip": m58,
    "obfs": MessageLookupByLibrary.simpleMessage("Ofuscación"),
    "obfsHost": MessageLookupByLibrary.simpleMessage("Host de ofuscación"),
    "obfsMode": MessageLookupByLibrary.simpleMessage("Modo de ofuscación"),
    "obfsParam": MessageLookupByLibrary.simpleMessage(
      "Parámetro de ofuscación",
    ),
    "obfsPassword": MessageLookupByLibrary.simpleMessage(
      "Contraseña de ofuscación",
    ),
    "offline": MessageLookupByLibrary.simpleMessage("Sin conexión"),
    "onDemand": MessageLookupByLibrary.simpleMessage("Bajo demanda"),
    "onDemandDesc": MessageLookupByLibrary.simpleMessage(
      "Bajo demanda pausa el proxy en las redes Wi-Fi excluidas.",
    ),
    "online": MessageLookupByLibrary.simpleMessage("En línea"),
    "onlyConfig": MessageLookupByLibrary.simpleMessage("Solo configuración"),
    "onlyEmoji": MessageLookupByLibrary.simpleMessage("Solo emoji"),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("Solo icono"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "Contar solo el tráfico del proxy",
    ),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Contabilizar solo el tráfico del proxy cuando esté activado",
    ),
    "openInGitHub": MessageLookupByLibrary.simpleMessage("Abrir en GitHub"),
    "optional": MessageLookupByLibrary.simpleMessage("Opcional"),
    "options": MessageLookupByLibrary.simpleMessage("Opciones"),
    "other": MessageLookupByLibrary.simpleMessage("Otros"),
    "otherContributors": MessageLookupByLibrary.simpleMessage(
      "Otros colaboradores",
    ),
    "outbound": MessageLookupByLibrary.simpleMessage("Salida"),
    "outboundExit": MessageLookupByLibrary.simpleMessage("Salida"),
    "outboundIp": MessageLookupByLibrary.simpleMessage("IP de salida"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("Modo de salida"),
    "override": MessageLookupByLibrary.simpleMessage("Sobrescribir"),
    "overrideDestination": MessageLookupByLibrary.simpleMessage(
      "Sobrescribir destino",
    ),
    "overrideDestinationDesc": MessageLookupByLibrary.simpleMessage(
      "Sobrescribir destino se conecta al dominio detectado en lugar de a la dirección original.",
    ),
    "overrideDns": MessageLookupByLibrary.simpleMessage("Sobrescribir DNS"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "Sobrescribir las opciones DNS del perfil cuando esté activado",
    ),
    "overrideEntries": MessageLookupByLibrary.simpleMessage(
      "Entradas de sobrescritura",
    ),
    "overrideMode": MessageLookupByLibrary.simpleMessage(
      "Modo de sobrescritura",
    ),
    "overrideNtp": MessageLookupByLibrary.simpleMessage("Sobrescribir NTP"),
    "overrideNtpDesc": MessageLookupByLibrary.simpleMessage(
      "Sobrescribir las opciones NTP del perfil cuando esté activado",
    ),
    "overrideScript": MessageLookupByLibrary.simpleMessage(
      "Script de sobrescritura",
    ),
    "overwriteTypeCustom": MessageLookupByLibrary.simpleMessage(
      "Personalizado",
    ),
    "overwriteTypeCustomDesc": MessageLookupByLibrary.simpleMessage(
      "Modo personalizado: personalizar por completo los grupos de proxies y las reglas",
    ),
    "parentDirectory": MessageLookupByLibrary.simpleMessage(
      "Directorio superior",
    ),
    "parsePureIp": MessageLookupByLibrary.simpleMessage("Analizar IP pura"),
    "parsePureIpDesc": MessageLookupByLibrary.simpleMessage(
      "Analizar IP pura analiza las conexiones que solo llevan una dirección IP.",
    ),
    "password": MessageLookupByLibrary.simpleMessage("Contraseña"),
    "paste": MessageLookupByLibrary.simpleMessage("Pegar"),
    "peers": MessageLookupByLibrary.simpleMessage("Pares"),
    "pickFromAlbum": MessageLookupByLibrary.simpleMessage("Elegir del álbum"),
    "pinWindow": MessageLookupByLibrary.simpleMessage("Fijar ventana"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage("Vincula WebDAV"),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "Introduce un nombre para el script",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "Sube un código QR válido",
    ),
    "plugin": MessageLookupByLibrary.simpleMessage("Complemento"),
    "pluginHost": MessageLookupByLibrary.simpleMessage("Host del complemento"),
    "pluginMode": MessageLookupByLibrary.simpleMessage("Modo del complemento"),
    "port": MessageLookupByLibrary.simpleMessage("Puerto"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "Introduce un puerto diferente",
    ),
    "portHopping": MessageLookupByLibrary.simpleMessage("Salto de puertos"),
    "portTip": m59,
    "portValue": m60,
    "ports": MessageLookupByLibrary.simpleMessage("Puertos"),
    "positiveIntegerTip": MessageLookupByLibrary.simpleMessage(
      "Introduce un entero mayor que 0",
    ),
    "preSharedKey": MessageLookupByLibrary.simpleMessage("Clave precompartida"),
    "predictiveBack": MessageLookupByLibrary.simpleMessage(
      "Retroceso predictivo",
    ),
    "preferH3": MessageLookupByLibrary.simpleMessage("Preferir HTTP/3"),
    "preferH3Desc": MessageLookupByLibrary.simpleMessage(
      "Preferir HTTP/3 para DoH",
    ),
    "prerequisites": MessageLookupByLibrary.simpleMessage("Requisitos previos"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage(
      "Pulsa una combinación de teclas",
    ),
    "preview": MessageLookupByLibrary.simpleMessage("Vista previa"),
    "previousMatch": MessageLookupByLibrary.simpleMessage(
      "Coincidencia anterior",
    ),
    "privateKey": MessageLookupByLibrary.simpleMessage("Clave privada"),
    "privateKeyPassphrase": MessageLookupByLibrary.simpleMessage(
      "Frase de contraseña de la clave privada",
    ),
    "process": MessageLookupByLibrary.simpleMessage("Proceso"),
    "profile": MessageLookupByLibrary.simpleMessage("Perfil"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("Introduce un intervalo válido"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "Introduce el intervalo de actualización automática",
        ),
    "profileDaysLeft": m61,
    "profileExpiresIn": m62,
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "El perfil se ha modificado. ¿Desactivar la actualización automática?",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Introduce el nombre del perfil",
    ),
    "profileSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Se aplica solo a este perfil; lo que no añadas usa su valor predeterminado.",
    ),
    "profileTunSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Se aplica solo a este perfil y tiene prioridad sobre las entradas de sobrescritura de TUN de los ajustes de red.",
    ),
    "profileUpdatedAt": m63,
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Introduce una URL de perfil válida",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Introduce la URL del perfil",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("Perfiles"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("Ordenar perfiles"),
    "project": MessageLookupByLibrary.simpleMessage("Proyecto"),
    "promptCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Confirmar el cierre de conexiones",
    ),
    "promptCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Preguntar si se deben cerrar las conexiones después de cambiar de nodo",
    ),
    "protocol": MessageLookupByLibrary.simpleMessage("Protocolo"),
    "protocolParam": MessageLookupByLibrary.simpleMessage(
      "Parámetro del protocolo",
    ),
    "protocolVersion": MessageLookupByLibrary.simpleMessage(
      "Versión del protocolo",
    ),
    "providerInUse": m64,
    "providerUrlTip": MessageLookupByLibrary.simpleMessage(
      "Solo se admiten proveedores remotos",
    ),
    "providers": MessageLookupByLibrary.simpleMessage("Recursos externos"),
    "proxies": MessageLookupByLibrary.simpleMessage("Proxies"),
    "proxiesCount": m65,
    "proxiesProfileLabel": m66,
    "proxiesRemovedTip": m67,
    "proxiesReplacedTip": m68,
    "proxy": MessageLookupByLibrary.simpleMessage("Proxy"),
    "proxyChains": MessageLookupByLibrary.simpleMessage("Cadena de proxies"),
    "proxyDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Los proxies seleccionados presentan una anomalía",
    ),
    "proxyFilter": MessageLookupByLibrary.simpleMessage("Filtro de proxies"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("Grupo de proxies"),
    "proxyGroupDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "El grupo de proxies actual presenta una anomalía",
    ),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage(
      "El grupo de proxies está vacío",
    ),
    "proxyGroupInUse": m69,
    "proxyGroupNameEmpty": MessageLookupByLibrary.simpleMessage(
      "El nombre del grupo de proxies no puede estar vacío",
    ),
    "proxyGroupsAfterStart": MessageLookupByLibrary.simpleMessage(
      "Los grupos aparecen aquí cuando se inicia el núcleo",
    ),
    "proxyGroupsCount": m70,
    "proxyNameserver": MessageLookupByLibrary.simpleMessage(
      "Servidor DNS de proxies",
    ),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Se usa para resolver los dominios de los nodos proxy",
    ),
    "proxyNameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "Política DNS de proxies",
    ),
    "proxyNameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Especificar la política de servidores DNS para los nodos proxy",
    ),
    "proxyProvider": MessageLookupByLibrary.simpleMessage(
      "Proveedor de proxies",
    ),
    "proxyProviderDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Los proveedores de proxies seleccionados presentan una anomalía",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage(
      "Proveedores de proxies",
    ),
    "proxyType": MessageLookupByLibrary.simpleMessage("Tipo de proxy"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("Depurar caché"),
    "publicKey": MessageLookupByLibrary.simpleMessage("Clave pública"),
    "pureBlack": MessageLookupByLibrary.simpleMessage("Negro puro"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("Modo negro puro"),
    "qrcode": MessageLookupByLibrary.simpleMessage("Código QR"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "Escanea un código QR para obtener un perfil",
    ),
    "query": MessageLookupByLibrary.simpleMessage("Consultar"),
    "queryDns": MessageLookupByLibrary.simpleMessage("Consultar DNS"),
    "queryRule": MessageLookupByLibrary.simpleMessage("Consultar reglas"),
    "quickActions": MessageLookupByLibrary.simpleMessage("Acciones rápidas"),
    "quickEdit": MessageLookupByLibrary.simpleMessage("Edición rápida"),
    "quickFill": MessageLookupByLibrary.simpleMessage("Relleno rápido"),
    "random": MessageLookupByLibrary.simpleMessage("Aleatorio"),
    "recentRequests": MessageLookupByLibrary.simpleMessage(
      "Solicitudes recientes",
    ),
    "recommendedIcons": MessageLookupByLibrary.simpleMessage("Sugeridos"),
    "recordType": MessageLookupByLibrary.simpleMessage("Tipo de registro"),
    "recvMsgX": MessageLookupByLibrary.simpleMessage("Activar RecvMsgX"),
    "recvMsgXDesc": MessageLookupByLibrary.simpleMessage(
      "Recibir paquetes por lotes en Darwin",
    ),
    "redirPort": MessageLookupByLibrary.simpleMessage("Puerto Redir"),
    "redo": MessageLookupByLibrary.simpleMessage("Rehacer"),
    "regex": MessageLookupByLibrary.simpleMessage("Expresión regular"),
    "regexSearch": MessageLookupByLibrary.simpleMessage(
      "Búsqueda con expresiones regulares",
    ),
    "relayed": MessageLookupByLibrary.simpleMessage("Retransmitido"),
    "releaseMemory": MessageLookupByLibrary.simpleMessage("Liberar memoria"),
    "releaseMemoryFailed": MessageLookupByLibrary.simpleMessage(
      "No se pudo liberar la memoria",
    ),
    "remote": MessageLookupByLibrary.simpleMessage("Remoto"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Guardar una copia de seguridad en WebDAV",
    ),
    "remoteDestination": MessageLookupByLibrary.simpleMessage("Destino remoto"),
    "remoteDnsResolve": MessageLookupByLibrary.simpleMessage(
      "Resolución DNS remota",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("Quitar"),
    "rename": MessageLookupByLibrary.simpleMessage("Renombrar"),
    "replace": MessageLookupByLibrary.simpleMessage("Reemplazar"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("Reemplazar todo"),
    "request": MessageLookupByLibrary.simpleMessage("Solicitud"),
    "requests": MessageLookupByLibrary.simpleMessage("Solicitudes"),
    "requestsAndUpdates": MessageLookupByLibrary.simpleMessage(
      "Solicitudes y actualizaciones",
    ),
    "requestsDesc": MessageLookupByLibrary.simpleMessage(
      "Ver registros de solicitudes recientes",
    ),
    "required": MessageLookupByLibrary.simpleMessage("Obligatorio"),
    "reset": MessageLookupByLibrary.simpleMessage("Restablecer"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "Esta página tiene cambios. ¿Seguro que quieres restablecer?",
    ),
    "resetProfilesAndScripts": MessageLookupByLibrary.simpleMessage(
      "Perfiles y scripts",
    ),
    "resetSettingsData": MessageLookupByLibrary.simpleMessage(
      "Ajustes de la aplicación",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage(
      "¿Seguro que quieres restablecer?",
    ),
    "resourceUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Intervalo de actualización automática",
    ),
    "resourceUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "El intervalo de actualización automática debe ser mayor que 0",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("Recursos"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage(
      "Información sobre recursos externos",
    ),
    "respectRules": MessageLookupByLibrary.simpleMessage("Respetar reglas"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "Respetar reglas enruta las conexiones DNS según las reglas y requiere un Proxy Server Nameserver.",
    ),
    "responseCode": MessageLookupByLibrary.simpleMessage("Código de respuesta"),
    "restart": MessageLookupByLibrary.simpleMessage("Reiniciar"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage(
      "¿Seguro que quieres reiniciar el núcleo?",
    ),
    "restore": MessageLookupByLibrary.simpleMessage("Restaurar"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage(
      "Restaurar todos los datos",
    ),
    "restoreException": MessageLookupByLibrary.simpleMessage(
      "Error de restauración",
    ),
    "restoreFromFileDesc": MessageLookupByLibrary.simpleMessage(
      "Restaurar datos desde un archivo",
    ),
    "restoreFromWebDAVDesc": MessageLookupByLibrary.simpleMessage(
      "Restaurar datos desde WebDAV",
    ),
    "restoreHiddenGroups": MessageLookupByLibrary.simpleMessage(
      "Restaurar grupos ocultos",
    ),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage(
      "Restaurar solo los perfiles",
    ),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage(
      "Estrategia de restauración",
    ),
    "restoreStrategyCompatible": MessageLookupByLibrary.simpleMessage(
      "Compatible",
    ),
    "restoreStrategyOverride": MessageLookupByLibrary.simpleMessage(
      "Sobrescribir",
    ),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage(
      "Restauración completada",
    ),
    "result": MessageLookupByLibrary.simpleMessage("Resultado"),
    "retry": MessageLookupByLibrary.simpleMessage("Reintentar"),
    "role": MessageLookupByLibrary.simpleMessage("Rol"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("Direcciones de ruta"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage(
      "Configurar las direcciones de las rutas de escucha",
    ),
    "routeExcludeAddress": MessageLookupByLibrary.simpleMessage(
      "Direcciones excluidas de la ruta",
    ),
    "routeMode": MessageLookupByLibrary.simpleMessage("Modo de enrutamiento"),
    "routeModeBypassPrivate": MessageLookupByLibrary.simpleMessage(
      "Excluir direcciones privadas",
    ),
    "routeModeConfig": MessageLookupByLibrary.simpleMessage(
      "Usar la configuración",
    ),
    "routes": MessageLookupByLibrary.simpleMessage("Rutas"),
    "routingMark": MessageLookupByLibrary.simpleMessage(
      "Marca de enrutamiento",
    ),
    "ru": MessageLookupByLibrary.simpleMessage("Ruso"),
    "rule": MessageLookupByLibrary.simpleMessage("Regla"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage(
      "Regla lógica AND",
    ),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el dominio completo",
    ),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con una palabra clave del dominio",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con una expresión regular de dominio",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con un sufijo de dominio",
    ),
    "ruleActionDomainWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Coincidencia con comodines; solo se admiten * y ?",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con la marca DSCP (solo entrada UDP de tproxy)",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el rango de puertos de destino",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el código de país de la IP",
    ),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con los dominios de Geosite",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el nombre de la entrada",
    ),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el puerto de entrada",
    ),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el tipo de entrada",
    ),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el nombre de usuario de entrada; separa varios usuarios con /",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el ASN de la IP",
    ),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "Coincide con un rango de direcciones IP; IP-CIDR6 es solo un alias",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con un rango de direcciones IP",
    ),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con un rango de sufijo de IP",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con todas las solicitudes, sin necesidad de condiciones",
    ),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con TCP o UDP",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage(
      "Regla lógica NOT",
    ),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage("Regla lógica OR"),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el nombre del proceso; en Android coincide con el nombre del paquete",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con una expresión regular del nombre del proceso; en Android coincide con el nombre del paquete",
    ),
    "ruleActionProcessNameWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con comodines en el nombre del proceso; solo se admiten * y ?",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con la ruta completa del proceso",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con una expresión regular de la ruta del proceso",
    ),
    "ruleActionProcessPathWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con comodines en la ruta del proceso; solo se admiten * y ?",
    ),
    "ruleActionRematchNameDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el nombre de rematch; separa varios nombres con /",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "Hace referencia a un conjunto de reglas; requiere rule-providers",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el código de país de la IP de origen",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el ASN de la IP de origen",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con un rango de direcciones IP de origen",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con un rango de sufijo de IP de origen",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el rango de puertos de origen",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con una subregla; cuidado con los paréntesis",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el ID de usuario de Linux",
    ),
    "ruleDisabled": MessageLookupByLibrary.simpleMessage("Desactivada"),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("La regla está vacía"),
    "ruleEnabled": MessageLookupByLibrary.simpleMessage("Activada"),
    "ruleHits": MessageLookupByLibrary.simpleMessage("Coincidencias"),
    "ruleLastHit": MessageLookupByLibrary.simpleMessage("Última coincidencia"),
    "ruleLastMiss": MessageLookupByLibrary.simpleMessage(
      "Última no coincidencia",
    ),
    "ruleListInvalid": MessageLookupByLibrary.simpleMessage(
      "Las reglas deben ser una lista YAML con una regla por elemento, por ejemplo - DOMAIN,example.com,DIRECT",
    ),
    "ruleMisses": MessageLookupByLibrary.simpleMessage("No coincidencias"),
    "rulePresetBittorrentDirect": MessageLookupByLibrary.simpleMessage(
      "BitTorrent directo",
    ),
    "rulePresetBlockDot": MessageLookupByLibrary.simpleMessage(
      "Bloquear DNS sobre TLS",
    ),
    "rulePresetBlockLoopback": MessageLookupByLibrary.simpleMessage(
      "Bloquear bucle del proxy",
    ),
    "rulePresetBlockQuic": MessageLookupByLibrary.simpleMessage(
      "Bloquear QUIC",
    ),
    "rulePresetBlockStun": MessageLookupByLibrary.simpleMessage(
      "Bloquear STUN",
    ),
    "rulePresetLanDirect": MessageLookupByLibrary.simpleMessage("LAN directa"),
    "rulePresetSystemServicesDirect": MessageLookupByLibrary.simpleMessage(
      "Apple y Microsoft directos",
    ),
    "ruleProviders": MessageLookupByLibrary.simpleMessage(
      "Proveedores de reglas",
    ),
    "ruleQueryDestinationIP": MessageLookupByLibrary.simpleMessage(
      "IP de destino",
    ),
    "ruleQueryInboundName": MessageLookupByLibrary.simpleMessage(
      "Nombre de entrada",
    ),
    "ruleQueryInboundUser": MessageLookupByLibrary.simpleMessage(
      "Usuario de entrada",
    ),
    "ruleQueryInvalidIP": MessageLookupByLibrary.simpleMessage(
      "Introduce una dirección IP válida.",
    ),
    "ruleQueryNoMatch": MessageLookupByLibrary.simpleMessage(
      "Ninguna regla coincide (política del modo o alternativa DIRECT)",
    ),
    "ruleQueryNumberRange": m71,
    "ruleQueryPortInvalid": MessageLookupByLibrary.simpleMessage(
      "Introduce un puerto entre 1 y 65535.",
    ),
    "ruleQueryProcessPath": MessageLookupByLibrary.simpleMessage(
      "Ruta del proceso",
    ),
    "ruleQuerySniffHost": MessageLookupByLibrary.simpleMessage(
      "Dominio detectado",
    ),
    "ruleQuerySourcePort": MessageLookupByLibrary.simpleMessage(
      "Puerto de origen",
    ),
    "ruleQueryTarget": MessageLookupByLibrary.simpleMessage(
      "Dominio o dirección IP",
    ),
    "ruleSet": MessageLookupByLibrary.simpleMessage("Conjunto de reglas"),
    "ruleSetEmptyTip": MessageLookupByLibrary.simpleMessage(
      "El conjunto de reglas no tiene entradas utilizables",
    ),
    "ruleSetInvalidTip": MessageLookupByLibrary.simpleMessage(
      "No se puede leer este archivo mrs",
    ),
    "ruleSetMixedTip": MessageLookupByLibrary.simpleMessage(
      "El conjunto de reglas mezcla dominios y rangos de IP, por lo que no se puede determinar su tipo",
    ),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("Destino de la regla"),
    "ruleTextInvalid": MessageLookupByLibrary.simpleMessage(
      "La regla debe empezar con un tipo admitido, por ejemplo DOMAIN,example.com,DIRECT",
    ),
    "ruleType": MessageLookupByLibrary.simpleMessage("Tipo de regla"),
    "ruleUpdateFailed": MessageLookupByLibrary.simpleMessage(
      "No se pudo cambiar la regla. Puede que la configuración haya cambiado; actualiza y vuelve a intentarlo.",
    ),
    "rules": MessageLookupByLibrary.simpleMessage("Reglas"),
    "rulesCount": m72,
    "rulesDesc": MessageLookupByLibrary.simpleMessage(
      "Ver reglas y estadísticas de coincidencias",
    ),
    "runTime": MessageLookupByLibrary.simpleMessage("Tiempo de ejecución"),
    "running": MessageLookupByLibrary.simpleMessage("En ejecución"),
    "runtimeConfig": MessageLookupByLibrary.simpleMessage(
      "Configuración de ejecución",
    ),
    "safeMode": MessageLookupByLibrary.simpleMessage("Modo seguro"),
    "safeModeAppTitle": m73,
    "saturation": MessageLookupByLibrary.simpleMessage("Saturación"),
    "save": MessageLookupByLibrary.simpleMessage("Guardar"),
    "saveChanges": MessageLookupByLibrary.simpleMessage(
      "¿Guardar los cambios?",
    ),
    "script": MessageLookupByLibrary.simpleMessage("Script"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "Modo script: reescribe todo el perfil con un script de extensión",
    ),
    "scrollToSelected": MessageLookupByLibrary.simpleMessage(
      "Ir a la selección",
    ),
    "search": MessageLookupByLibrary.simpleMessage("Buscar"),
    "seconds": MessageLookupByLibrary.simpleMessage("segundos"),
    "secondsCount": m74,
    "secretKey": MessageLookupByLibrary.simpleMessage("Clave"),
    "sectionsInEffect": m75,
    "selectAll": MessageLookupByLibrary.simpleMessage("Seleccionar todo"),
    "selectMatchTarget": MessageLookupByLibrary.simpleMessage(
      "Seleccionar MATCH-TARGET",
    ),
    "selectRemoteBackup": MessageLookupByLibrary.simpleMessage(
      "Seleccionar una copia de seguridad",
    ),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage(
      "Selecciona un conjunto de reglas",
    ),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage(
      "Selecciona una estrategia de división",
    ),
    "selected": MessageLookupByLibrary.simpleMessage("Seleccionado"),
    "sendMsgX": MessageLookupByLibrary.simpleMessage("Activar SendMsgX"),
    "sendMsgXDesc": MessageLookupByLibrary.simpleMessage(
      "Enviar paquetes por lotes en Darwin",
    ),
    "server": MessageLookupByLibrary.simpleMessage("Servidor"),
    "serviceAbnormalCount": m76,
    "serviceAllAvailable": MessageLookupByLibrary.simpleMessage(
      "Todo disponible",
    ),
    "serviceAvailable": MessageLookupByLibrary.simpleMessage("Disponible"),
    "serviceBlocked": MessageLookupByLibrary.simpleMessage("Bloqueado"),
    "serviceCheck": MessageLookupByLibrary.simpleMessage("Comprobar"),
    "serviceCheckAll": MessageLookupByLibrary.simpleMessage("Comprobar todo"),
    "serviceCheckedAt": m77,
    "serviceComingSoon": MessageLookupByLibrary.simpleMessage("Próximamente"),
    "serviceDisallowedIsp": MessageLookupByLibrary.simpleMessage(
      "ISP no permitido",
    ),
    "serviceFailed": MessageLookupByLibrary.simpleMessage(
      "Error en la comprobación",
    ),
    "serviceManage": MessageLookupByLibrary.simpleMessage(
      "Gestionar servicios",
    ),
    "serviceOriginalsOnly": MessageLookupByLibrary.simpleMessage(
      "Solo originales",
    ),
    "servicePending": MessageLookupByLibrary.simpleMessage("Sin comprobar"),
    "serviceRestricted": MessageLookupByLibrary.simpleMessage(
      "Acceso restringido",
    ),
    "serviceShownOnDashboard": MessageLookupByLibrary.simpleMessage(
      "Se muestra en el panel",
    ),
    "serviceStatus": MessageLookupByLibrary.simpleMessage(
      "Estado del servicio",
    ),
    "serviceUnavailable": MessageLookupByLibrary.simpleMessage("No disponible"),
    "serviceUnsupportedRegion": MessageLookupByLibrary.simpleMessage(
      "Región no compatible",
    ),
    "settingEntries": MessageLookupByLibrary.simpleMessage("ajustes"),
    "settings": MessageLookupByLibrary.simpleMessage("Ajustes"),
    "settingsCount": m78,
    "shareLinkUnreadable": m79,
    "shareLinksInvalid": MessageLookupByLibrary.simpleMessage(
      "No se pudo leer ningún proxy de los enlaces",
    ),
    "show": MessageLookupByLibrary.simpleMessage("Mostrar"),
    "showHiddenGroups": MessageLookupByLibrary.simpleMessage(
      "Mostrar grupos ocultos",
    ),
    "showLess": MessageLookupByLibrary.simpleMessage("Contraer"),
    "showMore": MessageLookupByLibrary.simpleMessage("Expandir"),
    "showNotificationStopAction": MessageLookupByLibrary.simpleMessage(
      "Botón de detener en la notificación",
    ),
    "showNotificationStopActionDesc": MessageLookupByLibrary.simpleMessage(
      "Mostrar un botón para detener en la notificación persistente. Desactívalo si hace que tu sistema mantenga expandida la notificación",
    ),
    "showPassword": MessageLookupByLibrary.simpleMessage("Mostrar contraseña"),
    "showQuickSettingsProfileName": MessageLookupByLibrary.simpleMessage(
      "Mostrar el nombre del perfil actual",
    ),
    "showQuickSettingsProfileNameDesc": MessageLookupByLibrary.simpleMessage(
      "Mostrar el nombre del perfil en el acceso rápido cuando esté conectado",
    ),
    "showTrayProxySelection": MessageLookupByLibrary.simpleMessage(
      "Mostrar la selección de proxy en la bandeja",
    ),
    "showTrayProxySelectionDesc": MessageLookupByLibrary.simpleMessage(
      "Mostrar grupos y nodos proxy en el menú de la bandeja para cambiar rápidamente",
    ),
    "showUnavailable": MessageLookupByLibrary.simpleMessage(
      "Mostrar tiempos de espera agotados",
    ),
    "sidebarBlur": MessageLookupByLibrary.simpleMessage(
      "Desenfoque de la barra lateral",
    ),
    "sidebarBlurDesc": MessageLookupByLibrary.simpleMessage(
      "Muestra el escritorio desenfocado detrás de la ventana a través de la barra lateral",
    ),
    "signIn": MessageLookupByLibrary.simpleMessage("Iniciar sesión"),
    "signOut": MessageLookupByLibrary.simpleMessage("Cerrar sesión"),
    "signedIn": MessageLookupByLibrary.simpleMessage("Sesión iniciada"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("Inicio silencioso"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "El inicio silencioso arranca sin mostrar la ventana.",
    ),
    "singleAdd": MessageLookupByLibrary.simpleMessage("Añadir uno"),
    "singleImport": MessageLookupByLibrary.simpleMessage("Importar uno"),
    "singleShareLinkOnly": MessageLookupByLibrary.simpleMessage(
      "Introduce aquí un solo enlace; para varios, usa la edición rápida de la lista",
    ),
    "singleValueTip": m80,
    "size": MessageLookupByLibrary.simpleMessage("Tamaño"),
    "skipCertVerify": MessageLookupByLibrary.simpleMessage(
      "Omitir verificación de certificado",
    ),
    "skipDomain": MessageLookupByLibrary.simpleMessage("Omitir dominios"),
    "skipDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Un dominio detectado que esté en la lista de dominios omitidos no se usa.",
    ),
    "skipDstAddress": MessageLookupByLibrary.simpleMessage(
      "Omitir direcciones de destino",
    ),
    "skipSrcAddress": MessageLookupByLibrary.simpleMessage(
      "Omitir direcciones de origen",
    ),
    "slide": MessageLookupByLibrary.simpleMessage("Deslizar"),
    "sliders": MessageLookupByLibrary.simpleMessage("Reguladores"),
    "small": MessageLookupByLibrary.simpleMessage("Pequeño"),
    "sniffProtocols": MessageLookupByLibrary.simpleMessage("Protocolos"),
    "sniffer": MessageLookupByLibrary.simpleMessage("Sniffer"),
    "snifferStatusDesc": MessageLookupByLibrary.simpleMessage(
      "El sniffer lee el dominio del tráfico TLS, HTTP y QUIC para que las reglas puedan aplicarse.",
    ),
    "socksPort": MessageLookupByLibrary.simpleMessage("Puerto SOCKS"),
    "softStyle": MessageLookupByLibrary.simpleMessage("Suave"),
    "sort": MessageLookupByLibrary.simpleMessage("Ordenar"),
    "source": MessageLookupByLibrary.simpleMessage("Origen"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("IP de origen"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("Proxy especial"),
    "specialRules": MessageLookupByLibrary.simpleMessage("Reglas especiales"),
    "spectrum": MessageLookupByLibrary.simpleMessage("Espectro"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage(
      "Estadísticas de velocidad",
    ),
    "splitStrategy": MessageLookupByLibrary.simpleMessage(
      "Estrategia de división",
    ),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage(
      "La estrategia de división no puede estar vacía",
    ),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("No hay SSID"),
    "stackMode": MessageLookupByLibrary.simpleMessage("Modo de pila"),
    "stackTrace": MessageLookupByLibrary.simpleMessage("Seguimiento de pila"),
    "standard": MessageLookupByLibrary.simpleMessage("Estándar"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "Modo estándar: añade reglas sobre el perfil",
    ),
    "start": MessageLookupByLibrary.simpleMessage("Iniciar"),
    "startFromScratch": MessageLookupByLibrary.simpleMessage(
      "Empezar desde cero",
    ),
    "startVpn": MessageLookupByLibrary.simpleMessage("Iniciando VPN…"),
    "startupAndBackground": MessageLookupByLibrary.simpleMessage(
      "Inicio y segundo plano",
    ),
    "status": MessageLookupByLibrary.simpleMessage("Estado"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "Con DNS desactivado, se usa el DNS del sistema.",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("Detener"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("Deteniendo VPN…"),
    "stopped": MessageLookupByLibrary.simpleMessage("Detenido"),
    "strategy": MessageLookupByLibrary.simpleMessage("Estrategia"),
    "strictRoute": MessageLookupByLibrary.simpleMessage("Ruta estricta"),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "La ruta estricta evita que el tráfico, como el DNS, eluda TUN y, con IPv6 desactivado, bloquea las conexiones IPv6 de este dispositivo.",
    ),
    "style": MessageLookupByLibrary.simpleMessage("Estilo"),
    "styleSettings": MessageLookupByLibrary.simpleMessage("Ajustes de estilo"),
    "submit": MessageLookupByLibrary.simpleMessage("Enviar"),
    "subscriptionInfo": MessageLookupByLibrary.simpleMessage(
      "Información de la suscripción",
    ),
    "sudoPasswordTitle": MessageLookupByLibrary.simpleMessage(
      "Introduce tu contraseña para sudo",
    ),
    "suspendSupport": MessageLookupByLibrary.simpleMessage(
      "Compatibilidad con suspensión",
    ),
    "suspendSupportDesc": MessageLookupByLibrary.simpleMessage(
      "Suspender el núcleo cuando el dispositivo esté inactivo para reducir el consumo de batería",
    ),
    "suspended": MessageLookupByLibrary.simpleMessage("Suspendido…"),
    "swipeToSwitchPage": MessageLookupByLibrary.simpleMessage(
      "Deslizar para cambiar de página",
    ),
    "switchProfile": MessageLookupByLibrary.simpleMessage("Cambiar de perfil"),
    "sync": MessageLookupByLibrary.simpleMessage("Sincronizar"),
    "system": MessageLookupByLibrary.simpleMessage("Sistema"),
    "systemApp": MessageLookupByLibrary.simpleMessage("Apps del sistema"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("Proxy del sistema"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Establecer el proxy HTTP del sistema",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("Pestaña"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage(
      "Animación de pestañas",
    ),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage(
      "Solo tiene efecto en la vista móvil",
    ),
    "tailscaleActive": MessageLookupByLibrary.simpleMessage("Activo"),
    "tailscaleCurrentEndpoint": MessageLookupByLibrary.simpleMessage(
      "Punto de conexión actual",
    ),
    "tailscaleDnsName": MessageLookupByLibrary.simpleMessage("Nombre DNS"),
    "tailscaleEndpoints": MessageLookupByLibrary.simpleMessage(
      "Puntos de conexión",
    ),
    "tailscaleExitNode": MessageLookupByLibrary.simpleMessage("Nodo de salida"),
    "tailscaleExitNodeAvailable": MessageLookupByLibrary.simpleMessage(
      "Nodo de salida disponible",
    ),
    "tailscaleHealth": MessageLookupByLibrary.simpleMessage("Estado de salud"),
    "tailscaleHealthWarnings": MessageLookupByLibrary.simpleMessage(
      "Advertencias de estado",
    ),
    "tailscaleKeyExpired": MessageLookupByLibrary.simpleMessage(
      "Clave caducada",
    ),
    "tailscaleKeyExpiry": MessageLookupByLibrary.simpleMessage(
      "Caducidad de la clave",
    ),
    "tailscaleLastHandshake": MessageLookupByLibrary.simpleMessage(
      "Última negociación",
    ),
    "tailscaleLastSeen": MessageLookupByLibrary.simpleMessage(
      "Última conexión",
    ),
    "tailscaleNeedsMachineAuth": MessageLookupByLibrary.simpleMessage(
      "Se requiere aprobar el dispositivo",
    ),
    "tailscaleNodeKey": MessageLookupByLibrary.simpleMessage("Clave del nodo"),
    "tailscaleRelay": MessageLookupByLibrary.simpleMessage(
      "Retransmisión DERP",
    ),
    "tailscaleSubnets": MessageLookupByLibrary.simpleMessage("Subredes"),
    "tailscaleTags": MessageLookupByLibrary.simpleMessage("Etiquetas"),
    "tapIconToRetry": MessageLookupByLibrary.simpleMessage(
      "Toca el icono para reintentar",
    ),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage(
      "Toca para autorizar",
    ),
    "target": MessageLookupByLibrary.simpleMessage("Destino"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP concurrente"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "Permitir conexiones TCP simultáneas",
    ),
    "testInterval": MessageLookupByLibrary.simpleMessage("Intervalo de prueba"),
    "testUrl": MessageLookupByLibrary.simpleMessage("URL de prueba"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage("Probar al usarse"),
    "textReplacement": MessageLookupByLibrary.simpleMessage(
      "Sustitución de texto:",
    ),
    "textScale": MessageLookupByLibrary.simpleMessage("Escala del texto"),
    "textScalePreview": MessageLookupByLibrary.simpleMessage(
      "Así se verá el texto en la app",
    ),
    "theme": MessageLookupByLibrary.simpleMessage("Tema"),
    "themeColor": MessageLookupByLibrary.simpleMessage("Color del tema"),
    "themeMode": MessageLookupByLibrary.simpleMessage("Modo del tema"),
    "tight": MessageLookupByLibrary.simpleMessage("Ajustado"),
    "time": MessageLookupByLibrary.simpleMessage("Hora"),
    "timeout": MessageLookupByLibrary.simpleMessage("Tiempo agotado"),
    "tintedStyle": MessageLookupByLibrary.simpleMessage("Tintado"),
    "tip": MessageLookupByLibrary.simpleMessage("Consejo"),
    "toggle": MessageLookupByLibrary.simpleMessage("Alternar"),
    "toggleLabel": MessageLookupByLibrary.simpleMessage(
      "Mostrar u ocultar etiquetas",
    ),
    "tolerance": MessageLookupByLibrary.simpleMessage("Tolerancia"),
    "tools": MessageLookupByLibrary.simpleMessage("Herramientas"),
    "torch": MessageLookupByLibrary.simpleMessage("Linterna"),
    "total": MessageLookupByLibrary.simpleMessage("Total"),
    "totalDownload": MessageLookupByLibrary.simpleMessage("Descargado"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("Tráfico total"),
    "totalUpload": MessageLookupByLibrary.simpleMessage("Subido"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Puerto TProxy"),
    "traffic": MessageLookupByLibrary.simpleMessage("Tráfico"),
    "trafficBoth": MessageLookupByLibrary.simpleMessage("Ambos"),
    "trafficPeak": m81,
    "trafficTotal": m82,
    "trafficUsage": MessageLookupByLibrary.simpleMessage("Uso de tráfico"),
    "transport": MessageLookupByLibrary.simpleMessage("Transporte"),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunAuthorizationFailed": MessageLookupByLibrary.simpleMessage(
      "No se pudo autorizar TUN, por lo que se desactivó.",
    ),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "TUN solo funciona en modo administrador.",
    ),
    "tunDnsMode": MessageLookupByLibrary.simpleMessage("Modo DNS del sistema"),
    "tunDnsModeDisabled": MessageLookupByLibrary.simpleMessage("Desactivado"),
    "tunDnsModeHijack": MessageLookupByLibrary.simpleMessage("Intercepción"),
    "tunDnsModeNative": MessageLookupByLibrary.simpleMessage("Nativo"),
    "tunOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Las entradas añadidas aquí sustituyen los ajustes de TUN de todos los perfiles; lo que no añadas conserva el ajuste del propio perfil. Las entradas que añade un perfil personalizado tienen prioridad.",
    ),
    "turnOff": MessageLookupByLibrary.simpleMessage("Desactivar"),
    "turnOn": MessageLookupByLibrary.simpleMessage("Activar"),
    "tvMode": MessageLookupByLibrary.simpleMessage("Modo TV"),
    "tvModeDesc": MessageLookupByLibrary.simpleMessage(
      "Usar en este dispositivo una interfaz adaptada al mando a distancia",
    ),
    "udpRelayMode": MessageLookupByLibrary.simpleMessage(
      "Modo de retransmisión UDP",
    ),
    "udpTimeout": MessageLookupByLibrary.simpleMessage("Tiempo de espera UDP"),
    "udpTimeoutDesc": MessageLookupByLibrary.simpleMessage(
      "El tiempo de espera UDP se indica en segundos y solo funciona con las pilas gvisor, system y mixed.",
    ),
    "uiUpdateIdleInterval": MessageLookupByLibrary.simpleMessage(
      "Intervalo de actualización en inactividad",
    ),
    "uiUpdateIdleWhenUnfocused": MessageLookupByLibrary.simpleMessage(
      "Reducir la frecuencia al perder el foco",
    ),
    "uiUpdateIdleWhenUnfocusedDesc": MessageLookupByLibrary.simpleMessage(
      "Usar el intervalo de inactividad cuando la ventana pierda el foco",
    ),
    "uiUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Intervalo de actualización de la información de la interfaz",
    ),
    "uiUpdateIntervalDesc": m83,
    "uiUpdateIntervalIdleDisabledDesc": m84,
    "ultra": MessageLookupByLibrary.simpleMessage("Ultra"),
    "unauthorized": MessageLookupByLibrary.simpleMessage("No autorizado"),
    "undo": MessageLookupByLibrary.simpleMessage("Deshacer"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("Latencia unificada"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "Eliminar retrasos adicionales, como los de negociación",
    ),
    "uninitialized": MessageLookupByLibrary.simpleMessage("Sin inicializar"),
    "unknown": MessageLookupByLibrary.simpleMessage("Desconocido"),
    "unknownBackupVariable": MessageLookupByLibrary.simpleMessage(
      "Variable desconocida. Elige una de las variables siguientes.",
    ),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage(
      "Error de red desconocido",
    ),
    "unmaximize": MessageLookupByLibrary.simpleMessage("Restaurar tamaño"),
    "unnamed": MessageLookupByLibrary.simpleMessage("Sin nombre"),
    "unpinWindow": MessageLookupByLibrary.simpleMessage("Desfijar ventana"),
    "update": MessageLookupByLibrary.simpleMessage("Actualizar"),
    "updateChecksumMismatch": MessageLookupByLibrary.simpleMessage(
      "El archivo descargado no coincide con la suma de verificación publicada y se ha descartado.",
    ),
    "updateDownloading": MessageLookupByLibrary.simpleMessage(
      "Descargando actualización",
    ),
    "updateInstallFailed": MessageLookupByLibrary.simpleMessage(
      "No se pudo iniciar el instalador.",
    ),
    "updateInstallPermission": MessageLookupByLibrary.simpleMessage(
      "No se autorizó a FlClash a instalar aplicaciones, por lo que no se instaló la actualización.",
    ),
    "updateNotWritable": MessageLookupByLibrary.simpleMessage(
      "FlClash no puede escribir en su carpeta de instalación. Descarga la actualización manualmente.",
    ),
    "updateNow": MessageLookupByLibrary.simpleMessage("Actualizar ahora"),
    "upload": MessageLookupByLibrary.simpleMessage("Subida"),
    "uploadBandwidth": MessageLookupByLibrary.simpleMessage(
      "Ancho de banda de subida",
    ),
    "uploadSpeed": MessageLookupByLibrary.simpleMessage("Velocidad de subida"),
    "uploadTraffic": MessageLookupByLibrary.simpleMessage("Tráfico de subida"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage(
      "Obtener un perfil desde una URL",
    ),
    "urlTip": m85,
    "useHosts": MessageLookupByLibrary.simpleMessage("Usar hosts"),
    "useHostsDesc": MessageLookupByLibrary.simpleMessage(
      "Consultar las entradas hosts de la configuración antes de los servidores DNS de origen",
    ),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage(
      "Usar hosts del sistema",
    ),
    "useSystemHostsDesc": MessageLookupByLibrary.simpleMessage(
      "Consultar el archivo hosts del sistema operativo al resolver dominios",
    ),
    "usedShort": MessageLookupByLibrary.simpleMessage("usado"),
    "usedTraffic": MessageLookupByLibrary.simpleMessage("Tráfico usado"),
    "userAgent": MessageLookupByLibrary.simpleMessage("User-Agent"),
    "username": MessageLookupByLibrary.simpleMessage("Usuario"),
    "value": MessageLookupByLibrary.simpleMessage("Valor"),
    "version": MessageLookupByLibrary.simpleMessage("Versión"),
    "view": MessageLookupByLibrary.simpleMessage("Ver"),
    "virtualIpv4": MessageLookupByLibrary.simpleMessage("IPv4 virtual"),
    "vividStyle": MessageLookupByLibrary.simpleMessage("Vivo"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "Se detectó un cambio en la configuración relacionada con la VPN",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "La VPN enruta automáticamente todo el tráfico del sistema a través de VpnService.",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage(
      "Configuración de WebDAV",
    ),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("Modo lista blanca"),
    "writeToSystem": MessageLookupByLibrary.simpleMessage(
      "Escribir en el sistema",
    ),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage(
      "Escribir en el sistema también ajusta el reloj del sistema; Android lo ignora.",
    ),
    "yearsAgo": m86,
    "yearsAgoShort": m87,
    "yes": MessageLookupByLibrary.simpleMessage("Sí"),
    "zhCN": MessageLookupByLibrary.simpleMessage("Chino simplificado"),
    "zhTW": MessageLookupByLibrary.simpleMessage("Chino tradicional"),
    "zolnitActivating": MessageLookupByLibrary.simpleMessage("Activando"),
    "zolnitAdvanced": MessageLookupByLibrary.simpleMessage("Ajustes avanzados"),
    "zolnitAllNodes": MessageLookupByLibrary.simpleMessage("Todos los nodos"),
    "zolnitAmountDue": MessageLookupByLibrary.simpleMessage("Importe a pagar"),
    "zolnitBilledMonthly": MessageLookupByLibrary.simpleMessage(
      "Pago mensual, para empezar sin complicaciones",
    ),
    "zolnitBilledOnce": m88,
    "zolnitBillingUnavailable": MessageLookupByLibrary.simpleMessage(
      "Los datos de renovación no están disponibles temporalmente.",
    ),
    "zolnitBuy": MessageLookupByLibrary.simpleMessage("Crear pedido"),
    "zolnitCancelOrder": MessageLookupByLibrary.simpleMessage(
      "Cancelar pedido",
    ),
    "zolnitCancelOrderTip": MessageLookupByLibrary.simpleMessage(
      "¿Cancelar este pedido sin pagar?",
    ),
    "zolnitCancelRenewal": MessageLookupByLibrary.simpleMessage(
      "Cancelar renovación automática",
    ),
    "zolnitCancelRenewalTip": MessageLookupByLibrary.simpleMessage(
      "Se detendrán los próximos cargos automáticos. También se cancelará un primer pedido sin pagar. El acceso ya pagado depende del resultado del servidor.",
    ),
    "zolnitCanceled": MessageLookupByLibrary.simpleMessage("Cancelado"),
    "zolnitCheckoutExists": MessageLookupByLibrary.simpleMessage(
      "Ya hay un pago en curso. Consulta su estado en Cuenta y no lo envíes de nuevo.",
    ),
    "zolnitCheckoutProcessing": MessageLookupByLibrary.simpleMessage(
      "El pago se está preparando o verificando. Inténtalo de nuevo en unos instantes.",
    ),
    "zolnitChoosePlan": MessageLookupByLibrary.simpleMessage("Elegir plan"),
    "zolnitCompleted": MessageLookupByLibrary.simpleMessage("Completado"),
    "zolnitConnectHeadline": MessageLookupByLibrary.simpleMessage(
      "Un toque y conectado al instante",
    ),
    "zolnitConnectSub": MessageLookupByLibrary.simpleMessage(
      "Elige tu ruta y deja el resto en manos de ZolNit.",
    ),
    "zolnitCredentialsInvalid": MessageLookupByLibrary.simpleMessage(
      "Introduce un correo válido y una contraseña de al menos ocho caracteres.",
    ),
    "zolnitCredited": MessageLookupByLibrary.simpleMessage("Compensado"),
    "zolnitCurrentBadge": MessageLookupByLibrary.simpleMessage("Plan actual"),
    "zolnitCurrentPlanHint": m89,
    "zolnitCurrentPlanLine": m90,
    "zolnitCurrentSelection": MessageLookupByLibrary.simpleMessage(
      "Seleccionado",
    ),
    "zolnitCycleHalfYear": MessageLookupByLibrary.simpleMessage("semestre"),
    "zolnitCycleQuarter": MessageLookupByLibrary.simpleMessage("trimestre"),
    "zolnitCycleThreeYears": MessageLookupByLibrary.simpleMessage("3 años"),
    "zolnitCycleTwoYears": MessageLookupByLibrary.simpleMessage("2 años"),
    "zolnitCycleYear": MessageLookupByLibrary.simpleMessage("año"),
    "zolnitDaysLeftLabel": m91,
    "zolnitDaysUnit": MessageLookupByLibrary.simpleMessage("días"),
    "zolnitEmail": MessageLookupByLibrary.simpleMessage("Correo electrónico"),
    "zolnitEveryScreen": MessageLookupByLibrary.simpleMessage(
      "Una experiencia familiar en cada pantalla",
    ),
    "zolnitExpiresOn": m92,
    "zolnitFailure": MessageLookupByLibrary.simpleMessage(
      "No se pudo completar la solicitud. Comprueba los datos o la conexión e inténtalo de nuevo.",
    ),
    "zolnitFeatureDevices": m93,
    "zolnitFeatureSpeed": m94,
    "zolnitFeatureTraffic": m95,
    "zolnitFirstCharge": MessageLookupByLibrary.simpleMessage("Primer pago"),
    "zolnitFollowingCharge": MessageLookupByLibrary.simpleMessage(
      "Pagos posteriores",
    ),
    "zolnitGift": MessageLookupByLibrary.simpleMessage("Acceso de regalo"),
    "zolnitGiftReplacement": MessageLookupByLibrary.simpleMessage(
      "El periodo de pago comienza al confirmar el primer pago y sustituye el tiempo gratuito restante.",
    ),
    "zolnitGlobalRoutes": MessageLookupByLibrary.simpleMessage(
      "Rutas globales seleccionadas",
    ),
    "zolnitGreeting": m96,
    "zolnitGreetingSub": MessageLookupByLibrary.simpleMessage(
      "Listo para descubrir un mundo más grande.",
    ),
    "zolnitHalfYearly": MessageLookupByLibrary.simpleMessage("Cada seis meses"),
    "zolnitHelpSupport": MessageLookupByLibrary.simpleMessage(
      "Ayuda y soporte",
    ),
    "zolnitLatency": MessageLookupByLibrary.simpleMessage("Latencia"),
    "zolnitLatestNotices": MessageLookupByLibrary.simpleMessage(
      "Últimos avisos",
    ),
    "zolnitLoginDescription": MessageLookupByLibrary.simpleMessage(
      "Olvida los ajustes complicados. Tu mundo está a una conexión.",
    ),
    "zolnitLoginEyebrow": MessageLookupByLibrary.simpleMessage(
      "Un poco más cerca de tu mundo",
    ),
    "zolnitLoginSubtitle": MessageLookupByLibrary.simpleMessage(
      "Inicia sesión para gestionar tu plan y tus conexiones.",
    ),
    "zolnitLoginWebsite": MessageLookupByLibrary.simpleMessage(
      "Registrarse o recuperar la contraseña",
    ),
    "zolnitMembershipEyebrow": MessageLookupByLibrary.simpleMessage(
      "YOUR MEMBERSHIP",
    ),
    "zolnitModeGlobal": MessageLookupByLibrary.simpleMessage("Global"),
    "zolnitModeSmart": MessageLookupByLibrary.simpleMessage(
      "Enrutamiento inteligente",
    ),
    "zolnitMonthly": MessageLookupByLibrary.simpleMessage("Mensual"),
    "zolnitMonthlyEnrollment": MessageLookupByLibrary.simpleMessage(
      "Facturación mensual automática",
    ),
    "zolnitMySpace": MessageLookupByLibrary.simpleMessage("Mi espacio"),
    "zolnitNextRenewal": MessageLookupByLibrary.simpleMessage(
      "Próxima renovación",
    ),
    "zolnitNoCurrentPlanHint": MessageLookupByLibrary.simpleMessage(
      "Aún no tienes ningún plan activo. Elige uno abajo para empezar.",
    ),
    "zolnitNoMethods": MessageLookupByLibrary.simpleMessage(
      "No hay métodos de pago disponibles",
    ),
    "zolnitNoNodes": MessageLookupByLibrary.simpleMessage(
      "No hay nodos disponibles para esta suscripción.",
    ),
    "zolnitNoNotices": MessageLookupByLibrary.simpleMessage(
      "Aún no hay avisos",
    ),
    "zolnitNoOrders": MessageLookupByLibrary.simpleMessage(
      "Aún no hay pedidos",
    ),
    "zolnitNoPlan": MessageLookupByLibrary.simpleMessage(
      "No hay ningún plan activo",
    ),
    "zolnitNoRenewals": MessageLookupByLibrary.simpleMessage(
      "No hay contratos de renovación automática",
    ),
    "zolnitNodeName": MessageLookupByLibrary.simpleMessage("Nodo"),
    "zolnitNotConnected": MessageLookupByLibrary.simpleMessage(
      "Aún sin conexión",
    ),
    "zolnitNotices": MessageLookupByLibrary.simpleMessage("Avisos"),
    "zolnitOneTime": MessageLookupByLibrary.simpleMessage("Pago único"),
    "zolnitOnlineDevices": MessageLookupByLibrary.simpleMessage(
      "Dispositivos en línea",
    ),
    "zolnitOrders": MessageLookupByLibrary.simpleMessage("Pedidos"),
    "zolnitOutOfDevices": m97,
    "zolnitPaid": MessageLookupByLibrary.simpleMessage("Acceso pagado"),
    "zolnitPaidThrough": MessageLookupByLibrary.simpleMessage(
      "Acceso pagado hasta",
    ),
    "zolnitPay": MessageLookupByLibrary.simpleMessage("Pagar pedido"),
    "zolnitPaymentReturn": MessageLookupByLibrary.simpleMessage(
      "El estado del pedido debe confirmarse al volver del pago.",
    ),
    "zolnitPaymentStatus": MessageLookupByLibrary.simpleMessage(
      "Estado del pago",
    ),
    "zolnitPaymentUnavailable": MessageLookupByLibrary.simpleMessage(
      "Este método de pago aún no está disponible.",
    ),
    "zolnitPending": MessageLookupByLibrary.simpleMessage("Pendiente de pago"),
    "zolnitPendingOrder": MessageLookupByLibrary.simpleMessage(
      "Tienes un pedido pendiente. Continúa el pago o ciérralo en Pedidos antes de hacer otro.",
    ),
    "zolnitPerMonth": MessageLookupByLibrary.simpleMessage("/ mes"),
    "zolnitPlanSwitch": MessageLookupByLibrary.simpleMessage(
      "El nuevo plan comienza al confirmar el primer pago o el crédito del valor restante.",
    ),
    "zolnitPlanValidity": MessageLookupByLibrary.simpleMessage(
      "Vigencia del plan",
    ),
    "zolnitPlans": MessageLookupByLibrary.simpleMessage("Planes"),
    "zolnitPlansHeadline": MessageLookupByLibrary.simpleMessage(
      "El plan justo, la libertad justa.",
    ),
    "zolnitPlansSub": MessageLookupByLibrary.simpleMessage(
      "Desde la navegación diaria hasta el streaming fluido, elige la conexión que mejor te encaje.",
    ),
    "zolnitPreferences": MessageLookupByLibrary.simpleMessage("Preferencias"),
    "zolnitProfileSource": MessageLookupByLibrary.simpleMessage(
      "Los nodos y las reglas de enrutamiento se sincronizan automáticamente desde ZolNit.",
    ),
    "zolnitQuarterly": MessageLookupByLibrary.simpleMessage("Trimestral"),
    "zolnitQuoteBeforeConsent": MessageLookupByLibrary.simpleMessage(
      "Revisa la cotización del servidor antes de autorizar la renovación automática.",
    ),
    "zolnitQuoteExpired": MessageLookupByLibrary.simpleMessage(
      "La cotización ha caducado. Vuelve a Planes y elige de nuevo.",
    ),
    "zolnitRateLimited": MessageLookupByLibrary.simpleMessage(
      "Demasiados intentos. Inténtalo de nuevo en un momento.",
    ),
    "zolnitRecommendedNodes": MessageLookupByLibrary.simpleMessage(
      "Nodos recomendados",
    ),
    "zolnitRecommendedNodesSub": MessageLookupByLibrary.simpleMessage(
      "Primero los más cercanos, para conectar más rápido",
    ),
    "zolnitRecommendedRoute": MessageLookupByLibrary.simpleMessage(
      "Recomendado",
    ),
    "zolnitRecurringConsent": MessageLookupByLibrary.simpleMessage(
      "Acepto los pagos recurrentes de este plan según las condiciones mostradas del primer pago y las renovaciones.",
    ),
    "zolnitRecurringUnavailable": MessageLookupByLibrary.simpleMessage(
      "La facturación mensual automática no está disponible para este plan por ahora.",
    ),
    "zolnitRefresh": MessageLookupByLibrary.simpleMessage("Actualizar"),
    "zolnitRenewCurrent": MessageLookupByLibrary.simpleMessage(
      "Renovar el plan actual",
    ),
    "zolnitRenewPlan": MessageLookupByLibrary.simpleMessage("Renovar plan"),
    "zolnitRenewals": MessageLookupByLibrary.simpleMessage(
      "Renovación automática",
    ),
    "zolnitResetInDays": m98,
    "zolnitResetTraffic": MessageLookupByLibrary.simpleMessage(
      "Restablecer tráfico",
    ),
    "zolnitResumeRenewal": MessageLookupByLibrary.simpleMessage(
      "Reanudar renovación automática",
    ),
    "zolnitResumeRenewalTip": MessageLookupByLibrary.simpleMessage(
      "Reanudar los cargos automáticos según el plan autorizado.",
    ),
    "zolnitSafeModeConnect": MessageLookupByLibrary.simpleMessage(
      "El modo seguro nunca modifica la red del sistema.",
    ),
    "zolnitSavePercent": m99,
    "zolnitSelectColumn": MessageLookupByLibrary.simpleMessage("Seleccionar"),
    "zolnitSessionOnly": MessageLookupByLibrary.simpleMessage(
      "La sesión permanecerá abierta hasta que cierres la aplicación.",
    ),
    "zolnitSignIn": MessageLookupByLibrary.simpleMessage("Iniciar sesión"),
    "zolnitSignOut": MessageLookupByLibrary.simpleMessage("Cerrar sesión"),
    "zolnitStatusActive": MessageLookupByLibrary.simpleMessage("Activo"),
    "zolnitStatusExpired": MessageLookupByLibrary.simpleMessage("Caducado"),
    "zolnitStatusNoPlan": MessageLookupByLibrary.simpleMessage("Sin plan"),
    "zolnitSubscribePlan": MessageLookupByLibrary.simpleMessage(
      "Elegir un plan",
    ),
    "zolnitSync": MessageLookupByLibrary.simpleMessage(
      "Sincronizar perfil de conexión",
    ),
    "zolnitSynced": MessageLookupByLibrary.simpleMessage(
      "Perfil de conexión sincronizado",
    ),
    "zolnitSyncing": MessageLookupByLibrary.simpleMessage(
      "Sincronizando perfil de conexión…",
    ),
    "zolnitTagline": MessageLookupByLibrary.simpleMessage(
      "Conectarse vuelve a ser sencillo.",
    ),
    "zolnitThreeYearly": MessageLookupByLibrary.simpleMessage("Cada tres años"),
    "zolnitTrafficLeft": MessageLookupByLibrary.simpleMessage(
      "Tráfico restante",
    ),
    "zolnitTrafficUsed": MessageLookupByLibrary.simpleMessage(
      "Usado en este ciclo",
    ),
    "zolnitTwoYearly": MessageLookupByLibrary.simpleMessage("Cada dos años"),
    "zolnitViewMonthlyQuote": MessageLookupByLibrary.simpleMessage(
      "Ver cotización mensual",
    ),
    "zolnitWebsite": MessageLookupByLibrary.simpleMessage(
      "Abrir el sitio de ZolNit",
    ),
    "zolnitWelcome": MessageLookupByLibrary.simpleMessage(
      "Te damos la bienvenida",
    ),
    "zolnitWorkspace": MessageLookupByLibrary.simpleMessage("YOUR WORKSPACE"),
    "zolnitYearly": MessageLookupByLibrary.simpleMessage("Anual"),
  };
}
