// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a fr locale. All the
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
  String get localeName => 'fr';

  static String m0(count, skipped) =>
      "${count} à ajouter, ${skipped} ignorés car déjà présents";

  static String m1(detail) => "Impossible d’effacer les données : ${detail}";

  static String m2(code) =>
      "Windows a refusé d’exécuter FlClashCore.exe (erreur ${code}). Une stratégie de contrôle des applications, telle que Smart App Control ou AppLocker, bloque les programmes non signés ; autorisez FlClash dans cette stratégie ou désactivez-la, puis réessayez.";

  static String m3(name) =>
      "L’app n’a pas réussi à finir de démarrer deux fois de suite. Pour sortir de cette boucle, le profil ${name} a été désélectionné et la configuration automatique a été ignorée. Vous pouvez le sélectionner de nouveau à tout moment.";

  static String m4(url) => "Créer un profil à partir de ${url} ?";

  static String m5(count, label) =>
      "${Intl.plural(count, one: '1 règle SUB-RULE a été abandonnée, car les profils personnalisés ne prennent pas en charge les sous-règles', other: '${label} règles SUB-RULE ont été abandonnées, car les profils personnalisés ne prennent pas en charge les sous-règles')}";

  static String m6(message) =>
      "Le cœur ne peut pas analyser ce proxy : ${message}";

  static String m7(proxy, target) =>
      "${proxy} se connecte via ${target}, qui renvoie à ${proxy} ; la connexion boucle";

  static String m8(name) =>
      "Le nom ${name} est déjà utilisé par un autre proxy ou groupe de proxys";

  static String m9(path) =>
      "Les groupes de proxys se référencent mutuellement en boucle : ${path}";

  static String m10(name) =>
      "Le repli si vide doit être un proxy, mais ${name} n’existe pas ou est un groupe de proxys";

  static String m11(name, message) =>
      "${name} n’est pas une regex valide : ${message}";

  static String m12(name) => "Le proxy de connexion ${name} n’existe pas";

  static String m13(names) =>
      "Ces fournisseurs de proxys n’existent pas : ${names}";

  static String m14(names) =>
      "Ces proxys ou stratégies n’existent pas : ${names}";

  static String m15(name) =>
      "${name} est un nom de stratégie intégré et ne peut pas être utilisé ici";

  static String m16(count) =>
      "${count} éléments posent problème, et l’application de ce profil peut échouer";

  static String m17(count) =>
      "${Intl.plural(count, one: 'il y a 1 jour', other: 'il y a ${count} jours')}";

  static String m18(count) =>
      "${Intl.plural(count, other: 'il y a ${count} j')}";

  static String m19(label) =>
      "Voulez-vous vraiment supprimer les éléments sélectionnés (${label}) ?";

  static String m20(label) =>
      "Voulez-vous vraiment supprimer cet élément (${label}) ?";

  static String m21(label) => "Détails de ${label}";

  static String m22(name) =>
      "La connexion via ${name} renvoie au proxy qui l’utilise ; la connexion a donc été arrêtée";

  static String m23(label) => "${label} ne peut pas être vide";

  static String m24(count) =>
      "${Intl.plural(count, one: '1 entrée', other: '${count} entrées')}";

  static String m25(label) => "${label} existe déjà";

  static String m26(count) => "${count} éléments en échec";

  static String m27(label, message) => "${label} : ${message}";

  static String m28(name) => "${name} est déjà à jour";

  static String m29(name) => "${name} mis à jour";

  static String m30(name) => "Mise à jour de ${name}…";

  static String m31(count) =>
      "${Intl.plural(count, one: '1 groupe', other: '${count} groupes')}";

  static String m32(count) => "${count} expirés";

  static String m33(action) =>
      "Déjà utilisé par « ${action} ». L’enregistrer le déplace ici.";

  static String m34(modifiers) =>
      "Incluez au moins l’une de ces touches : ${modifiers}";

  static String m35(count) =>
      "${Intl.plural(count, one: 'il y a 1 heure', other: 'il y a ${count} heures')}";

  static String m36(count) =>
      "${Intl.plural(count, other: 'il y a ${count} h')}";

  static String m37(target) => "${target} n’est pas une stratégie valide";

  static String m38(proxyName) => "${proxyName} n’est pas un proxy valide";

  static String m39(providerName) =>
      "${providerName} n’est pas un fournisseur de proxys valide";

  static String m40(ruleSet) => "${ruleSet} n’est pas un jeu de règles valide";

  static String m41(subRule) => "${subRule} n’est pas un SUB_RULE valide";

  static String m42(count) =>
      "${Intl.plural(count, one: '1 élément', other: '${count} éléments')}";

  static String m43(line, message) => "Ligne ${line} : ${message}";

  static String m44(appName) =>
      "1. Ouvrez Réglages système > Confidentialité et sécurité\n2. Choisissez Service de localisation\n3. Trouvez ${appName} dans la liste et cochez-le\n\nUne fois terminé, revenez dans l’app pour continuer. Merci de votre coopération.";

  static String m45(label, max) =>
      "${label} ne doit pas dépasser ${max} caractères";

  static String m46(size) => "${size} libérés";

  static String m47(count) =>
      "${Intl.plural(count, one: 'il y a 1 minute', other: 'il y a ${count} minutes')}";

  static String m48(count) =>
      "${Intl.plural(count, other: 'il y a ${count} min')}";

  static String m49(count) =>
      "${Intl.plural(count, one: 'il y a 1 mois', other: 'il y a ${count} mois')}";

  static String m50(count) =>
      "${Intl.plural(count, other: 'il y a ${count} m')}";

  static String m51(code) =>
      "Le serveur a refusé l’accès (HTTP ${code}). Le lien a peut-être expiré, ou les identifiants sont incorrects";

  static String m52(code) => "Le serveur a rejeté la requête (HTTP ${code})";

  static String m53(code) =>
      "Rien n’a été trouvé à cette adresse (HTTP ${code}). Vérifiez que l’URL est correcte";

  static String m54(detail) => "Échec de la requête réseau : ${detail}";

  static String m55(code) =>
      "Le serveur a rencontré un problème (HTTP ${code}). Réessayez plus tard";

  static String m56(label) => "Aucun élément (${label}) pour le moment";

  static String m57(label, min, max) =>
      "${label} doit être compris entre ${min} et ${max}";

  static String m58(label) => "${label} doit être un nombre";

  static String m59(label) => "${label} doit être compris entre 1024 et 49151";

  static String m60(port) => "Port ${port}";

  static String m61(days) =>
      "${Intl.plural(days, one: '1 jour restant', other: '${days} jours restants')}";

  static String m62(date, days) =>
      "Expire le ${date}, ${Intl.plural(days, one: '1 jour restant', other: '${days} jours restants')}";

  static String m63(time) => "Mis à jour ${time}";

  static String m64(label, profiles) =>
      "${label} est encore utilisé par ${profiles}, qui ne fonctionneront plus correctement s’il est supprimé. Voulez-vous vraiment le supprimer ?";

  static String m65(count, label) =>
      "${Intl.plural(count, one: '1 proxy', other: '${label} proxys')}";

  static String m66(name, count) => "${name} et autres (${count} proxys)";

  static String m67(removed) =>
      "Ces proxys seront supprimés : ${removed}. Une ligne dont le nom a changé compte comme un nouveau proxy, et les profils personnalisés qui nomment les proxys supprimés les signaleront comme manquants. Appliquer quand même ?";

  static String m68(removed, added) =>
      "Ces proxys seront supprimés : ${removed}. Ceux-ci seront ajoutés : ${added}. Une ligne dont le nom a changé compte comme un nouveau proxy, et les profils personnalisés qui nomment les proxys supprimés les signaleront comme manquants. Appliquer quand même ?";

  static String m69(label) =>
      "${label} est encore nommé par des règles, des groupes de proxys, des proxys de connexion, le DNS ou le NTP de ce profil, qui cesseront de fonctionner s’il est supprimé. Voulez-vous vraiment le supprimer ?";

  static String m70(count, label) =>
      "${Intl.plural(count, one: '1 groupe de proxys', other: '${label} groupes de proxys')}";

  static String m71(maximum) => "Saisissez un entier entre 0 et ${maximum}.";

  static String m72(count, label) =>
      "${Intl.plural(count, one: '1 règle', other: '${label} règles')}";

  static String m73(appName) => "${appName} (mode sans échec)";

  static String m74(count) =>
      "${Intl.plural(count, one: '1 seconde', other: '${count} secondes')}";

  static String m75(count) => "${count} actifs";

  static String m76(count) =>
      "${Intl.plural(count, one: '1 problème', other: '${count} problèmes')}";

  static String m77(time) => "Vérifié à ${time}";

  static String m78(count) =>
      "${Intl.plural(count, one: '1 réglage', other: '${count} réglages')}";

  static String m79(link) => "Aucun proxy n’a pu être lu dans ${link}";

  static String m80(label) => "${label} doit être un seul élément";

  static String m81(value) => "Pic ${value}";

  static String m82(value) => "Total ${value}";

  static String m83(interval, idleInterval) =>
      "${interval} · Inactif ${idleInterval}";

  static String m84(interval) => "${interval} · Ralentissement désactivé";

  static String m85(label) => "${label} doit être une URL";

  static String m86(count) =>
      "${Intl.plural(count, one: 'il y a 1 an', other: 'il y a ${count} ans')}";

  static String m87(count) =>
      "${Intl.plural(count, other: 'il y a ${count} a')}";

  static String m88(amount, cycle) =>
      "${amount} pour ${cycle}, payé en une fois";

  static String m89(date) =>
      "Expire le ${date}. Passez à une offre supérieure ou renouvelez ici.";

  static String m90(plan) => "Forfait actuel · ${plan}";

  static String m91(days) => "${days} jours restants";

  static String m92(date) => "Expire le ${date}";

  static String m93(count) =>
      "Jusqu’à ${count} appareils en ligne simultanément";

  static String m94(mbps) => "Débit jusqu’à ${mbps} Mbit/s";

  static String m95(gb) => "${gb} Go de données haut débit par mois";

  static String m96(name) => "Bonjour, ${name}.";

  static String m97(rate) => "Mesure ${rate}×";

  static String m98(count) => "Serveurs : ${count}";

  static String m99(count) => "/ ${count}";

  static String m100(days) => "Réinitialisation dans ${days} jours";

  static String m101(node) => "Trajet actuel : ${node}";

  static String m102(percent) => "Économisez ${percent} %";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("À propos"),
    "accessControl": MessageLookupByLibrary.simpleMessage("Contrôle d’accès"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Seules les apps sélectionnées passent par le VPN",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "Le contrôle d’accès choisit les apps qui utilisent le proxy.",
    ),
    "accessControlDisabledDesc": MessageLookupByLibrary.simpleMessage(
      "Le contrôle d’accès des apps est désactivé",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Les apps sélectionnées sont exclues du VPN",
    ),
    "accessControlSettings": MessageLookupByLibrary.simpleMessage(
      "Réglages du contrôle d’accès",
    ),
    "accessDenied": MessageLookupByLibrary.simpleMessage("Accès refusé"),
    "account": MessageLookupByLibrary.simpleMessage("Compte"),
    "action": MessageLookupByLibrary.simpleMessage("Action"),
    "actionDelayTest": MessageLookupByLibrary.simpleMessage(
      "Tester tous les délais",
    ),
    "actionDirectMode": MessageLookupByLibrary.simpleMessage("Mode direct"),
    "actionGlobalMode": MessageLookupByLibrary.simpleMessage("Mode global"),
    "actionMode": MessageLookupByLibrary.simpleMessage("Changer de mode"),
    "actionProxy": MessageLookupByLibrary.simpleMessage("Proxy système"),
    "actionRuleMode": MessageLookupByLibrary.simpleMessage("Mode règles"),
    "actionStart": MessageLookupByLibrary.simpleMessage("Démarrer/Arrêter"),
    "actionTun": MessageLookupByLibrary.simpleMessage("TUN"),
    "actionUpdateProfiles": MessageLookupByLibrary.simpleMessage(
      "Mettre à jour les profils",
    ),
    "actionView": MessageLookupByLibrary.simpleMessage("Afficher/Masquer"),
    "add": MessageLookupByLibrary.simpleMessage("Ajouter"),
    "addCustomProxy": MessageLookupByLibrary.simpleMessage("Ajouter un proxy"),
    "addFilters": MessageLookupByLibrary.simpleMessage("Ajouter des filtres"),
    "addNodes": MessageLookupByLibrary.simpleMessage("Ajouter des nœuds"),
    "addOverrideEntry": MessageLookupByLibrary.simpleMessage(
      "Ajouter une entrée de remplacement",
    ),
    "addProfile": MessageLookupByLibrary.simpleMessage("Ajouter un profil"),
    "addProxies": MessageLookupByLibrary.simpleMessage("Ajouter des proxys"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Ajouter un groupe de proxys",
    ),
    "addRule": MessageLookupByLibrary.simpleMessage("Ajouter une règle"),
    "addSettingEntry": MessageLookupByLibrary.simpleMessage(
      "Ajouter un réglage",
    ),
    "addSsid": MessageLookupByLibrary.simpleMessage("Ajouter un SSID"),
    "addedRules": MessageLookupByLibrary.simpleMessage("Règles ajoutées"),
    "additionalParameters": MessageLookupByLibrary.simpleMessage(
      "Paramètres supplémentaires",
    ),
    "additionalPrefix": MessageLookupByLibrary.simpleMessage("Préfixe du nom"),
    "additionalSuffix": MessageLookupByLibrary.simpleMessage("Suffixe du nom"),
    "address": MessageLookupByLibrary.simpleMessage("Adresse"),
    "addressHelp": MessageLookupByLibrary.simpleMessage(
      "Adresse du serveur WebDAV",
    ),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "Veuillez saisir une adresse WebDAV valide",
    ),
    "advancedConfig": MessageLookupByLibrary.simpleMessage(
      "Configuration avancée",
    ),
    "advancedConfigDesc": MessageLookupByLibrary.simpleMessage(
      "La configuration avancée regroupe le réseau, le DNS, les règles ajoutées et les scripts.",
    ),
    "ageEncryptedProfile": MessageLookupByLibrary.simpleMessage(
      "Profil chiffré",
    ),
    "ageKeyGenerateTitle": MessageLookupByLibrary.simpleMessage(
      "Génération de clé Age",
    ),
    "ageKeyPairGeneratedSuccess": MessageLookupByLibrary.simpleMessage(
      "Paire de clés X25519 générée. Conservez-la en lieu sûr",
    ),
    "agePrivateKeyLabel": MessageLookupByLibrary.simpleMessage(
      "Clé privée Age",
    ),
    "agePrivateKeyRequired": MessageLookupByLibrary.simpleMessage(
      "Saisissez d’abord une clé privée Age correcte",
    ),
    "agePublicKeyLabel": MessageLookupByLibrary.simpleMessage(
      "Clé publique Age",
    ),
    "ageSecretKey": MessageLookupByLibrary.simpleMessage("Clé secrète age"),
    "ageSecretKeyInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Saisissez une clé secrète Age valide (commençant par AGE-SECRET-KEY-)",
    ),
    "ageSecretKeyOptional": MessageLookupByLibrary.simpleMessage(
      "Clé secrète Age (facultative)",
    ),
    "ageSecretKeyRequiredTip": MessageLookupByLibrary.simpleMessage(
      "Ce profil est chiffré avec age et nécessite une clé secrète age pour être déchiffré",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("Accepter"),
    "allData": MessageLookupByLibrary.simpleMessage("Toutes les données"),
    "allReferencedProxies": MessageLookupByLibrary.simpleMessage(
      "Tous les proxys référencés",
    ),
    "allReferencedProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Tous les fournisseurs de proxys référencés",
    ),
    "allowBypass": MessageLookupByLibrary.simpleMessage(
      "Autoriser les apps à contourner le VPN",
    ),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "Permettre à certaines applications de contourner le VPN",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("Autoriser le LAN"),
    "allowLanAccess": MessageLookupByLibrary.simpleMessage(
      "Autoriser l’accès LAN",
    ),
    "allowLanAccessDesc": MessageLookupByLibrary.simpleMessage(
      "Autoriser l’accès au contrôleur externe depuis le réseau local",
    ),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage(
      "Autoriser l’accès au proxy sur le réseau local",
    ),
    "allowedIps": MessageLookupByLibrary.simpleMessage("IP autorisées"),
    "alwaysOn": MessageLookupByLibrary.simpleMessage("Toujours actif"),
    "alwaysOnDesc": MessageLookupByLibrary.simpleMessage(
      "Maintenir le VPN connecté quelles que soient les conditions réseau",
    ),
    "answers": MessageLookupByLibrary.simpleMessage("Réponses"),
    "app": MessageLookupByLibrary.simpleMessage("App"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "Contrôle d’accès des apps",
    ),
    "appIconDesign": MessageLookupByLibrary.simpleMessage(
      "Conception de l’icône de l’app",
    ),
    "appProxiesEmpty": MessageLookupByLibrary.simpleMessage(
      "Aucun proxy local",
    ),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage(
      "Ajouter le DNS du système",
    ),
    "appendSystemDnsTip": MessageLookupByLibrary.simpleMessage(
      "Ajouter de force le DNS système à la configuration",
    ),
    "application": MessageLookupByLibrary.simpleMessage("Application"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage(
      "Régler les paramètres de l’application",
    ),
    "ascending": MessageLookupByLibrary.simpleMessage("Croissant"),
    "authentication": MessageLookupByLibrary.simpleMessage("Authentification"),
    "authenticationDesc": MessageLookupByLibrary.simpleMessage(
      "L’authentification demande un nom d’utilisateur et un mot de passe sur le port du proxy local.",
    ),
    "authenticationSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Le proxy système n’est pas appliqué tant que l’authentification est activée.",
    ),
    "authorize": MessageLookupByLibrary.simpleMessage("Autoriser"),
    "authorized": MessageLookupByLibrary.simpleMessage("Autorisé"),
    "auto": MessageLookupByLibrary.simpleMessage("Auto"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage(
      "Rechercher les mises à jour automatiquement",
    ),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "Rechercher automatiquement les mises à jour au démarrage de l’application",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Fermer les connexions automatiquement",
    ),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "La fermeture automatique coupe les connexions ouvertes lorsque vous changez de proxy.",
    ),
    "autoInclude": MessageLookupByLibrary.simpleMessage(
      "Inclure automatiquement",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("Lancement automatique"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Lancer automatiquement au démarrage du système",
    ),
    "autoRun": MessageLookupByLibrary.simpleMessage("Démarrage automatique"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "Le démarrage automatique active le proxy à l’ouverture de l’app.",
    ),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage(
      "Définir automatiquement le DNS du système",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage(
      "Mise à jour automatique",
    ),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Intervalle de mise à jour automatique",
    ),
    "back": MessageLookupByLibrary.simpleMessage("Retour"),
    "backToDashboard": MessageLookupByLibrary.simpleMessage(
      "Retour au tableau de bord",
    ),
    "backToDashboardDesc": MessageLookupByLibrary.simpleMessage(
      "Revenir au tableau de bord avant de quitter",
    ),
    "backup": MessageLookupByLibrary.simpleMessage("Sauvegarde"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage(
      "Sauvegarde et restauration",
    ),
    "backupDateDescription": MessageLookupByLibrary.simpleMessage(
      "Date locale (AAAA-MM-JJ)",
    ),
    "backupFromNewerVersion": MessageLookupByLibrary.simpleMessage(
      "Cette sauvegarde provient d’une version plus récente de l’app. Mettez l’app à jour avant de la restaurer",
    ),
    "backupPlatformDescription": MessageLookupByLibrary.simpleMessage(
      "Plateforme actuelle",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("Sauvegarde réussie"),
    "backupTimeDescription": MessageLookupByLibrary.simpleMessage(
      "Heure locale (HHmmss)",
    ),
    "backupVersionDescription": MessageLookupByLibrary.simpleMessage(
      "Version de l’application",
    ),
    "basicConfig": MessageLookupByLibrary.simpleMessage(
      "Configuration de base",
    ),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage(
      "Modifier la configuration de base globalement",
    ),
    "basicInfo": MessageLookupByLibrary.simpleMessage("Infos de base"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("Stratégies de base"),
    "batchAdd": MessageLookupByLibrary.simpleMessage("Ajout groupé"),
    "batchImport": MessageLookupByLibrary.simpleMessage("Importation groupée"),
    "batchLinkInputTip": MessageLookupByLibrary.simpleMessage(
      "Un lien par ligne",
    ),
    "batchListInputTip": MessageLookupByLibrary.simpleMessage(
      "Un élément par ligne, ou séparés par des virgules",
    ),
    "batchMapInputTip": MessageLookupByLibrary.simpleMessage(
      "Une entrée par ligne : la clé, un espace, puis la valeur",
    ),
    "batchPreviewTip": m0,
    "batchUrlInputTip": MessageLookupByLibrary.simpleMessage(
      "Une URL par ligne",
    ),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "Ignorer l’optimisation de la batterie maintient l’app active en arrière-plan.",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("Lier"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("Mode liste noire"),
    "blockConnection": MessageLookupByLibrary.simpleMessage(
      "Bloquer la connexion",
    ),
    "brightness": MessageLookupByLibrary.simpleMessage("Luminosité"),
    "browse": MessageLookupByLibrary.simpleMessage("Parcourir"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("Domaines contournés"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Les domaines contournés ne s’appliquent que si le proxy système est activé.",
    ),
    "bypassPrivateRoute": MessageLookupByLibrary.simpleMessage(
      "Contourner les adresses privées",
    ),
    "bypassPrivateRouteDesc": MessageLookupByLibrary.simpleMessage(
      "Avec « Contourner les adresses privées » activé, les adresses LAN, de bouclage et multicast ne passent pas par TUN.",
    ),
    "cache": MessageLookupByLibrary.simpleMessage("Cache"),
    "cacheAlgorithm": MessageLookupByLibrary.simpleMessage(
      "Algorithme de cache",
    ),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "Le cache est corrompu. Le vider ?",
    ),
    "cacheMaxSize": MessageLookupByLibrary.simpleMessage("Taille du cache"),
    "cameraPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Autorisez l’accès à l’appareil photo dans les réglages du système pour scanner des codes QR, ou choisissez une image de code QR dans l’album.",
    ),
    "cameraPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Autorisation de l’appareil photo requise",
    ),
    "cameraUnavailable": MessageLookupByLibrary.simpleMessage(
      "Appareil photo indisponible",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Annuler"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage(
      "Tout désélectionner",
    ),
    "cannotSave": MessageLookupByLibrary.simpleMessage(
      "Enregistrement impossible",
    ),
    "captureDns": MessageLookupByLibrary.simpleMessage(
      "Capturer le DNS système",
    ),
    "captureDnsDesc": MessageLookupByLibrary.simpleMessage(
      "Rediriger toutes les requêtes DNS du système vers le module DNS interne",
    ),
    "changeProxyFailedTip": MessageLookupByLibrary.simpleMessage(
      "Échec du changement de proxy ; la sélection précédente a été rétablie",
    ),
    "changelogBreaking": MessageLookupByLibrary.simpleMessage(
      "Changements majeurs",
    ),
    "changelogFeatures": MessageLookupByLibrary.simpleMessage("Nouveautés"),
    "changelogFixes": MessageLookupByLibrary.simpleMessage(
      "Corrections de bugs",
    ),
    "changelogPerformance": MessageLookupByLibrary.simpleMessage(
      "Performances",
    ),
    "changelogReverts": MessageLookupByLibrary.simpleMessage("Annulations"),
    "checkCertificate": MessageLookupByLibrary.simpleMessage(
      "Vérifier les certificats TLS",
    ),
    "checkCertificateDesc": MessageLookupByLibrary.simpleMessage(
      "Sans vérification TLS, les abonnements et les sauvegardes sont exposés aux attaques de l’homme du milieu.",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage(
      "Rechercher des mises à jour",
    ),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "L’app est déjà à jour",
    ),
    "cipher": MessageLookupByLibrary.simpleMessage("Chiffrement"),
    "clear": MessageLookupByLibrary.simpleMessage("Effacer"),
    "clearData": MessageLookupByLibrary.simpleMessage("Effacer les données"),
    "clearDataAndExitTip": MessageLookupByLibrary.simpleMessage(
      "Cela supprime tous les profils, réglages et données locales, puis ferme l’app. Rouvrez-la pour repartir de zéro.",
    ),
    "clearDataFailed": m1,
    "clearSearch": MessageLookupByLibrary.simpleMessage("Effacer la recherche"),
    "clientFingerprint": MessageLookupByLibrary.simpleMessage(
      "Empreinte client",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage(
      "Exporter vers le presse-papiers",
    ),
    "clipboardImport": MessageLookupByLibrary.simpleMessage(
      "Importer depuis le presse-papiers",
    ),
    "clipboardWriteFailed": MessageLookupByLibrary.simpleMessage(
      "Impossible de copier dans le presse-papiers. La sélection est peut-être trop volumineuse",
    ),
    "close": MessageLookupByLibrary.simpleMessage("Fermer"),
    "closeAll": MessageLookupByLibrary.simpleMessage("Tout fermer"),
    "closeConnections": MessageLookupByLibrary.simpleMessage(
      "Fermer les connexions",
    ),
    "closeConnectionsPrompt": MessageLookupByLibrary.simpleMessage(
      "Fermer les connexions utilisant le proxy précédent ?",
    ),
    "collapse": MessageLookupByLibrary.simpleMessage("Réduire"),
    "collapseProxyChains": MessageLookupByLibrary.simpleMessage(
      "Réduire les chaînes de proxys",
    ),
    "collapseProxyChainsDesc": MessageLookupByLibrary.simpleMessage(
      "Masquer les nœuds intermédiaires lorsqu’une chaîne de proxys contient plus de trois nœuds",
    ),
    "collapseQuickSettingsPanel": MessageLookupByLibrary.simpleMessage(
      "Réduire le panneau des réglages rapides",
    ),
    "collapseQuickSettingsPanelDesc": MessageLookupByLibrary.simpleMessage(
      "Réduire le panneau après avoir touché la tuile",
    ),
    "color": MessageLookupByLibrary.simpleMessage("Couleur"),
    "colorStyle": MessageLookupByLibrary.simpleMessage("Style de couleur"),
    "columns": MessageLookupByLibrary.simpleMessage("Colonnes"),
    "compact": MessageLookupByLibrary.simpleMessage("Compact"),
    "compatible": MessageLookupByLibrary.simpleMessage("Mode de compatibilité"),
    "configDataDetected": MessageLookupByLibrary.simpleMessage(
      "Données détectées dans la configuration",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("Confirmer"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage(
      "Voulez-vous vraiment effacer toutes les données ?",
    ),
    "confirmClearSelectedData": MessageLookupByLibrary.simpleMessage(
      "Voulez-vous vraiment effacer les données sélectionnées ?",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Voulez-vous vraiment supprimer ce groupe de proxys ?",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage(
      "Voulez-vous vraiment quitter la fenêtre actuelle ?",
    ),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "Voulez-vous vraiment forcer le plantage du cœur ?",
    ),
    "confirmOverwriteTip": MessageLookupByLibrary.simpleMessage(
      "La confirmation remplacera les données existantes",
    ),
    "congestionControl": MessageLookupByLibrary.simpleMessage(
      "Contrôle de congestion",
    ),
    "congestionController": MessageLookupByLibrary.simpleMessage(
      "Contrôle de congestion TCP",
    ),
    "congestionControllerDesc": MessageLookupByLibrary.simpleMessage(
      "Le contrôle de congestion TCP ne fonctionne qu’avec la pile mips.",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("Connecté"),
    "connecting": MessageLookupByLibrary.simpleMessage("Connexion…"),
    "connection": MessageLookupByLibrary.simpleMessage("Connexion"),
    "connectionInfo": MessageLookupByLibrary.simpleMessage(
      "Nombre de connexions",
    ),
    "connectionStats": MessageLookupByLibrary.simpleMessage(
      "Statistiques de connexion",
    ),
    "connectionStatsDesc": MessageLookupByLibrary.simpleMessage(
      "Connexions en direct, requêtes récentes et requêtes DNS",
    ),
    "connections": MessageLookupByLibrary.simpleMessage("Connexions"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Afficher les données des connexions actuelles",
    ),
    "connectivity": MessageLookupByLibrary.simpleMessage("Connectivité : "),
    "content": MessageLookupByLibrary.simpleMessage("Contenu"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Le contenu ne peut pas être vide",
    ),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage(
      "Gérer les règles ajoutées globales",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("Copier"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage(
      "Copier les variables d’environnement",
    ),
    "copyLink": MessageLookupByLibrary.simpleMessage("Copier le lien"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("Copié avec succès"),
    "core": MessageLookupByLibrary.simpleMessage("Cœur"),
    "coreBlockedByPolicyTip": m2,
    "coreBlockedBySmartAppControlTip": MessageLookupByLibrary.simpleMessage(
      "Windows Smart App Control a bloqué FlClashCore.exe car il n’est pas signé. Ouvrez Sécurité Windows → Contrôle des applications et du navigateur → Paramètres de Smart App Control, choisissez Désactivé, puis relancez FlClash. Smart App Control ne peut pas être réactivé sans réinstaller Windows.",
    ),
    "coreStatus": MessageLookupByLibrary.simpleMessage("État du cœur"),
    "country": MessageLookupByLibrary.simpleMessage("Région"),
    "crashDetected": MessageLookupByLibrary.simpleMessage("Plantage détecté"),
    "crashDetectedTip": m3,
    "crashTest": MessageLookupByLibrary.simpleMessage("Test de plantage"),
    "create": MessageLookupByLibrary.simpleMessage("Créer"),
    "createProfile": MessageLookupByLibrary.simpleMessage("Créer un profil"),
    "createProfileFromUrlTip": m4,
    "creationTime": MessageLookupByLibrary.simpleMessage("Date de création"),
    "currentOutboundDesc": MessageLookupByLibrary.simpleMessage(
      "Contient le bouton de démarrage et ne peut pas être retiré",
    ),
    "custom": MessageLookupByLibrary.simpleMessage("Personnalisé"),
    "customColor": MessageLookupByLibrary.simpleMessage(
      "Couleur personnalisée",
    ),
    "customImportDroppedSubRules": m5,
    "customIssueCoreRejected": m6,
    "customIssueDialerLoop": m7,
    "customIssueDuplicateName": m8,
    "customIssueEmptyName": MessageLookupByLibrary.simpleMessage(
      "Le nom est vide",
    ),
    "customIssueGroupLoop": m9,
    "customIssueInvalidEmptyFallback": m10,
    "customIssueInvalidFilter": m11,
    "customIssueMissingDialer": m12,
    "customIssueMissingProviders": m13,
    "customIssueMissingProxies": m14,
    "customIssueNoProxySource": MessageLookupByLibrary.simpleMessage(
      "Aucun proxy ni fournisseur de proxys n’est sélectionné ; le cœur rejette donc ce groupe",
    ),
    "customIssueReservedName": m15,
    "customIssuesSummary": m16,
    "customProfile": MessageLookupByLibrary.simpleMessage("Personnalisé"),
    "customProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Assembler des groupes de proxys et des règles à partir des proxys de l’app et d’autres profils",
    ),
    "customProfileResources": MessageLookupByLibrary.simpleMessage(
      "Ressources des profils personnalisés",
    ),
    "customProfileResourcesDesc": MessageLookupByLibrary.simpleMessage(
      "Les ressources des profils personnalisés regroupent des proxys, des fournisseurs de règles, des filtres et des jeux d’icônes.",
    ),
    "cut": MessageLookupByLibrary.simpleMessage("Couper"),
    "dark": MessageLookupByLibrary.simpleMessage("Sombre"),
    "dashboard": MessageLookupByLibrary.simpleMessage("Tableau de bord"),
    "dashboardAddableSection": MessageLookupByLibrary.simpleMessage(
      "Disponibles à l’ajout",
    ),
    "dataChangedSave": MessageLookupByLibrary.simpleMessage(
      "Des modifications ont été détectées. Les enregistrer ?",
    ),
    "databaseWriteFailedTip": MessageLookupByLibrary.simpleMessage(
      "Échec de l’enregistrement de la modification ; elle a été annulée",
    ),
    "davDirectory": MessageLookupByLibrary.simpleMessage("Dossier"),
    "daysAgo": m17,
    "daysAgoShort": m18,
    "defaultNameserver": MessageLookupByLibrary.simpleMessage(
      "Serveur DNS par défaut",
    ),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Utilisé pour résoudre les noms des serveurs DNS",
    ),
    "defaultSelected": MessageLookupByLibrary.simpleMessage(
      "Sélection par défaut",
    ),
    "defaultText": MessageLookupByLibrary.simpleMessage("Par défaut"),
    "definitionNotMap": MessageLookupByLibrary.simpleMessage(
      "La configuration doit être un mappage YAML avec un nom et un type",
    ),
    "delay": MessageLookupByLibrary.simpleMessage("Délai"),
    "delayFailed": MessageLookupByLibrary.simpleMessage("Échec"),
    "delayTest": MessageLookupByLibrary.simpleMessage("Test de délai"),
    "delete": MessageLookupByLibrary.simpleMessage("Supprimer"),
    "deleteMultipTip": m19,
    "deleteTip": m20,
    "desc": MessageLookupByLibrary.simpleMessage(
      "Un client proxy multiplateforme basé sur ClashMeta, simple d’utilisation, open source et sans publicité.",
    ),
    "descending": MessageLookupByLibrary.simpleMessage("Décroissant"),
    "destination": MessageLookupByLibrary.simpleMessage("Destination"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage(
      "GeoIP de destination",
    ),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage(
      "ASN de l’IP de destination",
    ),
    "details": m21,
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "Repose sur une API tierce ; à titre indicatif uniquement",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("Mode développeur"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "Le mode développeur est activé.",
    ),
    "dialerProxy": MessageLookupByLibrary.simpleMessage("Proxy de connexion"),
    "dialerProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Le proxy de connexion est la sortie utilisée pour joindre le serveur NTP.",
    ),
    "dialerProxyLoopStopped": m22,
    "direct": MessageLookupByLibrary.simpleMessage("Direct"),
    "disableIcmpForwarding": MessageLookupByLibrary.simpleMessage(
      "Désactiver le transfert ICMP",
    ),
    "disableIcmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "Avec le transfert ICMP désactivé, TUN répond lui-même au ping, qui n’indique donc plus la latence réelle.",
    ),
    "disableKeepAlive": MessageLookupByLibrary.simpleMessage(
      "Désactiver le keep-alive TCP",
    ),
    "disableUDP": MessageLookupByLibrary.simpleMessage("Désactiver UDP"),
    "disabled": MessageLookupByLibrary.simpleMessage("Désactivé"),
    "discardChanges": MessageLookupByLibrary.simpleMessage(
      "Abandonner les modifications ?",
    ),
    "disclaimer": MessageLookupByLibrary.simpleMessage("Avertissement"),
    "disclaimerAcceptContent": MessageLookupByLibrary.simpleMessage(
      "En installant, copiant ou utilisant le Logiciel, vous êtes réputé avoir lu et accepté l’intégralité de cette déclaration. Si vous n’êtes pas d’accord avec l’une de ses conditions, cessez immédiatement d’utiliser le Logiciel et désinstallez-le.",
    ),
    "disclaimerAcceptTitle": MessageLookupByLibrary.simpleMessage(
      "Acceptation",
    ),
    "disclaimerAcknowledgeLabel": MessageLookupByLibrary.simpleMessage(
      "J\'ai lu et compris cette déclaration",
    ),
    "disclaimerAcknowledgeTip": MessageLookupByLibrary.simpleMessage(
      "Pour confirmer que vous avez compris, lisez la déclaration suivante et cochez la case ci-dessous :",
    ),
    "disclaimerAcknowledgeTitle": MessageLookupByLibrary.simpleMessage(
      "Confirmer la déclaration",
    ),
    "disclaimerChangesContent": MessageLookupByLibrary.simpleMessage(
      "Les développeurs peuvent réviser cette déclaration à chaque version, et la révision prend effet à la publication de cette version. Continuer à utiliser le Logiciel après une mise à jour signifie que vous acceptez la déclaration révisée.",
    ),
    "disclaimerChangesTitle": MessageLookupByLibrary.simpleMessage(
      "Modifications de cette déclaration",
    ),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "Avant d’utiliser FlClash (« le Logiciel »), veuillez lire attentivement cette déclaration et vous assurer de l’avoir comprise dans son intégralité. Appuyer sur « Accepter » signifie que vous avez lu, compris et accepté chacune des conditions ci-dessous. Si vous n’êtes pas d’accord, appuyez sur « Quitter » et cessez d’utiliser le Logiciel.",
    ),
    "disclaimerLiabilityContent": MessageLookupByLibrary.simpleMessage(
      "Dans toute la mesure permise par la loi applicable, ni les développeurs ni aucun contributeur ne sauraient être tenus responsables de dommages directs, indirects, accessoires, spéciaux, punitifs ou consécutifs résultant de l’utilisation ou de l’impossibilité d’utiliser le Logiciel, y compris, sans s’y limiter, la perte de données, les dommages matériels, les pannes réseau, l’interruption d’activité, le manque à gagner ou tout litige qui en découlerait, même s’ils ont été avertis de la possibilité de tels dommages.",
    ),
    "disclaimerLiabilityTitle": MessageLookupByLibrary.simpleMessage(
      "Limitation de responsabilité",
    ),
    "disclaimerLicenseContent": MessageLookupByLibrary.simpleMessage(
      "Le Logiciel est open source sous licence GPL-3.0. Vous pouvez l’utiliser, le modifier et le distribuer librement tant que vous respectez cette licence, qui exige que les œuvres dérivées soient elles aussi publiées sous GPL-3.0 et que les mentions de droit d’auteur d’origine soient conservées.\n\nLes composants tiers du Logiciel, dont le cœur Clash.Meta, suivent leurs propres licences. Les auteurs d’origine ne sont pas responsables des problèmes liés aux versions modifiées ou redistribuées.",
    ),
    "disclaimerLicenseTitle": MessageLookupByLibrary.simpleMessage(
      "Licence open source",
    ),
    "disclaimerNoServiceStatement": MessageLookupByLibrary.simpleMessage(
      "Le Logiciel ne fournit lui-même aucun serveur proxy, nœud, abonnement ni service d’accès au réseau, et n’a aucun partenariat, mandat ni lien de garantie avec un quelconque fournisseur de tels services.",
    ),
    "disclaimerPrivacyContent": MessageLookupByLibrary.simpleMessage(
      "Le Logiciel ne collecte ni ne transmet vos URL d’abonnement, détails de nœuds, contenus de configuration, sites visités, historiques de connexion, contenus de trafic ou journaux. Ces données restent sur votre appareil et les développeurs n’y ont pas accès.\n\nLe Logiciel n’accède au réseau que lorsque vous utilisez une fonction qui en a besoin, par exemple pour récupérer l’URL d’abonnement que vous avez fournie lors de la mise à jour d’un profil, ou pour contacter GitHub lors de la recherche de mises à jour.\n\nLe Logiciel n’inclut aucun service d’analyse ni de rapport de plantage, sur aucune plateforme.",
    ),
    "disclaimerPrivacyTitle": MessageLookupByLibrary.simpleMessage(
      "Collecte de données et confidentialité",
    ),
    "disclaimerResponsibilityContent": MessageLookupByLibrary.simpleMessage(
      "Il vous incombe de vous assurer que l’utilisation du Logiciel est licite là où vous vivez, et vous assumez seul la responsabilité juridique de tout ce que vous faites avec lui et de ses conséquences.\n\nLes abonnements, nœuds et configurations que vous importez relèvent de votre choix. La licéité de leur source, la sécurité de leur contenu et la fiabilité de leur service sont une affaire entre vous et leurs fournisseurs.",
    ),
    "disclaimerResponsibilityTitle": MessageLookupByLibrary.simpleMessage(
      "Votre responsabilité",
    ),
    "disclaimerRestateHint": MessageLookupByLibrary.simpleMessage(
      "Saisissez la déclaration ci-dessus",
    ),
    "disclaimerRestateMismatch": MessageLookupByLibrary.simpleMessage(
      "Ne correspond pas à la déclaration",
    ),
    "disclaimerRestateTip": MessageLookupByLibrary.simpleMessage(
      "Pour confirmer que vous avez compris, saisissez la déclaration suivante en entier dans le champ ci-dessous :",
    ),
    "disclaimerRestateTitle": MessageLookupByLibrary.simpleMessage(
      "Recopier la déclaration",
    ),
    "disclaimerSoftwareContent": MessageLookupByLibrary.simpleMessage(
      "Le Logiciel est un client proxy réseau open source construit sur le cœur Clash.Meta (mihomo). Il se limite à fournir des outils locaux tels que la gestion de la configuration, le routage par règles et le transfert du trafic.",
    ),
    "disclaimerSoftwareTitle": MessageLookupByLibrary.simpleMessage(
      "Nature du logiciel",
    ),
    "disclaimerThirdPartyContent": MessageLookupByLibrary.simpleMessage(
      "Les liens d’abonnement, fichiers de configuration, jeux de règles, scripts, ressources externes et liens externes sont tous fournis par des tiers. Les développeurs ne peuvent ni ne vont vérifier ou garantir leur légalité, leur exactitude, leur sécurité ou leur disponibilité.\n\nTout vol de données, perte financière, bannissement de compte ou autre dommage causé par un contenu tiers se règle entre vous et le tiers concerné ; les développeurs n’en assument aucune responsabilité.",
    ),
    "disclaimerThirdPartyTitle": MessageLookupByLibrary.simpleMessage(
      "Contenus tiers",
    ),
    "disclaimerUsageContent": MessageLookupByLibrary.simpleMessage(
      "Le Logiciel est destiné uniquement à des usages non commerciaux tels que l’apprentissage, les échanges et la recherche technique. Toute utilisation à des fins commerciales est strictement interdite, y compris, sans s’y limiter, la distribution payante, la vente groupée, l’intégration à un service commercial ou l’exercice d’une activité au nom du Logiciel. Toute activité commerciale est étrangère au Logiciel et à ses développeurs.\n\nIl est strictement interdit d’utiliser le Logiciel à des fins contraires aux lois et règlements de votre pays ou de votre région, y compris, sans s’y limiter, le contournement de restrictions d’accès au réseau légalement imposées, la diffusion de contenus illicites, le lancement d’attaques réseau ou l’atteinte aux droits légitimes d’autrui.",
    ),
    "disclaimerUsageTitle": MessageLookupByLibrary.simpleMessage(
      "Restrictions d’utilisation",
    ),
    "disclaimerWarrantyContent": MessageLookupByLibrary.simpleMessage(
      "Le Logiciel est fourni « tel quel » et « selon disponibilité », sans garantie d’aucune sorte, expresse ou implicite, y compris, sans s’y limiter, les garanties de qualité marchande, d’adéquation à un usage particulier, d’absence de contrefaçon, de disponibilité ininterrompue, d’absence d’erreurs ou d’absence de failles de sécurité.\n\nLes développeurs ne garantissent pas que le Logiciel répondra à vos besoins ni qu’il fonctionnera sans interruption ni erreur.",
    ),
    "disclaimerWarrantyTitle": MessageLookupByLibrary.simpleMessage(
      "Absence de garantie",
    ),
    "disconnected": MessageLookupByLibrary.simpleMessage("Déconnecté"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "Nouvelle version disponible",
    ),
    "dnsDesc": MessageLookupByLibrary.simpleMessage(
      "Modifier les paramètres DNS",
    ),
    "dnsHijack": MessageLookupByLibrary.simpleMessage("Interception DNS"),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "Sans cette entrée, TUN détourne toutes les requêtes DNS vers le port 53 (any:53).",
    ),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("Détournement DNS"),
    "dnsIPv6Desc": MessageLookupByLibrary.simpleMessage(
      "Lorsqu’elle est désactivée, cette option renvoie un résultat vide pour les requêtes AAAA",
    ),
    "dnsMode": MessageLookupByLibrary.simpleMessage("Mode DNS"),
    "dnsOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Les entrées ajoutées ici remplacent le DNS de tous les profils URL et fichier ; tout ce qui n’est pas ajouté garde le réglage du profil. Les profils personnalisés définissent leur DNS dans leur contenu.",
    ),
    "dnsQueries": MessageLookupByLibrary.simpleMessage("Requêtes DNS"),
    "dnsQueriesDesc": MessageLookupByLibrary.simpleMessage(
      "Enregistrements de résolution DNS du noyau",
    ),
    "docked": MessageLookupByLibrary.simpleMessage("Ancrée"),
    "domain": MessageLookupByLibrary.simpleMessage("Domaine"),
    "done": MessageLookupByLibrary.simpleMessage("Terminé"),
    "download": MessageLookupByLibrary.simpleMessage("Réception"),
    "downloadBandwidth": MessageLookupByLibrary.simpleMessage(
      "Bande passante de réception",
    ),
    "downloadSpeed": MessageLookupByLibrary.simpleMessage(
      "Vitesse de téléchargement",
    ),
    "downloadTraffic": MessageLookupByLibrary.simpleMessage("Trafic reçu"),
    "duration": MessageLookupByLibrary.simpleMessage("Durée"),
    "easyTierConnectionLatency": MessageLookupByLibrary.simpleMessage(
      "Latence de connexion",
    ),
    "easyTierDnsZone": MessageLookupByLibrary.simpleMessage("Zone DNS"),
    "easyTierFeatureFlags": MessageLookupByLibrary.simpleMessage(
      "Indicateurs de fonctionnalités",
    ),
    "easyTierInstanceId": MessageLookupByLibrary.simpleMessage(
      "Identifiant de l’instance",
    ),
    "easyTierLatencyFirstPathLatency": MessageLookupByLibrary.simpleMessage(
      "Latence du chemin (latence prioritaire)",
    ),
    "easyTierListeners": MessageLookupByLibrary.simpleMessage("Écoutes"),
    "easyTierLocalEndpoint": MessageLookupByLibrary.simpleMessage(
      "Point de terminaison local",
    ),
    "easyTierLossRate": MessageLookupByLibrary.simpleMessage(
      "Perte de paquets",
    ),
    "easyTierMinDirectLatency": MessageLookupByLibrary.simpleMessage(
      "Latence directe minimale",
    ),
    "easyTierNextHop": MessageLookupByLibrary.simpleMessage(
      "Identifiant du pair du prochain saut",
    ),
    "easyTierPathLatency": MessageLookupByLibrary.simpleMessage(
      "Latence du chemin (nombre de sauts prioritaire)",
    ),
    "easyTierPeerId": MessageLookupByLibrary.simpleMessage(
      "Identifiant du pair",
    ),
    "easyTierProtocol": MessageLookupByLibrary.simpleMessage(
      "Protocole de transport",
    ),
    "easyTierPublicServer": MessageLookupByLibrary.simpleMessage(
      "Serveur public",
    ),
    "easyTierRemoteEndpoint": MessageLookupByLibrary.simpleMessage(
      "Point de terminaison distant",
    ),
    "easyTierRouteCost": MessageLookupByLibrary.simpleMessage(
      "Coût de la route",
    ),
    "easyTierRxPackets": MessageLookupByLibrary.simpleMessage("Paquets reçus"),
    "easyTierTxPackets": MessageLookupByLibrary.simpleMessage(
      "Paquets envoyés",
    ),
    "edit": MessageLookupByLibrary.simpleMessage("Modifier"),
    "editDashboard": MessageLookupByLibrary.simpleMessage(
      "Modifier le tableau de bord",
    ),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage(
      "Modifier les règles globales",
    ),
    "editProxy": MessageLookupByLibrary.simpleMessage("Modifier le proxy"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Modifier le groupe de proxys",
    ),
    "editRule": MessageLookupByLibrary.simpleMessage("Modifier la règle"),
    "editSsid": MessageLookupByLibrary.simpleMessage("Modifier le SSID"),
    "editorUnavailable": MessageLookupByLibrary.simpleMessage(
      "Éditeur indisponible",
    ),
    "elapsed": MessageLookupByLibrary.simpleMessage("Durée"),
    "emptyFallback": MessageLookupByLibrary.simpleMessage("Repli si vide"),
    "emptyTip": m23,
    "en": MessageLookupByLibrary.simpleMessage("Anglais"),
    "enableExternalController": MessageLookupByLibrary.simpleMessage(
      "Activer le contrôleur externe",
    ),
    "enabled": MessageLookupByLibrary.simpleMessage("Activé"),
    "endpointIndependentNat": MessageLookupByLibrary.simpleMessage(
      "Amélioration du NAT",
    ),
    "endpointIndependentNatDesc": MessageLookupByLibrary.simpleMessage(
      "Optimiser la connectivité des applications UDP et P2P",
    ),
    "endpoints": MessageLookupByLibrary.simpleMessage("Points de terminaison"),
    "enforceRoutes": MessageLookupByLibrary.simpleMessage("Imposer les routes"),
    "enforceRoutesDesc": MessageLookupByLibrary.simpleMessage(
      "Garantir l’acheminement du trafic dans le tunnel même si des routes plus spécifiques existent",
    ),
    "entries": MessageLookupByLibrary.simpleMessage(" entrées"),
    "entriesCount": m24,
    "error": MessageLookupByLibrary.simpleMessage("Erreur"),
    "errorDetails": MessageLookupByLibrary.simpleMessage("Détails de l’erreur"),
    "es": MessageLookupByLibrary.simpleMessage("Espagnol"),
    "exclude": MessageLookupByLibrary.simpleMessage(
      "Masquer des tâches récentes",
    ),
    "excludeAPNs": MessageLookupByLibrary.simpleMessage("Exclure APNs"),
    "excludeAPNsDesc": MessageLookupByLibrary.simpleMessage(
      "Autoriser les notifications push Apple à contourner le tunnel",
    ),
    "excludeCellularServices": MessageLookupByLibrary.simpleMessage(
      "Exclure les services cellulaires",
    ),
    "excludeCellularServicesDesc": MessageLookupByLibrary.simpleMessage(
      "Autoriser les services cellulaires, tels que les appels Wi-Fi, à contourner le tunnel",
    ),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "Masquer l’application des tâches récentes lorsqu’elle est en arrière-plan",
    ),
    "excludeDeviceCommunication": MessageLookupByLibrary.simpleMessage(
      "Exclure les communications entre appareils",
    ),
    "excludeDeviceCommunicationDesc": MessageLookupByLibrary.simpleMessage(
      "Autoriser les communications entre appareils, telles qu’AirDrop et AirPlay, à contourner le tunnel",
    ),
    "excludeDstPort": MessageLookupByLibrary.simpleMessage(
      "Ports de destination exclus",
    ),
    "excludeDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "Le trafic vers les ports de destination exclus ne passe pas par TUN.",
    ),
    "excludeFilter": MessageLookupByLibrary.simpleMessage("Filtre d’exclusion"),
    "excludeInterface": MessageLookupByLibrary.simpleMessage(
      "Interfaces exclues",
    ),
    "excludeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "Le trafic qui arrive sur les interfaces exclues, par exemple docker0, ne passe pas par TUN.",
    ),
    "excludeLocalNetworks": MessageLookupByLibrary.simpleMessage(
      "Exclure les réseaux locaux",
    ),
    "excludeLocalNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "Autoriser l’accès direct aux appareils du réseau local",
    ),
    "excludeProxyFilter": MessageLookupByLibrary.simpleMessage(
      "Filtre d’exclusion de proxys",
    ),
    "excludeSrcPort": MessageLookupByLibrary.simpleMessage(
      "Ports source exclus",
    ),
    "excludeSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "Le trafic issu des ports source exclus ne passe pas par TUN.",
    ),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("SSID exclus"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "Lorsque vous êtes connecté à un Wi-Fi dont le SSID est exclu, l’état d’exécution de l’app change automatiquement.",
    ),
    "excludeType": MessageLookupByLibrary.simpleMessage("Type d’exclusion"),
    "excludeUid": MessageLookupByLibrary.simpleMessage("ID utilisateur exclus"),
    "excludeUidDesc": MessageLookupByLibrary.simpleMessage(
      "Le trafic des processus des ID utilisateur exclus ne passe pas par TUN.",
    ),
    "existsTip": m25,
    "exit": MessageLookupByLibrary.simpleMessage("Quitter"),
    "exitFullScreen": MessageLookupByLibrary.simpleMessage(
      "Quitter le plein écran",
    ),
    "exitNodes": MessageLookupByLibrary.simpleMessage("Nœuds de sortie"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("Statut attendu"),
    "expireTime": MessageLookupByLibrary.simpleMessage("Date d’expiration"),
    "exportFile": MessageLookupByLibrary.simpleMessage("Exporter le fichier"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("Exporter les journaux"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage(
      "Exportation réussie",
    ),
    "extend": MessageLookupByLibrary.simpleMessage("Extension"),
    "extendMode": MessageLookupByLibrary.simpleMessage("Mode d’extension"),
    "extendScript": MessageLookupByLibrary.simpleMessage("Script d’extension"),
    "externalController": MessageLookupByLibrary.simpleMessage(
      "Contrôleur externe",
    ),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "Le contrôleur externe permet de piloter le cœur via le port 9090.",
    ),
    "externalControllerSecret": MessageLookupByLibrary.simpleMessage(
      "Secret du contrôleur externe",
    ),
    "externalFetch": MessageLookupByLibrary.simpleMessage(
      "Récupération externe",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("Lien externe"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("Très grande"),
    "fade": MessageLookupByLibrary.simpleMessage("Fondu"),
    "failedCount": m26,
    "failedItem": m27,
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Filtre Fake-IP"),
    "fakeipFilterDesc": MessageLookupByLibrary.simpleMessage(
      "Les domaines correspondants reçoivent de vraies adresses IP au lieu d’adresses Fake IP dans ce mode",
    ),
    "fakeipFilterMode": MessageLookupByLibrary.simpleMessage(
      "Mode du filtre Fake-IP",
    ),
    "fakeipFilterModeDesc": MessageLookupByLibrary.simpleMessage(
      "En mode filtre Fake-IP, la liste noire exclut les correspondances, la liste blanche ne falsifie que les correspondances, et « rule » les traite comme des règles.",
    ),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Plage Fake-IP"),
    "fakeipRange6": MessageLookupByLibrary.simpleMessage(
      "Plage Fake-IP (IPv6)",
    ),
    "fakeipTtl": MessageLookupByLibrary.simpleMessage("TTL Fake-IP"),
    "fallback": MessageLookupByLibrary.simpleMessage("Repli"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Généralement un DNS à l’étranger",
    ),
    "fallbackDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Les domaines correspondants utilisent directement le repli sans interroger le serveur DNS",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("Filtre de repli"),
    "fallbackGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Vérifier le code GeoIP des résultats du serveur DNS ; utiliser le repli hors de cette région",
    ),
    "fallbackGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Les domaines correspondant à ces catégories GeoSite utilisent directement le repli",
    ),
    "fallbackIpcidrDesc": MessageLookupByLibrary.simpleMessage(
      "Remplacer par le repli les résultats du serveur DNS correspondant à ces préfixes CIDR",
    ),
    "features": MessageLookupByLibrary.simpleMessage("Fonctionnalités"),
    "file": MessageLookupByLibrary.simpleMessage("Fichier"),
    "fileDesc": MessageLookupByLibrary.simpleMessage(
      "Importer directement un fichier de profil",
    ),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "Le fichier a été modifié. Enregistrer les modifications ?",
    ),
    "fileName": MessageLookupByLibrary.simpleMessage("Nom de fichier"),
    "filter": MessageLookupByLibrary.simpleMessage("Filtrer"),
    "filters": MessageLookupByLibrary.simpleMessage("Filtres"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage(
      "Recherche de processus",
    ),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "L’activation réduit légèrement les performances",
    ),
    "floating": MessageLookupByLibrary.simpleMessage("Flottante"),
    "followProfile": MessageLookupByLibrary.simpleMessage("Suivre le profil"),
    "followSystem": MessageLookupByLibrary.simpleMessage("Suivre le système"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("Police"),
    "fontSize": MessageLookupByLibrary.simpleMessage("Taille"),
    "forceDnsMapping": MessageLookupByLibrary.simpleMessage(
      "Forcer le mappage DNS",
    ),
    "forceDnsMappingDesc": MessageLookupByLibrary.simpleMessage(
      "Forcer le mappage DNS analyse aussi les connexions dont le domaine provient d’un mappage DNS.",
    ),
    "forceDomain": MessageLookupByLibrary.simpleMessage("Domaines forcés"),
    "forceDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Les domaines forcés sont aussi analysés ; les autres connexions qui ont déjà un domaine sont laissées telles quelles.",
    ),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Voulez-vous vraiment forcer le redémarrage du cœur ?",
    ),
    "fr": MessageLookupByLibrary.simpleMessage("Français"),
    "general": MessageLookupByLibrary.simpleMessage("Général"),
    "generalDesc": MessageLookupByLibrary.simpleMessage(
      "Paramètres généraux de l’application et du noyau",
    ),
    "generateFromPrivateKey": MessageLookupByLibrary.simpleMessage(
      "Générer depuis une clé privée Age",
    ),
    "generateSecret": MessageLookupByLibrary.simpleMessage("Générer"),
    "geoAutoUpdate": MessageLookupByLibrary.simpleMessage(
      "Mise à jour automatique",
    ),
    "geoAutoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Intervalle de mise à jour automatique",
    ),
    "geoAutoUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "L’intervalle de mise à jour automatique doit être supérieur à 0",
    ),
    "geoOptions": MessageLookupByLibrary.simpleMessage("Options Geo"),
    "geoResources": MessageLookupByLibrary.simpleMessage("Geo"),
    "geoSkipped": m28,
    "geoUpdated": m29,
    "geoUpdating": m30,
    "geodataLoader": MessageLookupByLibrary.simpleMessage(
      "Mode Geo à faible mémoire",
    ),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "Utiliser le chargeur Geo à faible consommation de mémoire",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("Code GeoIP"),
    "geositeMatcher": MessageLookupByLibrary.simpleMessage(
      "Moteur de correspondance Geo haute performance",
    ),
    "geositeMatcherDesc": MessageLookupByLibrary.simpleMessage(
      "Utiliser l’algorithme de hachage parfait minimal pour les correspondances",
    ),
    "global": MessageLookupByLibrary.simpleMessage("Global"),
    "go": MessageLookupByLibrary.simpleMessage("Aller"),
    "goDownload": MessageLookupByLibrary.simpleMessage("Télécharger"),
    "goToConfigureAddedRules": MessageLookupByLibrary.simpleMessage(
      "Aller à la configuration des règles ajoutées",
    ),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage(
      "Aller à la configuration du script",
    ),
    "goroutineInfo": MessageLookupByLibrary.simpleMessage("Goroutines"),
    "grid": MessageLookupByLibrary.simpleMessage("Grille"),
    "groupCount": m31,
    "groupCountUnit": MessageLookupByLibrary.simpleMessage("groupes"),
    "groupTimeoutCount": m32,
    "hasCacheChange": MessageLookupByLibrary.simpleMessage(
      "Mettre les modifications en cache ?",
    ),
    "hashByInUser": MessageLookupByLibrary.simpleMessage(
      "Hachage par utilisateur entrant",
    ),
    "header": MessageLookupByLibrary.simpleMessage("En-tête"),
    "healthCheck": MessageLookupByLibrary.simpleMessage("Contrôle d’état"),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "Service Helper indisponible ; le mode TUN ne peut pas être activé. Réinstallez FlClash pour le rétablir.",
    ),
    "hex": MessageLookupByLibrary.simpleMessage("Hex"),
    "hide": MessageLookupByLibrary.simpleMessage("Masquer"),
    "hideFromList": MessageLookupByLibrary.simpleMessage("Masquer de la liste"),
    "hideIp": MessageLookupByLibrary.simpleMessage("Masquer l’IP"),
    "hidePassword": MessageLookupByLibrary.simpleMessage(
      "Masquer le mot de passe",
    ),
    "hideTimeoutProxies": MessageLookupByLibrary.simpleMessage(
      "Masquer les proxys expirés",
    ),
    "hideTimeoutProxiesDesc": MessageLookupByLibrary.simpleMessage(
      "Ignorer les proxys dont le dernier test de délai a expiré",
    ),
    "hideUnavailable": MessageLookupByLibrary.simpleMessage(
      "Masquer les délais dépassés",
    ),
    "highPriorityAutoLaunch": MessageLookupByLibrary.simpleMessage(
      "Démarrage automatique prioritaire",
    ),
    "highPriorityAutoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Utiliser une tâche planifiée Windows pour démarrer plus tôt",
    ),
    "hopInterval": MessageLookupByLibrary.simpleMessage("Intervalle de saut"),
    "host": MessageLookupByLibrary.simpleMessage("Hôte"),
    "hostname": MessageLookupByLibrary.simpleMessage("Nom d’hôte"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage(
      "Ajouter des entrées hosts",
    ),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage(
      "Conflit de raccourci clavier",
    ),
    "hotkeyConflictWith": m33,
    "hotkeyDesc": MessageLookupByLibrary.simpleMessage(
      "Les raccourcis globaux fonctionnent même lorsque la fenêtre est masquée. Appuyez sur une action pour enregistrer sa combinaison de touches.",
    ),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage(
      "Gestion des raccourcis",
    ),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "Contrôler l’application au clavier",
    ),
    "hotkeyNeedsModifier": m34,
    "hotkeyNotSet": MessageLookupByLibrary.simpleMessage("Non défini"),
    "hotkeyUnavailable": MessageLookupByLibrary.simpleMessage(
      "Non enregistré, il est peut-être pris par une autre app",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("heures"),
    "hoursAgo": m35,
    "hoursAgoShort": m36,
    "hue": MessageLookupByLibrary.simpleMessage("Teinte"),
    "icmpForwarding": MessageLookupByLibrary.simpleMessage("Transfert ICMP"),
    "icmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "Activer le ping ICMP",
    ),
    "icon": MessageLookupByLibrary.simpleMessage("Icône"),
    "iconRecords": MessageLookupByLibrary.simpleMessage(
      "Historique des icônes",
    ),
    "iconSets": MessageLookupByLibrary.simpleMessage("Jeux d’icônes"),
    "iconSetsEmptyTip": MessageLookupByLibrary.simpleMessage(
      "Aucun jeu d’icônes pour le moment. Ajoutez-en dans Ressources des profils personnalisés → Jeux d’icônes",
    ),
    "iconSource": MessageLookupByLibrary.simpleMessage("Source des icônes"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("Style des icônes"),
    "iconStyleFilled": MessageLookupByLibrary.simpleMessage("Pleines"),
    "iconStyleHidden": MessageLookupByLibrary.simpleMessage("Masquées"),
    "iconStylePlain": MessageLookupByLibrary.simpleMessage("Simples"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("URL de l’icône"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "Ignorer l’optimisation de la batterie",
    ),
    "ignoreCertificateErrors": MessageLookupByLibrary.simpleMessage(
      "Ignorer la validation des certificats",
    ),
    "ignoreCertificateErrorsDesc": MessageLookupByLibrary.simpleMessage(
      "Autoriser les connexions HTTPS avec des certificats invalides. Cela réduit la sécurité",
    ),
    "import": MessageLookupByLibrary.simpleMessage("Importer"),
    "importConfigInvalid": MessageLookupByLibrary.simpleMessage(
      "Ce fichier n’est pas une configuration importable",
    ),
    "importConfigReplaceTip": MessageLookupByLibrary.simpleMessage(
      "L’importation remplace les groupes de proxys, les règles et les réglages actuels de ce profil",
    ),
    "importFile": MessageLookupByLibrary.simpleMessage(
      "Importer depuis un fichier",
    ),
    "importFromLink": MessageLookupByLibrary.simpleMessage(
      "Importer depuis un lien",
    ),
    "importFromURL": MessageLookupByLibrary.simpleMessage(
      "Importer depuis une URL",
    ),
    "importUrl": MessageLookupByLibrary.simpleMessage(
      "Importer depuis une URL",
    ),
    "inbound": MessageLookupByLibrary.simpleMessage("Entrant"),
    "includeAllNetworks": MessageLookupByLibrary.simpleMessage(
      "Inclure tous les réseaux",
    ),
    "includeAllNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "Acheminer tout le trafic réseau dans le tunnel, y compris les services locaux et cellulaires",
    ),
    "includeAllProxies": MessageLookupByLibrary.simpleMessage(
      "Inclure tous les proxys",
    ),
    "includeAllProxiesTip": MessageLookupByLibrary.simpleMessage(
      "Importer tous les proxys hors des groupes ; des groupes supplémentaires peuvent être ajoutés ci-dessous",
    ),
    "includeAllProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Inclure tous les fournisseurs de proxys",
    ),
    "includeAllProxyProvidersTip": MessageLookupByLibrary.simpleMessage(
      "Remplacer les fournisseurs de proxys importés lorsque cette option est activée",
    ),
    "includeInterface": MessageLookupByLibrary.simpleMessage(
      "Interfaces incluses",
    ),
    "includeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "Seul le trafic arrivant sur les interfaces incluses passe par TUN, et les interfaces exclues ne s’appliquent plus.",
    ),
    "includeUid": MessageLookupByLibrary.simpleMessage("ID utilisateur inclus"),
    "includeUidDesc": MessageLookupByLibrary.simpleMessage(
      "Seul le trafic des processus des ID utilisateur inclus passe par TUN.",
    ),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("N’expire jamais"),
    "init": MessageLookupByLibrary.simpleMessage("Initialisation"),
    "initFailed": MessageLookupByLibrary.simpleMessage("Échec du démarrage"),
    "initFailedTip": MessageLookupByLibrary.simpleMessage(
      "FlClash a rencontré une erreur au démarrage et ne peut pas continuer. Copiez les détails pour signaler le problème. Si cela se reproduit, effacer les données permet généralement de relancer l’app.",
    ),
    "initialize": MessageLookupByLibrary.simpleMessage("Initialiser"),
    "initiator": MessageLookupByLibrary.simpleMessage("Initiateur"),
    "initiatorShort": MessageLookupByLibrary.simpleMessage("De"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage(
      "Saisissez un raccourci clavier valide",
    ),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage(
      "Saisissez le nom du groupe de proxys",
    ),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage(
      "Saisissez le contenu de la règle",
    ),
    "installedAppsPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "L’autorisation de la liste des apps a été refusée ; les apps installées ne peuvent donc pas être listées. Veuillez l’accorder manuellement dans les réglages du système.",
    ),
    "installedAppsPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Ce système masque la liste des apps installées tant que l’autorisation n’est pas accordée. Accordez-la pour configurer le proxy par app.",
    ),
    "installedAppsPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Autorisation de la liste des apps requise",
    ),
    "installedFonts": MessageLookupByLibrary.simpleMessage(
      "Polices installées",
    ),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage(
      "Sélection intelligente",
    ),
    "interfaceName": MessageLookupByLibrary.simpleMessage("Nom de l’interface"),
    "interfaceNameDesc": MessageLookupByLibrary.simpleMessage(
      "Le nom de l’interface est l’interface réseau utilisée par les connexions sortantes.",
    ),
    "interfaceNameMode": MessageLookupByLibrary.simpleMessage(
      "Interface sortante",
    ),
    "interfaceNameModeClear": MessageLookupByLibrary.simpleMessage("Aucune"),
    "interfaceNameModeCustom": MessageLookupByLibrary.simpleMessage(
      "Personnalisée",
    ),
    "interfaceNameModeFollow": MessageLookupByLibrary.simpleMessage(
      "Suivre la configuration",
    ),
    "internet": MessageLookupByLibrary.simpleMessage("Internet"),
    "interval": MessageLookupByLibrary.simpleMessage("Intervalle"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("IP du réseau local"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage(
      "Fichier de sauvegarde non valide",
    ),
    "invalidBackupFileName": MessageLookupByLibrary.simpleMessage(
      "Saisissez un nom de fichier valide sans séparateur de chemin ni caractère spécial, de 255 octets maximum.",
    ),
    "invalidCidrContent": MessageLookupByLibrary.simpleMessage(
      "Saisissez une plage d’IP au format CIDR, par exemple 192.168.0.0/16",
    ),
    "invalidDavDirectory": MessageLookupByLibrary.simpleMessage(
      "Saisissez un dossier valide sans segments . ou .., barres obliques inverses ni caractères spéciaux.",
    ),
    "invalidDscpContent": MessageLookupByLibrary.simpleMessage(
      "Une marque DSCP ne peut pas dépasser 63",
    ),
    "invalidHostContent": MessageLookupByLibrary.simpleMessage(
      "Saisissez un domaine ou une adresse IP",
    ),
    "invalidIconSet": MessageLookupByLibrary.simpleMessage(
      "Jeu d’icônes non valide",
    ),
    "invalidLinkTip": MessageLookupByLibrary.simpleMessage(
      "Ce n’est ni un lien d’abonnement ni un lien de partage de proxy",
    ),
    "invalidListenContent": MessageLookupByLibrary.simpleMessage(
      "Saisissez une adresse et un port, par exemple 0.0.0.0:1053",
    ),
    "invalidNetworkContent": MessageLookupByLibrary.simpleMessage(
      "Seuls tcp ou udp sont pris en charge",
    ),
    "invalidPolicy": m37,
    "invalidPortRangeContent": MessageLookupByLibrary.simpleMessage(
      "Saisissez un port ou une plage, par exemple 443 ou 8000-9000",
    ),
    "invalidProfileQrcode": MessageLookupByLibrary.simpleMessage(
      "Ce code QR ne contient pas de lien de profil",
    ),
    "invalidProxy": m38,
    "invalidProxyProvider": m39,
    "invalidRangeContent": MessageLookupByLibrary.simpleMessage(
      "Saisissez des nombres ou des plages tels que 80 ou 8000-9000, séparés par /",
    ),
    "invalidRuleSet": m40,
    "invalidSubRule": m41,
    "ipAddress": MessageLookupByLibrary.simpleMessage("Adresse IP"),
    "ipAsn": MessageLookupByLibrary.simpleMessage("ASN"),
    "ipFlagAbuser": MessageLookupByLibrary.simpleMessage("Antécédents d’abus"),
    "ipFlagProxy": MessageLookupByLibrary.simpleMessage("Proxy"),
    "ipFlagTor": MessageLookupByLibrary.simpleMessage("Tor"),
    "ipFlagVpn": MessageLookupByLibrary.simpleMessage("VPN"),
    "ipFlags": MessageLookupByLibrary.simpleMessage("Indicateurs"),
    "ipOrganization": MessageLookupByLibrary.simpleMessage("Organisation"),
    "ipQualityFailed": MessageLookupByLibrary.simpleMessage(
      "Impossible de déterminer le type de l’IP",
    ),
    "ipQualityGood": MessageLookupByLibrary.simpleMessage("Bonne"),
    "ipQualityLevel": MessageLookupByLibrary.simpleMessage("Niveau"),
    "ipQualityNormal": MessageLookupByLibrary.simpleMessage("Normale"),
    "ipQualityRetry": MessageLookupByLibrary.simpleMessage(
      "Vérifier à nouveau",
    ),
    "ipQualityRisky": MessageLookupByLibrary.simpleMessage("À risque"),
    "ipQualityShort": MessageLookupByLibrary.simpleMessage("Qualité"),
    "ipQualitySource": MessageLookupByLibrary.simpleMessage("Réponse de"),
    "ipQualitySources": MessageLookupByLibrary.simpleMessage("Sources"),
    "ipSourceIpMismatch": MessageLookupByLibrary.simpleMessage(
      "IP sortante différente",
    ),
    "ipSourceNoType": MessageLookupByLibrary.simpleMessage("Aucun type"),
    "ipSourceRateLimited": MessageLookupByLibrary.simpleMessage(
      "Limite de débit atteinte",
    ),
    "ipType": MessageLookupByLibrary.simpleMessage("Type"),
    "ipTypeBusiness": MessageLookupByLibrary.simpleMessage("Entreprise"),
    "ipTypeHosting": MessageLookupByLibrary.simpleMessage("Centre de données"),
    "ipTypeMobile": MessageLookupByLibrary.simpleMessage("Réseau mobile"),
    "ipTypeResidential": MessageLookupByLibrary.simpleMessage("Résidentielle"),
    "ipTypeUnknown": MessageLookupByLibrary.simpleMessage("Type inconnu"),
    "ipVersion": MessageLookupByLibrary.simpleMessage("Version d’IP"),
    "ipcidr": MessageLookupByLibrary.simpleMessage("CIDR IP"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "Le trafic IPv6 n’est reçu que si IPv6 est activé.",
    ),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "Avec IPv6 activé, le VPN autorise le trafic IPv6 entrant.",
    ),
    "ipv6Timeout": MessageLookupByLibrary.simpleMessage(
      "Délai d’expiration IPv6 (ms)",
    ),
    "itemsCount": m42,
    "ja": MessageLookupByLibrary.simpleMessage("Japonais"),
    "justNow": MessageLookupByLibrary.simpleMessage("À l’instant"),
    "keepAliveIdle": MessageLookupByLibrary.simpleMessage(
      "Inactivité keep-alive TCP",
    ),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "Intervalle keep-alive TCP",
    ),
    "key": MessageLookupByLibrary.simpleMessage("Clé"),
    "ko": MessageLookupByLibrary.simpleMessage("Coréen"),
    "label": MessageLookupByLibrary.simpleMessage("Libellé"),
    "language": MessageLookupByLibrary.simpleMessage("Langue"),
    "large": MessageLookupByLibrary.simpleMessage("Grande"),
    "lastUpdated": MessageLookupByLibrary.simpleMessage("Dernière mise à jour"),
    "launchInterrupted": MessageLookupByLibrary.simpleMessage(
      "Démarrage inachevé",
    ),
    "launchInterruptedTip": MessageLookupByLibrary.simpleMessage(
      "L’app s’est arrêtée de façon inattendue lors de son dernier démarrage. La configuration automatique a été ignorée pour ce lancement ; vous pouvez la démarrer manuellement pour réessayer.",
    ),
    "layout": MessageLookupByLibrary.simpleMessage("Disposition"),
    "level": MessageLookupByLibrary.simpleMessage("Niveau"),
    "light": MessageLookupByLibrary.simpleMessage("Clair"),
    "lineHeight": MessageLookupByLibrary.simpleMessage("Interligne"),
    "lineIssueTip": m43,
    "lineWrap": MessageLookupByLibrary.simpleMessage("Retour à la ligne"),
    "link": MessageLookupByLibrary.simpleMessage("Lien"),
    "linkDesc": MessageLookupByLibrary.simpleMessage(
      "Obtenir un profil depuis un lien d’abonnement ou un lien de partage de proxy",
    ),
    "liquidGlass": MessageLookupByLibrary.simpleMessage("Liquid Glass"),
    "list": MessageLookupByLibrary.simpleMessage("Liste"),
    "listen": MessageLookupByLibrary.simpleMessage("Écoute"),
    "listenRoutingMark": MessageLookupByLibrary.simpleMessage(
      "Marque de routage d’écoute",
    ),
    "listenRoutingMarkDesc": MessageLookupByLibrary.simpleMessage(
      "La marque de routage d’écoute ne fonctionne que sous Linux.",
    ),
    "listeningPort": MessageLookupByLibrary.simpleMessage("Port d’écoute"),
    "liveConnections": MessageLookupByLibrary.simpleMessage(
      "Connexions en direct",
    ),
    "loading": MessageLookupByLibrary.simpleMessage("Chargement…"),
    "local": MessageLookupByLibrary.simpleMessage("Local"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Sauvegarder les données localement",
    ),
    "localImage": MessageLookupByLibrary.simpleMessage("Image locale"),
    "localNetworkDeniedTip": MessageLookupByLibrary.simpleMessage(
      "Autorisation du réseau local refusée : la pile gvisor est utilisée, le LAN est inaccessible.",
    ),
    "localProxies": MessageLookupByLibrary.simpleMessage("Proxys locaux"),
    "locationPermission": MessageLookupByLibrary.simpleMessage(
      "Autorisation de localisation",
    ),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "L’autorisation de localisation a été refusée ; le nom du Wi-Fi actuel ne peut donc pas être lu. Veuillez l’activer manuellement dans les réglages du système.",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Le système exige l’autorisation de localisation pour lire le nom du Wi-Fi. Sur Android, choisissez « Toujours autoriser », sinon le nom du Wi-Fi ne peut pas être lu lorsque l’app est en arrière-plan.",
    ),
    "locationPermissionGuide": m44,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Autorisation de localisation requise",
    ),
    "log": MessageLookupByLibrary.simpleMessage("Journal"),
    "logLevel": MessageLookupByLibrary.simpleMessage(
      "Niveau de journalisation",
    ),
    "logcat": MessageLookupByLibrary.simpleMessage("Logcat"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "Désactiver Logcat masque l’entrée Journaux.",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("Journaux"),
    "logsAndDiagnostics": MessageLookupByLibrary.simpleMessage(
      "Journaux et diagnostic",
    ),
    "logsDesc": MessageLookupByLibrary.simpleMessage("Journaux enregistrés"),
    "logsTest": MessageLookupByLibrary.simpleMessage("Test des journaux"),
    "loopback": MessageLookupByLibrary.simpleMessage(
      "Exemption de bouclage UWP",
    ),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage(
      "Utilisé pour l’exemption de bouclage UWP",
    ),
    "loose": MessageLookupByLibrary.simpleMessage("Aérée"),
    "manual": MessageLookupByLibrary.simpleMessage("Manuel"),
    "matchCase": MessageLookupByLibrary.simpleMessage("Respecter la casse"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage(
      "Faire correspondre l’IP source",
    ),
    "matchTarget": MessageLookupByLibrary.simpleMessage("MATCH-TARGET"),
    "matchTargetDesc": MessageLookupByLibrary.simpleMessage(
      "Destination des règles visant MATCH-TARGET. Par défaut, cible de la dernière règle MATCH du profil.",
    ),
    "matchTargetTitle": MessageLookupByLibrary.simpleMessage(
      "Cible de correspondance",
    ),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage("Échecs maximum"),
    "maxLengthTip": m45,
    "maximize": MessageLookupByLibrary.simpleMessage("Agrandir"),
    "memoryApp": MessageLookupByLibrary.simpleMessage(
      "Mémoire de l’application",
    ),
    "memoryAppResident": MessageLookupByLibrary.simpleMessage(
      "Mémoire résidente",
    ),
    "memoryAppShared": MessageLookupByLibrary.simpleMessage("App et partagée"),
    "memoryCleanup": MessageLookupByLibrary.simpleMessage("Nettoyer"),
    "memoryCoreHeapIdle": MessageLookupByLibrary.simpleMessage("Tas inactif"),
    "memoryCoreHeapInuse": MessageLookupByLibrary.simpleMessage("Tas utilisé"),
    "memoryCoreNotRunning": MessageLookupByLibrary.simpleMessage(
      "Le cœur n’est pas en cours d’exécution",
    ),
    "memoryCoreRuntime": MessageLookupByLibrary.simpleMessage(
      "Surcharge du runtime",
    ),
    "memoryCoreStack": MessageLookupByLibrary.simpleMessage(
      "Piles de goroutines",
    ),
    "memoryEstimateDesc": MessageLookupByLibrary.simpleMessage(
      "Estimation d’après la mémoire résidente du processus ; elle peut différer de ce qu’indique le système.",
    ),
    "memoryEstimateSharedDesc": MessageLookupByLibrary.simpleMessage(
      "Le cœur s’exécute dans le processus de l’app. Sa part est estimée à partir des statistiques du runtime, et le reste compte comme mémoire de l’app et partagée.",
    ),
    "memoryFootprint": MessageLookupByLibrary.simpleMessage(
      "Empreinte mémoire",
    ),
    "memoryGC": MessageLookupByLibrary.simpleMessage("Métadonnées du GC"),
    "memoryHeapIdle": MessageLookupByLibrary.simpleMessage(
      "Mémoire inactive conservée du tas",
    ),
    "memoryHeapObjects": MessageLookupByLibrary.simpleMessage("Objets du tas"),
    "memoryHeapReleased": MessageLookupByLibrary.simpleMessage(
      "Rendue au système",
    ),
    "memoryHeapUnused": MessageLookupByLibrary.simpleMessage(
      "Segments inutilisés du tas",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("Infos mémoire"),
    "memoryInfoDesc": MessageLookupByLibrary.simpleMessage(
      "Mémoire utilisée par l’app et le cœur",
    ),
    "memoryMetadata": MessageLookupByLibrary.simpleMessage(
      "Métadonnées d’exécution",
    ),
    "memoryOther": MessageLookupByLibrary.simpleMessage(
      "Autre mémoire d’exécution",
    ),
    "memoryReadFailed": MessageLookupByLibrary.simpleMessage(
      "Impossible de lire la mémoire. Nouvelle tentative…",
    ),
    "memoryReleased": MessageLookupByLibrary.simpleMessage("Mémoire libérée"),
    "memoryReleasedSize": m46,
    "memoryStacks": MessageLookupByLibrary.simpleMessage("Piles"),
    "memoryTotal": MessageLookupByLibrary.simpleMessage(
      "Mémoire utilisée par Go",
    ),
    "messageTest": MessageLookupByLibrary.simpleMessage("Test de message"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage(
      "Ceci est un message.",
    ),
    "minimize": MessageLookupByLibrary.simpleMessage("Réduire"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage(
      "Réduire à la fermeture",
    ),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "Remplacer le comportement de fermeture par défaut du système",
    ),
    "minutes": MessageLookupByLibrary.simpleMessage("minutes"),
    "minutesAgo": m47,
    "minutesAgoShort": m48,
    "mixedPort": MessageLookupByLibrary.simpleMessage("Port mixte"),
    "mode": MessageLookupByLibrary.simpleMessage("Mode"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("Monochrome"),
    "monochromeTrayIcon": MessageLookupByLibrary.simpleMessage(
      "Icône monochrome dans la zone de notification",
    ),
    "monthsAgo": m49,
    "monthsAgoShort": m50,
    "more": MessageLookupByLibrary.simpleMessage("Plus"),
    "mtu": MessageLookupByLibrary.simpleMessage("MTU"),
    "mtuRangeTip": MessageLookupByLibrary.simpleMessage(
      "Le MTU doit être un entier entre 1 et 65535",
    ),
    "multipleValuesTip": MessageLookupByLibrary.simpleMessage(
      "Séparez les valeurs par des virgules",
    ),
    "name": MessageLookupByLibrary.simpleMessage("Nom"),
    "nameserver": MessageLookupByLibrary.simpleMessage("Serveur DNS"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Utilisé pour résoudre les domaines",
    ),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "Politique des serveurs DNS",
    ),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Attribuer des serveurs DNS spécifiques aux domaines, catégories geosite ou ensembles de règles correspondants",
    ),
    "navigationBarStyle": MessageLookupByLibrary.simpleMessage(
      "Barre inférieure",
    ),
    "needsLogin": MessageLookupByLibrary.simpleMessage("Connexion requise"),
    "network": MessageLookupByLibrary.simpleMessage("Réseau"),
    "networkAccessDeniedError": m51,
    "networkBadResponseError": m52,
    "networkCancelledError": MessageLookupByLibrary.simpleMessage(
      "La requête a été annulée",
    ),
    "networkConnectionError": MessageLookupByLibrary.simpleMessage(
      "Impossible de se connecter au serveur. Vérifiez votre connexion réseau ou vos réglages de proxy",
    ),
    "networkDesc": MessageLookupByLibrary.simpleMessage(
      "Régler les paramètres réseau",
    ),
    "networkException": MessageLookupByLibrary.simpleMessage(
      "Erreur réseau. Vérifiez votre connexion et réessayez",
    ),
    "networkExtension": MessageLookupByLibrary.simpleMessage(
      "Extension réseau",
    ),
    "networkHostLookupError": MessageLookupByLibrary.simpleMessage(
      "Impossible de résoudre l’adresse du serveur. Vérifiez que l’URL est correcte et que le DNS fonctionne",
    ),
    "networkId": MessageLookupByLibrary.simpleMessage("Identifiant réseau"),
    "networkName": MessageLookupByLibrary.simpleMessage("Nom du réseau"),
    "networkNotFound": MessageLookupByLibrary.simpleMessage(
      "Réseau introuvable",
    ),
    "networkNotFoundError": m53,
    "networkRateLimitedError": MessageLookupByLibrary.simpleMessage(
      "Trop de requêtes (HTTP 429). Patientez un instant puis réessayez",
    ),
    "networkRequestFailed": m54,
    "networkSecret": MessageLookupByLibrary.simpleMessage("Secret du réseau"),
    "networkServerError": m55,
    "networkSpeed": MessageLookupByLibrary.simpleMessage("Débit réseau"),
    "networkSpeedNotification": MessageLookupByLibrary.simpleMessage(
      "Afficher la vitesse réseau en temps réel",
    ),
    "networkSpeedNotificationDesc": MessageLookupByLibrary.simpleMessage(
      "Afficher la vitesse réseau dans la zone d’état du système ; peut légèrement augmenter la consommation d’énergie",
    ),
    "networkTakeover": MessageLookupByLibrary.simpleMessage(
      "Prise en charge du trafic",
    ),
    "networkTimeoutError": MessageLookupByLibrary.simpleMessage(
      "La requête a expiré. Vérifiez votre réseau ou votre proxy, puis réessayez",
    ),
    "networkTlsError": MessageLookupByLibrary.simpleMessage(
      "Échec de la connexion sécurisée. Le certificat du serveur est peut-être invalide, ou la connexion est interceptée",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("Type de réseau"),
    "networking": MessageLookupByLibrary.simpleMessage("Mise en réseau"),
    "networkingDesc": MessageLookupByLibrary.simpleMessage(
      "Afficher l’état des réseaux P2P",
    ),
    "networkingError": MessageLookupByLibrary.simpleMessage("Erreur"),
    "networkingNoOutbounds": MessageLookupByLibrary.simpleMessage(
      "Aucune sortie P2P dans la configuration actuelle",
    ),
    "newProfile": MessageLookupByLibrary.simpleMessage("Nouveau"),
    "newProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Rédiger un profil manuellement",
    ),
    "nextMatch": MessageLookupByLibrary.simpleMessage("Résultat suivant"),
    "no": MessageLookupByLibrary.simpleMessage("Non"),
    "noData": MessageLookupByLibrary.simpleMessage("Aucune donnée"),
    "noDirectories": MessageLookupByLibrary.simpleMessage("Aucun sous-dossier"),
    "noFilterCondition": MessageLookupByLibrary.simpleMessage(
      "Aucune condition de filtre",
    ),
    "noHotKey": MessageLookupByLibrary.simpleMessage("Aucun raccourci clavier"),
    "noInfo": MessageLookupByLibrary.simpleMessage("Aucune information"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage(
      "Ne plus me le rappeler",
    ),
    "noNetwork": MessageLookupByLibrary.simpleMessage("Aucun réseau"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("Apps sans réseau"),
    "noRemoteBackups": MessageLookupByLibrary.simpleMessage(
      "Aucune sauvegarde distante trouvée",
    ),
    "noResolve": MessageLookupByLibrary.simpleMessage("Ne pas résoudre l’IP"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage(
      "Ne pas résoudre le nom d’hôte",
    ),
    "noSearchResults": MessageLookupByLibrary.simpleMessage("Aucun résultat"),
    "nodeTrafficReadFailed": MessageLookupByLibrary.simpleMessage(
      "Impossible de lire le trafic. Nouvelle tentative…",
    ),
    "nodeTrafficUsage": MessageLookupByLibrary.simpleMessage(
      "Trafic des nœuds",
    ),
    "nodes": MessageLookupByLibrary.simpleMessage("Nœuds"),
    "nonTextProviderFile": MessageLookupByLibrary.simpleMessage(
      "Cette ressource externe n’est pas un fichier texte",
    ),
    "none": MessageLookupByLibrary.simpleMessage("Aucun"),
    "notRunning": MessageLookupByLibrary.simpleMessage("À l’arrêt"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "Le groupe de proxys actuel n’est pas sélectionnable",
    ),
    "ntpDesc": MessageLookupByLibrary.simpleMessage(
      "Modifier les paramètres NTP",
    ),
    "ntpInterval": MessageLookupByLibrary.simpleMessage(
      "Intervalle de synchronisation (minutes)",
    ),
    "ntpStatusDesc": MessageLookupByLibrary.simpleMessage(
      "NTP récupère l’heure auprès d’un serveur NTP au lieu de l’horloge système.",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Ajoutez un profil pour commencer",
    ),
    "nullTip": m56,
    "numberRangeTip": m57,
    "numberTip": m58,
    "obfs": MessageLookupByLibrary.simpleMessage("Obfuscation"),
    "obfsHost": MessageLookupByLibrary.simpleMessage("Hôte d’obfuscation"),
    "obfsMode": MessageLookupByLibrary.simpleMessage("Mode d’obfuscation"),
    "obfsParam": MessageLookupByLibrary.simpleMessage(
      "Paramètre d’obfuscation",
    ),
    "obfsPassword": MessageLookupByLibrary.simpleMessage(
      "Mot de passe d’obfuscation",
    ),
    "offline": MessageLookupByLibrary.simpleMessage("Hors ligne"),
    "onDemand": MessageLookupByLibrary.simpleMessage("À la demande"),
    "onDemandDesc": MessageLookupByLibrary.simpleMessage(
      "À la demande met le proxy en pause sur les Wi-Fi exclus.",
    ),
    "online": MessageLookupByLibrary.simpleMessage("En ligne"),
    "onlyConfig": MessageLookupByLibrary.simpleMessage(
      "Configuration uniquement",
    ),
    "onlyEmoji": MessageLookupByLibrary.simpleMessage("Émojis uniquement"),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("Icône uniquement"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "Ne compter que le trafic proxy",
    ),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Compter uniquement le trafic du proxy lorsque cette option est activée",
    ),
    "openInGitHub": MessageLookupByLibrary.simpleMessage("Ouvrir dans GitHub"),
    "optional": MessageLookupByLibrary.simpleMessage("Facultatif"),
    "options": MessageLookupByLibrary.simpleMessage("Options"),
    "other": MessageLookupByLibrary.simpleMessage("Autre"),
    "otherContributors": MessageLookupByLibrary.simpleMessage(
      "Autres contributeurs",
    ),
    "outbound": MessageLookupByLibrary.simpleMessage("Sortant"),
    "outboundExit": MessageLookupByLibrary.simpleMessage("Sortie"),
    "outboundIp": MessageLookupByLibrary.simpleMessage("IP sortante"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("Mode sortant"),
    "override": MessageLookupByLibrary.simpleMessage("Remplacement"),
    "overrideDestination": MessageLookupByLibrary.simpleMessage(
      "Remplacer la destination",
    ),
    "overrideDestinationDesc": MessageLookupByLibrary.simpleMessage(
      "Remplacer la destination se connecte au domaine détecté plutôt qu’à l’adresse d’origine.",
    ),
    "overrideDns": MessageLookupByLibrary.simpleMessage("Remplacer le DNS"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "Remplacer les options DNS du profil lorsque cette option est activée",
    ),
    "overrideEntries": MessageLookupByLibrary.simpleMessage(
      "Entrées de remplacement",
    ),
    "overrideMode": MessageLookupByLibrary.simpleMessage(
      "Mode de remplacement",
    ),
    "overrideNtp": MessageLookupByLibrary.simpleMessage("Remplacer le NTP"),
    "overrideNtpDesc": MessageLookupByLibrary.simpleMessage(
      "Remplacer les options NTP du profil lorsque cette option est activée",
    ),
    "overrideScript": MessageLookupByLibrary.simpleMessage(
      "Script de remplacement",
    ),
    "overwriteTypeCustom": MessageLookupByLibrary.simpleMessage("Personnalisé"),
    "overwriteTypeCustomDesc": MessageLookupByLibrary.simpleMessage(
      "Mode personnalisé : personnaliser entièrement les groupes de proxys et les règles",
    ),
    "parentDirectory": MessageLookupByLibrary.simpleMessage("Dossier parent"),
    "parsePureIp": MessageLookupByLibrary.simpleMessage(
      "Analyser les IP seules",
    ),
    "parsePureIpDesc": MessageLookupByLibrary.simpleMessage(
      "Analyser les IP seules inspecte les connexions qui ne portent qu’une adresse IP.",
    ),
    "password": MessageLookupByLibrary.simpleMessage("Mot de passe"),
    "paste": MessageLookupByLibrary.simpleMessage("Coller"),
    "peers": MessageLookupByLibrary.simpleMessage("Pairs"),
    "pickFromAlbum": MessageLookupByLibrary.simpleMessage(
      "Choisir dans l’album",
    ),
    "pinWindow": MessageLookupByLibrary.simpleMessage("Épingler la fenêtre"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "Veuillez lier un WebDAV",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "Veuillez saisir un nom de script",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "Veuillez importer un code QR valide",
    ),
    "plugin": MessageLookupByLibrary.simpleMessage("Plugin"),
    "pluginHost": MessageLookupByLibrary.simpleMessage("Hôte du plugin"),
    "pluginMode": MessageLookupByLibrary.simpleMessage("Mode du plugin"),
    "port": MessageLookupByLibrary.simpleMessage("Port"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "Veuillez saisir un autre port",
    ),
    "portHopping": MessageLookupByLibrary.simpleMessage("Saut de port"),
    "portTip": m59,
    "portValue": m60,
    "ports": MessageLookupByLibrary.simpleMessage("Ports"),
    "positiveIntegerTip": MessageLookupByLibrary.simpleMessage(
      "Saisissez un entier supérieur à 0",
    ),
    "preSharedKey": MessageLookupByLibrary.simpleMessage("Clé prépartagée"),
    "predictiveBack": MessageLookupByLibrary.simpleMessage("Retour prédictif"),
    "preferH3": MessageLookupByLibrary.simpleMessage("Privilégier HTTP/3"),
    "preferH3Desc": MessageLookupByLibrary.simpleMessage(
      "Privilégier HTTP/3 pour DoH",
    ),
    "prerequisites": MessageLookupByLibrary.simpleMessage("Prérequis"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage(
      "Appuyez sur une combinaison de touches",
    ),
    "preview": MessageLookupByLibrary.simpleMessage("Aperçu"),
    "previousMatch": MessageLookupByLibrary.simpleMessage("Résultat précédent"),
    "privateKey": MessageLookupByLibrary.simpleMessage("Clé privée"),
    "privateKeyPassphrase": MessageLookupByLibrary.simpleMessage(
      "Phrase secrète de la clé privée",
    ),
    "process": MessageLookupByLibrary.simpleMessage("Processus"),
    "profile": MessageLookupByLibrary.simpleMessage("Profil"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "Veuillez saisir un intervalle valide",
        ),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "Veuillez saisir l’intervalle de mise à jour automatique",
        ),
    "profileDaysLeft": m61,
    "profileExpiresIn": m62,
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "Le profil a été modifié. Désactiver la mise à jour automatique ?",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Veuillez saisir le nom du profil",
    ),
    "profileSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "S’applique uniquement à ce profil ; tout ce qui n’est pas ajouté utilise la valeur par défaut.",
    ),
    "profileTunSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "S’applique uniquement à ce profil et prime sur les entrées de remplacement TUN des réglages réseau.",
    ),
    "profileUpdatedAt": m63,
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Veuillez saisir une URL de profil valide",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Veuillez saisir l’URL du profil",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("Profils"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("Trier les profils"),
    "project": MessageLookupByLibrary.simpleMessage("Projet"),
    "promptCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Demander la fermeture des connexions",
    ),
    "promptCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Demander s’il faut fermer les connexions après un changement de nœud",
    ),
    "protocol": MessageLookupByLibrary.simpleMessage("Protocole"),
    "protocolParam": MessageLookupByLibrary.simpleMessage(
      "Paramètre du protocole",
    ),
    "protocolVersion": MessageLookupByLibrary.simpleMessage(
      "Version du protocole",
    ),
    "providerInUse": m64,
    "providerUrlTip": MessageLookupByLibrary.simpleMessage(
      "Seuls les fournisseurs distants sont pris en charge",
    ),
    "providers": MessageLookupByLibrary.simpleMessage("Ressources externes"),
    "proxies": MessageLookupByLibrary.simpleMessage("Proxys"),
    "proxiesCount": m65,
    "proxiesProfileLabel": m66,
    "proxiesRemovedTip": m67,
    "proxiesReplacedTip": m68,
    "proxy": MessageLookupByLibrary.simpleMessage("Proxy"),
    "proxyChains": MessageLookupByLibrary.simpleMessage("Chaîne de proxys"),
    "proxyDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Les proxys sélectionnés présentent une anomalie",
    ),
    "proxyFilter": MessageLookupByLibrary.simpleMessage("Filtre de proxys"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("Groupe de proxys"),
    "proxyGroupDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Le groupe de proxys actuel présente une anomalie",
    ),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage(
      "Le groupe de proxys est vide",
    ),
    "proxyGroupInUse": m69,
    "proxyGroupNameEmpty": MessageLookupByLibrary.simpleMessage(
      "Le nom du groupe de proxys ne peut pas être vide",
    ),
    "proxyGroupsAfterStart": MessageLookupByLibrary.simpleMessage(
      "Les groupes s’affichent ici une fois le cœur démarré",
    ),
    "proxyGroupsCount": m70,
    "proxyNameserver": MessageLookupByLibrary.simpleMessage(
      "Serveur DNS des proxys",
    ),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Utilisé pour résoudre les domaines des nœuds proxy",
    ),
    "proxyNameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "Politique DNS des proxys",
    ),
    "proxyNameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Définir la politique des serveurs DNS pour les nœuds proxy",
    ),
    "proxyProvider": MessageLookupByLibrary.simpleMessage(
      "Fournisseur de proxys",
    ),
    "proxyProviderDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Les fournisseurs de proxys sélectionnés présentent une anomalie",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage(
      "Fournisseurs de proxys",
    ),
    "proxyType": MessageLookupByLibrary.simpleMessage("Type de proxy"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("Nettoyer le cache"),
    "publicKey": MessageLookupByLibrary.simpleMessage("Clé publique"),
    "pureBlack": MessageLookupByLibrary.simpleMessage("Noir pur"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("Mode noir pur"),
    "qrcode": MessageLookupByLibrary.simpleMessage("Code QR"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "Scannez un code QR pour obtenir un profil",
    ),
    "query": MessageLookupByLibrary.simpleMessage("Interroger"),
    "queryDns": MessageLookupByLibrary.simpleMessage("Interroger le DNS"),
    "queryRule": MessageLookupByLibrary.simpleMessage("Interroger les règles"),
    "quickActions": MessageLookupByLibrary.simpleMessage("Actions rapides"),
    "quickEdit": MessageLookupByLibrary.simpleMessage("Modification rapide"),
    "quickFill": MessageLookupByLibrary.simpleMessage("Remplissage rapide"),
    "random": MessageLookupByLibrary.simpleMessage("Aléatoire"),
    "recentRequests": MessageLookupByLibrary.simpleMessage("Requêtes récentes"),
    "recommendedIcons": MessageLookupByLibrary.simpleMessage("Suggestions"),
    "recordType": MessageLookupByLibrary.simpleMessage("Type d’enregistrement"),
    "recvMsgX": MessageLookupByLibrary.simpleMessage("Activer RecvMsgX"),
    "recvMsgXDesc": MessageLookupByLibrary.simpleMessage(
      "Recevoir les paquets par lots sur Darwin",
    ),
    "redirPort": MessageLookupByLibrary.simpleMessage("Port Redir"),
    "redo": MessageLookupByLibrary.simpleMessage("Rétablir"),
    "regex": MessageLookupByLibrary.simpleMessage("Regex"),
    "regexSearch": MessageLookupByLibrary.simpleMessage(
      "Recherche par expression régulière",
    ),
    "relayed": MessageLookupByLibrary.simpleMessage("Relayé"),
    "releaseMemory": MessageLookupByLibrary.simpleMessage("Libérer la mémoire"),
    "releaseMemoryFailed": MessageLookupByLibrary.simpleMessage(
      "Échec de la libération de la mémoire",
    ),
    "remote": MessageLookupByLibrary.simpleMessage("Distant"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Sauvegarder les données sur WebDAV",
    ),
    "remoteDestination": MessageLookupByLibrary.simpleMessage(
      "Destination distante",
    ),
    "remoteDnsResolve": MessageLookupByLibrary.simpleMessage(
      "Résolution DNS distante",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("Retirer"),
    "rename": MessageLookupByLibrary.simpleMessage("Renommer"),
    "replace": MessageLookupByLibrary.simpleMessage("Remplacer"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("Tout remplacer"),
    "request": MessageLookupByLibrary.simpleMessage("Requête"),
    "requests": MessageLookupByLibrary.simpleMessage("Requêtes"),
    "requestsAndUpdates": MessageLookupByLibrary.simpleMessage(
      "Requêtes et mises à jour",
    ),
    "requestsDesc": MessageLookupByLibrary.simpleMessage(
      "Afficher les requêtes récentes",
    ),
    "required": MessageLookupByLibrary.simpleMessage("Obligatoire"),
    "reset": MessageLookupByLibrary.simpleMessage("Réinitialiser"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "Cette page contient des modifications. Voulez-vous vraiment réinitialiser ?",
    ),
    "resetProfilesAndScripts": MessageLookupByLibrary.simpleMessage(
      "Profils et scripts",
    ),
    "resetSettingsData": MessageLookupByLibrary.simpleMessage(
      "Paramètres de l’application",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage(
      "Voulez-vous vraiment réinitialiser ?",
    ),
    "resourceUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Intervalle de mise à jour automatique",
    ),
    "resourceUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "L’intervalle de mise à jour automatique doit être supérieur à 0",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("Ressources"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage(
      "Informations sur les ressources externes",
    ),
    "respectRules": MessageLookupByLibrary.simpleMessage(
      "Respecter les règles",
    ),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "Respecter les règles fait passer les connexions DNS selon les règles et nécessite un Proxy Server Nameserver.",
    ),
    "responseCode": MessageLookupByLibrary.simpleMessage("Code de réponse"),
    "restart": MessageLookupByLibrary.simpleMessage("Redémarrer"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Voulez-vous vraiment redémarrer le cœur ?",
    ),
    "restore": MessageLookupByLibrary.simpleMessage("Restaurer"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage(
      "Restaurer toutes les données",
    ),
    "restoreException": MessageLookupByLibrary.simpleMessage(
      "Erreur de restauration",
    ),
    "restoreFromFileDesc": MessageLookupByLibrary.simpleMessage(
      "Restaurer les données depuis un fichier",
    ),
    "restoreFromWebDAVDesc": MessageLookupByLibrary.simpleMessage(
      "Restaurer les données depuis WebDAV",
    ),
    "restoreHiddenGroups": MessageLookupByLibrary.simpleMessage(
      "Rétablir les groupes masqués",
    ),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage(
      "Restaurer uniquement les profils",
    ),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage(
      "Stratégie de restauration",
    ),
    "restoreStrategyCompatible": MessageLookupByLibrary.simpleMessage(
      "Compatible",
    ),
    "restoreStrategyOverride": MessageLookupByLibrary.simpleMessage("Écraser"),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage(
      "Restauration réussie",
    ),
    "result": MessageLookupByLibrary.simpleMessage("Résultat"),
    "retry": MessageLookupByLibrary.simpleMessage("Réessayer"),
    "role": MessageLookupByLibrary.simpleMessage("Rôle"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("Adresses de route"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage(
      "Configurer les adresses des routes écoutées",
    ),
    "routeExcludeAddress": MessageLookupByLibrary.simpleMessage(
      "Adresses de route exclues",
    ),
    "routeMode": MessageLookupByLibrary.simpleMessage("Mode de routage"),
    "routeModeBypassPrivate": MessageLookupByLibrary.simpleMessage(
      "Contourner les adresses privées",
    ),
    "routeModeConfig": MessageLookupByLibrary.simpleMessage(
      "Utiliser la configuration",
    ),
    "routes": MessageLookupByLibrary.simpleMessage("Routes"),
    "routingMark": MessageLookupByLibrary.simpleMessage("Marque de routage"),
    "ru": MessageLookupByLibrary.simpleMessage("Russe"),
    "rule": MessageLookupByLibrary.simpleMessage("Règle"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage(
      "Règle logique ET",
    ),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au domaine complet",
    ),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à un mot-clé de domaine",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à une regex de domaine",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à un suffixe de domaine",
    ),
    "ruleActionDomainWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Correspondance par caractères génériques ; seuls * et ? sont pris en charge",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à la marque DSCP (entrant UDP tproxy uniquement)",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à la plage de ports de destination",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au code pays de l’IP",
    ),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond aux domaines de Geosite",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au nom entrant",
    ),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au port entrant",
    ),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au type entrant",
    ),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au nom d’utilisateur entrant ; séparez plusieurs noms par /",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à l’ASN de l’IP",
    ),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "Correspond à une plage d’adresses IP ; IP-CIDR6 n’est qu’un alias",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à une plage d’adresses IP",
    ),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à une plage de suffixes d’IP",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à toutes les requêtes, sans condition",
    ),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à TCP ou UDP",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage(
      "Règle logique NON",
    ),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage(
      "Règle logique OU",
    ),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au nom du processus ; correspond au nom du paquet sur Android",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond par regex au nom du processus ; correspond au nom du paquet sur Android",
    ),
    "ruleActionProcessNameWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond par caractères génériques au nom du processus ; seuls * et ? sont pris en charge",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au chemin complet du processus",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond par regex au chemin du processus",
    ),
    "ruleActionProcessPathWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond par caractères génériques au chemin du processus ; seuls * et ? sont pris en charge",
    ),
    "ruleActionRematchNameDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au nom de rematch ; séparez plusieurs noms par /",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "Référence un jeu de règles ; nécessite rule-providers",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au code pays de l’IP source",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à l’ASN de l’IP source",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à une plage d’adresses IP source",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à une plage de suffixes d’IP source",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à la plage de ports source",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond vers une sous-règle ; attention aux parenthèses",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à l’ID d’utilisateur Linux",
    ),
    "ruleDisabled": MessageLookupByLibrary.simpleMessage("Désactivée"),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("La règle est vide"),
    "ruleEnabled": MessageLookupByLibrary.simpleMessage("Activée"),
    "ruleHits": MessageLookupByLibrary.simpleMessage("Correspondances"),
    "ruleLastHit": MessageLookupByLibrary.simpleMessage(
      "Dernière correspondance",
    ),
    "ruleLastMiss": MessageLookupByLibrary.simpleMessage(
      "Dernière non-correspondance",
    ),
    "ruleListInvalid": MessageLookupByLibrary.simpleMessage(
      "Les règles doivent former une liste YAML avec une règle par élément, par exemple - DOMAIN,example.com,DIRECT",
    ),
    "ruleMisses": MessageLookupByLibrary.simpleMessage("Non-correspondances"),
    "rulePresetBittorrentDirect": MessageLookupByLibrary.simpleMessage(
      "BitTorrent en direct",
    ),
    "rulePresetBlockDot": MessageLookupByLibrary.simpleMessage(
      "Bloquer DNS over TLS",
    ),
    "rulePresetBlockLoopback": MessageLookupByLibrary.simpleMessage(
      "Bloquer le bouclage du proxy",
    ),
    "rulePresetBlockQuic": MessageLookupByLibrary.simpleMessage("Bloquer QUIC"),
    "rulePresetBlockStun": MessageLookupByLibrary.simpleMessage("Bloquer STUN"),
    "rulePresetLanDirect": MessageLookupByLibrary.simpleMessage(
      "LAN en direct",
    ),
    "rulePresetSystemServicesDirect": MessageLookupByLibrary.simpleMessage(
      "Apple et Microsoft en direct",
    ),
    "ruleProviders": MessageLookupByLibrary.simpleMessage(
      "Fournisseurs de règles",
    ),
    "ruleQueryDestinationIP": MessageLookupByLibrary.simpleMessage(
      "IP de destination",
    ),
    "ruleQueryInboundName": MessageLookupByLibrary.simpleMessage(
      "Nom de l’entrée",
    ),
    "ruleQueryInboundUser": MessageLookupByLibrary.simpleMessage(
      "Utilisateur de l’entrée",
    ),
    "ruleQueryInvalidIP": MessageLookupByLibrary.simpleMessage(
      "Saisissez une adresse IP valide.",
    ),
    "ruleQueryNoMatch": MessageLookupByLibrary.simpleMessage(
      "Aucune règle correspondante (politique du mode ou repli DIRECT)",
    ),
    "ruleQueryNumberRange": m71,
    "ruleQueryPortInvalid": MessageLookupByLibrary.simpleMessage(
      "Saisissez un port entre 1 et 65535.",
    ),
    "ruleQueryProcessPath": MessageLookupByLibrary.simpleMessage(
      "Chemin du processus",
    ),
    "ruleQuerySniffHost": MessageLookupByLibrary.simpleMessage(
      "Domaine détecté",
    ),
    "ruleQuerySourcePort": MessageLookupByLibrary.simpleMessage("Port source"),
    "ruleQueryTarget": MessageLookupByLibrary.simpleMessage(
      "Domaine ou adresse IP",
    ),
    "ruleSet": MessageLookupByLibrary.simpleMessage("Jeu de règles"),
    "ruleSetEmptyTip": MessageLookupByLibrary.simpleMessage(
      "Le jeu de règles ne contient aucune entrée exploitable",
    ),
    "ruleSetInvalidTip": MessageLookupByLibrary.simpleMessage(
      "Ce fichier mrs est illisible",
    ),
    "ruleSetMixedTip": MessageLookupByLibrary.simpleMessage(
      "Le jeu de règles mélange des domaines et des plages d’IP : son type est indéterminable",
    ),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("Cible de la règle"),
    "ruleTextInvalid": MessageLookupByLibrary.simpleMessage(
      "La règle doit commencer par un type pris en charge, par exemple DOMAIN,example.com,DIRECT",
    ),
    "ruleType": MessageLookupByLibrary.simpleMessage("Type de règle"),
    "ruleUpdateFailed": MessageLookupByLibrary.simpleMessage(
      "Impossible de modifier la règle. La configuration a peut-être changé ; actualisez et réessayez.",
    ),
    "rules": MessageLookupByLibrary.simpleMessage("Règles"),
    "rulesCount": m72,
    "rulesDesc": MessageLookupByLibrary.simpleMessage(
      "Afficher les règles et leurs statistiques de correspondance",
    ),
    "runTime": MessageLookupByLibrary.simpleMessage("Durée d’exécution"),
    "running": MessageLookupByLibrary.simpleMessage("En cours d’exécution"),
    "runtimeConfig": MessageLookupByLibrary.simpleMessage(
      "Configuration d’exécution",
    ),
    "safeMode": MessageLookupByLibrary.simpleMessage("Mode sans échec"),
    "safeModeAppTitle": m73,
    "saturation": MessageLookupByLibrary.simpleMessage("Saturation"),
    "save": MessageLookupByLibrary.simpleMessage("Enregistrer"),
    "saveChanges": MessageLookupByLibrary.simpleMessage(
      "Enregistrer les modifications ?",
    ),
    "script": MessageLookupByLibrary.simpleMessage("Script"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "Mode script : réécrit tout le profil avec un script d’extension",
    ),
    "scrollToSelected": MessageLookupByLibrary.simpleMessage(
      "Défiler jusqu’à la sélection",
    ),
    "search": MessageLookupByLibrary.simpleMessage("Rechercher"),
    "seconds": MessageLookupByLibrary.simpleMessage("secondes"),
    "secondsCount": m74,
    "secretKey": MessageLookupByLibrary.simpleMessage("Clé"),
    "sectionsInEffect": m75,
    "selectAll": MessageLookupByLibrary.simpleMessage("Tout sélectionner"),
    "selectMatchTarget": MessageLookupByLibrary.simpleMessage(
      "Sélectionner MATCH-TARGET",
    ),
    "selectRemoteBackup": MessageLookupByLibrary.simpleMessage(
      "Sélectionner une sauvegarde",
    ),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage(
      "Veuillez sélectionner un jeu de règles",
    ),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage(
      "Veuillez sélectionner une stratégie de répartition",
    ),
    "selected": MessageLookupByLibrary.simpleMessage("Sélectionné"),
    "sendMsgX": MessageLookupByLibrary.simpleMessage("Activer SendMsgX"),
    "sendMsgXDesc": MessageLookupByLibrary.simpleMessage(
      "Envoyer les paquets par lots sur Darwin",
    ),
    "server": MessageLookupByLibrary.simpleMessage("Serveur"),
    "serviceAbnormalCount": m76,
    "serviceAllAvailable": MessageLookupByLibrary.simpleMessage(
      "Tout est disponible",
    ),
    "serviceAvailable": MessageLookupByLibrary.simpleMessage("Disponible"),
    "serviceBlocked": MessageLookupByLibrary.simpleMessage("Bloqué"),
    "serviceCheck": MessageLookupByLibrary.simpleMessage("Vérifier"),
    "serviceCheckAll": MessageLookupByLibrary.simpleMessage("Tout vérifier"),
    "serviceCheckedAt": m77,
    "serviceComingSoon": MessageLookupByLibrary.simpleMessage(
      "Bientôt disponible",
    ),
    "serviceDisallowedIsp": MessageLookupByLibrary.simpleMessage(
      "FAI non autorisé",
    ),
    "serviceFailed": MessageLookupByLibrary.simpleMessage(
      "Échec de la vérification",
    ),
    "serviceManage": MessageLookupByLibrary.simpleMessage("Gérer les services"),
    "serviceOriginalsOnly": MessageLookupByLibrary.simpleMessage(
      "Contenus originaux uniquement",
    ),
    "servicePending": MessageLookupByLibrary.simpleMessage("Non vérifié"),
    "serviceRestricted": MessageLookupByLibrary.simpleMessage(
      "Accès restreint",
    ),
    "serviceShownOnDashboard": MessageLookupByLibrary.simpleMessage(
      "Affiché sur le tableau de bord",
    ),
    "serviceStatus": MessageLookupByLibrary.simpleMessage("État des services"),
    "serviceUnavailable": MessageLookupByLibrary.simpleMessage("Indisponible"),
    "serviceUnsupportedRegion": MessageLookupByLibrary.simpleMessage(
      "Région non prise en charge",
    ),
    "settingEntries": MessageLookupByLibrary.simpleMessage("réglages"),
    "settings": MessageLookupByLibrary.simpleMessage("Paramètres"),
    "settingsCount": m78,
    "shareLinkUnreadable": m79,
    "shareLinksInvalid": MessageLookupByLibrary.simpleMessage(
      "Aucun proxy n’a pu être lu dans les liens",
    ),
    "show": MessageLookupByLibrary.simpleMessage("Afficher"),
    "showHiddenGroups": MessageLookupByLibrary.simpleMessage(
      "Afficher les groupes masqués",
    ),
    "showLess": MessageLookupByLibrary.simpleMessage("Réduire"),
    "showMore": MessageLookupByLibrary.simpleMessage("Développer"),
    "showNotificationStopAction": MessageLookupByLibrary.simpleMessage(
      "Bouton Arrêter dans la notification",
    ),
    "showNotificationStopActionDesc": MessageLookupByLibrary.simpleMessage(
      "Afficher un bouton d’arrêt dans la notification persistante. Désactivez-le si votre système garde la notification déployée à cause de ce bouton",
    ),
    "showPassword": MessageLookupByLibrary.simpleMessage(
      "Afficher le mot de passe",
    ),
    "showQuickSettingsProfileName": MessageLookupByLibrary.simpleMessage(
      "Afficher le nom du profil actuel",
    ),
    "showQuickSettingsProfileNameDesc": MessageLookupByLibrary.simpleMessage(
      "Afficher le nom du profil sur la tuile rapide lorsque la connexion est établie",
    ),
    "showTrayProxySelection": MessageLookupByLibrary.simpleMessage(
      "Afficher le choix du proxy dans la zone de notification",
    ),
    "showTrayProxySelectionDesc": MessageLookupByLibrary.simpleMessage(
      "Afficher les groupes et les nœuds proxy dans le menu de la zone de notification pour changer rapidement",
    ),
    "showUnavailable": MessageLookupByLibrary.simpleMessage(
      "Afficher les délais dépassés",
    ),
    "sidebarBlur": MessageLookupByLibrary.simpleMessage(
      "Flou de la barre latérale",
    ),
    "sidebarBlurDesc": MessageLookupByLibrary.simpleMessage(
      "Afficher le bureau flouté derrière la fenêtre à travers la barre latérale",
    ),
    "signIn": MessageLookupByLibrary.simpleMessage("Se connecter"),
    "signOut": MessageLookupByLibrary.simpleMessage("Se déconnecter"),
    "signedIn": MessageLookupByLibrary.simpleMessage("Connecté"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage(
      "Lancement silencieux",
    ),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Le lancement silencieux démarre l’app sans afficher la fenêtre.",
    ),
    "singleAdd": MessageLookupByLibrary.simpleMessage("Ajout unique"),
    "singleImport": MessageLookupByLibrary.simpleMessage("Importation unique"),
    "singleShareLinkOnly": MessageLookupByLibrary.simpleMessage(
      "Saisissez un seul lien ici ; pour en modifier plusieurs, utilisez la modification rapide de la liste",
    ),
    "singleValueTip": m80,
    "size": MessageLookupByLibrary.simpleMessage("Taille"),
    "skipCertVerify": MessageLookupByLibrary.simpleMessage(
      "Ignorer la vérification du certificat",
    ),
    "skipDomain": MessageLookupByLibrary.simpleMessage("Domaines ignorés"),
    "skipDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Un domaine détecté figurant dans la liste des domaines ignorés n’est pas utilisé.",
    ),
    "skipDstAddress": MessageLookupByLibrary.simpleMessage(
      "Adresses de destination ignorées",
    ),
    "skipSrcAddress": MessageLookupByLibrary.simpleMessage(
      "Adresses sources ignorées",
    ),
    "slide": MessageLookupByLibrary.simpleMessage("Glissement"),
    "sliders": MessageLookupByLibrary.simpleMessage("Curseurs"),
    "small": MessageLookupByLibrary.simpleMessage("Petit"),
    "sniffProtocols": MessageLookupByLibrary.simpleMessage("Protocoles"),
    "sniffer": MessageLookupByLibrary.simpleMessage("Sniffer"),
    "snifferStatusDesc": MessageLookupByLibrary.simpleMessage(
      "Le sniffer lit le domaine dans le trafic TLS, HTTP et QUIC afin que les règles puissent le reconnaître.",
    ),
    "socksPort": MessageLookupByLibrary.simpleMessage("Port SOCKS"),
    "softStyle": MessageLookupByLibrary.simpleMessage("Doux"),
    "sort": MessageLookupByLibrary.simpleMessage("Trier"),
    "source": MessageLookupByLibrary.simpleMessage("Source"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("IP source"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("Proxy spécial"),
    "specialRules": MessageLookupByLibrary.simpleMessage("Règles spéciales"),
    "spectrum": MessageLookupByLibrary.simpleMessage("Spectre"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage(
      "Statistiques de débit",
    ),
    "splitStrategy": MessageLookupByLibrary.simpleMessage(
      "Stratégie de répartition",
    ),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage(
      "La stratégie de répartition ne peut pas être vide",
    ),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("Les SSID sont vides"),
    "stackMode": MessageLookupByLibrary.simpleMessage("Mode de pile"),
    "stackTrace": MessageLookupByLibrary.simpleMessage("Trace de pile"),
    "standard": MessageLookupByLibrary.simpleMessage("Standard"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "Mode standard : ajoute des règles par-dessus le profil",
    ),
    "start": MessageLookupByLibrary.simpleMessage("Démarrer"),
    "startFromScratch": MessageLookupByLibrary.simpleMessage("Partir de zéro"),
    "startVpn": MessageLookupByLibrary.simpleMessage("Démarrage du VPN…"),
    "startupAndBackground": MessageLookupByLibrary.simpleMessage(
      "Démarrage et arrière-plan",
    ),
    "status": MessageLookupByLibrary.simpleMessage("État"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "Si DNS est désactivé, le DNS du système est utilisé.",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("Arrêter"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("Arrêt du VPN…"),
    "stopped": MessageLookupByLibrary.simpleMessage("Arrêté"),
    "strategy": MessageLookupByLibrary.simpleMessage("Stratégie"),
    "strictRoute": MessageLookupByLibrary.simpleMessage("Route stricte"),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "La route stricte empêche le trafic tel que le DNS de contourner TUN et, avec IPv6 désactivé, bloque les connexions IPv6 de cet appareil.",
    ),
    "style": MessageLookupByLibrary.simpleMessage("Style"),
    "styleSettings": MessageLookupByLibrary.simpleMessage(
      "Paramètres de style",
    ),
    "submit": MessageLookupByLibrary.simpleMessage("Valider"),
    "subscriptionInfo": MessageLookupByLibrary.simpleMessage(
      "Infos d’abonnement",
    ),
    "sudoPasswordTitle": MessageLookupByLibrary.simpleMessage(
      "Saisissez votre mot de passe pour sudo",
    ),
    "suspendSupport": MessageLookupByLibrary.simpleMessage(
      "Prise en charge de la suspension",
    ),
    "suspendSupportDesc": MessageLookupByLibrary.simpleMessage(
      "Suspendre le noyau lorsque l’appareil est inactif pour économiser la batterie",
    ),
    "suspended": MessageLookupByLibrary.simpleMessage("Suspendu…"),
    "swipeToSwitchPage": MessageLookupByLibrary.simpleMessage(
      "Balayer pour changer de page",
    ),
    "switchProfile": MessageLookupByLibrary.simpleMessage("Changer de profil"),
    "sync": MessageLookupByLibrary.simpleMessage("Synchroniser"),
    "system": MessageLookupByLibrary.simpleMessage("Système"),
    "systemApp": MessageLookupByLibrary.simpleMessage("Apps système"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("Proxy système"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Définir le proxy HTTP du système",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("Onglet"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage(
      "Animation des onglets",
    ),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage(
      "Uniquement applicable à l’affichage mobile",
    ),
    "tailscaleActive": MessageLookupByLibrary.simpleMessage("Actif"),
    "tailscaleCurrentEndpoint": MessageLookupByLibrary.simpleMessage(
      "Point de terminaison actuel",
    ),
    "tailscaleDnsName": MessageLookupByLibrary.simpleMessage("Nom DNS"),
    "tailscaleEndpoints": MessageLookupByLibrary.simpleMessage(
      "Points de terminaison",
    ),
    "tailscaleExitNode": MessageLookupByLibrary.simpleMessage("Nœud de sortie"),
    "tailscaleExitNodeAvailable": MessageLookupByLibrary.simpleMessage(
      "Nœud de sortie disponible",
    ),
    "tailscaleHealth": MessageLookupByLibrary.simpleMessage("État de santé"),
    "tailscaleHealthWarnings": MessageLookupByLibrary.simpleMessage(
      "Avertissements d’état",
    ),
    "tailscaleKeyExpired": MessageLookupByLibrary.simpleMessage("Clé expirée"),
    "tailscaleKeyExpiry": MessageLookupByLibrary.simpleMessage(
      "Expiration de la clé",
    ),
    "tailscaleLastHandshake": MessageLookupByLibrary.simpleMessage(
      "Dernière négociation",
    ),
    "tailscaleLastSeen": MessageLookupByLibrary.simpleMessage(
      "Dernière présence",
    ),
    "tailscaleNeedsMachineAuth": MessageLookupByLibrary.simpleMessage(
      "Approbation de l’appareil requise",
    ),
    "tailscaleNodeKey": MessageLookupByLibrary.simpleMessage("Clé du nœud"),
    "tailscaleRelay": MessageLookupByLibrary.simpleMessage("Relais DERP"),
    "tailscaleSubnets": MessageLookupByLibrary.simpleMessage("Sous-réseaux"),
    "tailscaleTags": MessageLookupByLibrary.simpleMessage("Étiquettes"),
    "tapIconToRetry": MessageLookupByLibrary.simpleMessage(
      "Appuyez sur l’icône pour réessayer",
    ),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage(
      "Appuyez pour autoriser",
    ),
    "target": MessageLookupByLibrary.simpleMessage("Cible"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP simultané"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "Autoriser les connexions TCP simultanées",
    ),
    "testInterval": MessageLookupByLibrary.simpleMessage("Intervalle de test"),
    "testUrl": MessageLookupByLibrary.simpleMessage("URL de test"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage(
      "Tester à l’utilisation",
    ),
    "textReplacement": MessageLookupByLibrary.simpleMessage(
      "Substitution de texte :",
    ),
    "textScale": MessageLookupByLibrary.simpleMessage("Taille du texte"),
    "textScalePreview": MessageLookupByLibrary.simpleMessage(
      "Le texte de l’app ressemblera à ceci",
    ),
    "theme": MessageLookupByLibrary.simpleMessage("Thème"),
    "themeColor": MessageLookupByLibrary.simpleMessage("Couleur du thème"),
    "themeMode": MessageLookupByLibrary.simpleMessage("Mode du thème"),
    "tight": MessageLookupByLibrary.simpleMessage("Serrée"),
    "time": MessageLookupByLibrary.simpleMessage("Heure"),
    "timeout": MessageLookupByLibrary.simpleMessage("Expiré"),
    "tintedStyle": MessageLookupByLibrary.simpleMessage("Teinté"),
    "tip": MessageLookupByLibrary.simpleMessage("Astuce"),
    "toggle": MessageLookupByLibrary.simpleMessage("Basculer"),
    "toggleLabel": MessageLookupByLibrary.simpleMessage(
      "Afficher ou masquer les libellés",
    ),
    "tolerance": MessageLookupByLibrary.simpleMessage("Tolérance"),
    "tools": MessageLookupByLibrary.simpleMessage("Outils"),
    "torch": MessageLookupByLibrary.simpleMessage("Lampe torche"),
    "total": MessageLookupByLibrary.simpleMessage("Total"),
    "totalDownload": MessageLookupByLibrary.simpleMessage("Reçu"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("Trafic total"),
    "totalUpload": MessageLookupByLibrary.simpleMessage("Envoyé"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Port TProxy"),
    "traffic": MessageLookupByLibrary.simpleMessage("Trafic"),
    "trafficBoth": MessageLookupByLibrary.simpleMessage("Les deux"),
    "trafficPeak": m81,
    "trafficTotal": m82,
    "trafficUsage": MessageLookupByLibrary.simpleMessage("Trafic utilisé"),
    "transport": MessageLookupByLibrary.simpleMessage("Transport"),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunAuthorizationFailed": MessageLookupByLibrary.simpleMessage(
      "TUN n’a pas pu être autorisé et a donc été désactivé.",
    ),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "TUN ne fonctionne qu’en mode administrateur.",
    ),
    "tunDnsMode": MessageLookupByLibrary.simpleMessage("Mode DNS du système"),
    "tunDnsModeDisabled": MessageLookupByLibrary.simpleMessage("Désactivé"),
    "tunDnsModeHijack": MessageLookupByLibrary.simpleMessage("Interception"),
    "tunDnsModeNative": MessageLookupByLibrary.simpleMessage("Natif"),
    "tunOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Les entrées ajoutées ici remplacent les réglages TUN de tous les profils ; tout ce qui n’est pas ajouté garde le réglage du profil. Les entrées qu’un profil personnalisé ajoute lui-même priment.",
    ),
    "turnOff": MessageLookupByLibrary.simpleMessage("Désactiver"),
    "turnOn": MessageLookupByLibrary.simpleMessage("Activer"),
    "tvMode": MessageLookupByLibrary.simpleMessage("Mode TV"),
    "tvModeDesc": MessageLookupByLibrary.simpleMessage(
      "Utiliser une interface adaptée à la télécommande sur cet appareil",
    ),
    "udpRelayMode": MessageLookupByLibrary.simpleMessage("Mode de relais UDP"),
    "udpTimeout": MessageLookupByLibrary.simpleMessage("Délai UDP"),
    "udpTimeoutDesc": MessageLookupByLibrary.simpleMessage(
      "Le délai UDP est en secondes et ne fonctionne qu’avec les piles gvisor, system et mixed.",
    ),
    "uiUpdateIdleInterval": MessageLookupByLibrary.simpleMessage(
      "Intervalle d’actualisation en inactivité",
    ),
    "uiUpdateIdleWhenUnfocused": MessageLookupByLibrary.simpleMessage(
      "Ralentir en cas de perte du focus",
    ),
    "uiUpdateIdleWhenUnfocusedDesc": MessageLookupByLibrary.simpleMessage(
      "Utiliser l’intervalle d’inactivité lorsque la fenêtre perd le focus",
    ),
    "uiUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Intervalle d’actualisation des informations de l’interface",
    ),
    "uiUpdateIntervalDesc": m83,
    "uiUpdateIntervalIdleDisabledDesc": m84,
    "ultra": MessageLookupByLibrary.simpleMessage("Ultra"),
    "unauthorized": MessageLookupByLibrary.simpleMessage("Non autorisé"),
    "undo": MessageLookupByLibrary.simpleMessage("Annuler"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("Délai unifié"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "Éliminer les délais supplémentaires tels que les négociations",
    ),
    "uninitialized": MessageLookupByLibrary.simpleMessage("Non initialisé"),
    "unknown": MessageLookupByLibrary.simpleMessage("Inconnu"),
    "unknownBackupVariable": MessageLookupByLibrary.simpleMessage(
      "Variable inconnue. Choisissez l’une des variables ci-dessous.",
    ),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage(
      "Erreur réseau inconnue",
    ),
    "unmaximize": MessageLookupByLibrary.simpleMessage("Restaurer"),
    "unnamed": MessageLookupByLibrary.simpleMessage("Sans nom"),
    "unpinWindow": MessageLookupByLibrary.simpleMessage(
      "Désépingler la fenêtre",
    ),
    "update": MessageLookupByLibrary.simpleMessage("Mettre à jour"),
    "updateChecksumMismatch": MessageLookupByLibrary.simpleMessage(
      "Le fichier téléchargé ne correspond pas à la somme de contrôle publiée et a été supprimé.",
    ),
    "updateDownloading": MessageLookupByLibrary.simpleMessage(
      "Téléchargement de la mise à jour",
    ),
    "updateInstallFailed": MessageLookupByLibrary.simpleMessage(
      "Impossible de démarrer le programme d’installation.",
    ),
    "updateInstallPermission": MessageLookupByLibrary.simpleMessage(
      "FlClash n’a pas été autorisé à installer des applications. La mise à jour n’a pas été installée.",
    ),
    "updateNotWritable": MessageLookupByLibrary.simpleMessage(
      "FlClash ne peut pas écrire dans son dossier d’installation. Téléchargez la mise à jour manuellement.",
    ),
    "updateNow": MessageLookupByLibrary.simpleMessage(
      "Mettre à jour maintenant",
    ),
    "upload": MessageLookupByLibrary.simpleMessage("Envoi"),
    "uploadBandwidth": MessageLookupByLibrary.simpleMessage(
      "Bande passante d’envoi",
    ),
    "uploadSpeed": MessageLookupByLibrary.simpleMessage("Vitesse d’envoi"),
    "uploadTraffic": MessageLookupByLibrary.simpleMessage("Trafic envoyé"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage(
      "Obtenir un profil à partir d’une URL",
    ),
    "urlTip": m85,
    "useHosts": MessageLookupByLibrary.simpleMessage("Utiliser hosts"),
    "useHostsDesc": MessageLookupByLibrary.simpleMessage(
      "Vérifier les entrées hosts de la configuration avant d’interroger les serveurs DNS en amont",
    ),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage(
      "Utiliser les hosts du système",
    ),
    "useSystemHostsDesc": MessageLookupByLibrary.simpleMessage(
      "Vérifier le fichier hosts du système lors de la résolution des domaines",
    ),
    "usedShort": MessageLookupByLibrary.simpleMessage("utilisé"),
    "usedTraffic": MessageLookupByLibrary.simpleMessage("Trafic utilisé"),
    "userAgent": MessageLookupByLibrary.simpleMessage("User-Agent"),
    "username": MessageLookupByLibrary.simpleMessage("Nom d’utilisateur"),
    "value": MessageLookupByLibrary.simpleMessage("Valeur"),
    "version": MessageLookupByLibrary.simpleMessage("Version"),
    "view": MessageLookupByLibrary.simpleMessage("Afficher"),
    "virtualIpv4": MessageLookupByLibrary.simpleMessage("IPv4 virtuelle"),
    "vividStyle": MessageLookupByLibrary.simpleMessage("Vif"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "Modification de la configuration liée au VPN détectée",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "Le VPN fait passer automatiquement tout le trafic du système par VpnService.",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage(
      "Configuration WebDAV",
    ),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("Mode liste blanche"),
    "writeToSystem": MessageLookupByLibrary.simpleMessage(
      "Écrire dans le système",
    ),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage(
      "Écrire dans le système règle aussi l’horloge système ; Android l’ignore.",
    ),
    "yearsAgo": m86,
    "yearsAgoShort": m87,
    "yes": MessageLookupByLibrary.simpleMessage("Oui"),
    "zhCN": MessageLookupByLibrary.simpleMessage("Chinois simplifié"),
    "zhTW": MessageLookupByLibrary.simpleMessage("Chinois traditionnel"),
    "zolnitAccountHelpHint": MessageLookupByLibrary.simpleMessage(
      "Obtenir de l’aide",
    ),
    "zolnitAccountOrdersHint": MessageLookupByLibrary.simpleMessage(
      "Voir les commandes d\'activation et de renouvellement",
    ),
    "zolnitAccountPassword": MessageLookupByLibrary.simpleMessage(
      "Mot de passe de connexion",
    ),
    "zolnitAccountPreferencesHint": MessageLookupByLibrary.simpleMessage(
      "Paramètres de connexion",
    ),
    "zolnitAccountSubtitle": MessageLookupByLibrary.simpleMessage(
      "Consultez les informations du compte et les commandes.",
    ),
    "zolnitAccountTitle": MessageLookupByLibrary.simpleMessage("Mon compte"),
    "zolnitActivating": MessageLookupByLibrary.simpleMessage(
      "Activation en cours",
    ),
    "zolnitAdvanced": MessageLookupByLibrary.simpleMessage("Réglages avancés"),
    "zolnitAiService": MessageLookupByLibrary.simpleMessage("Services IA"),
    "zolnitAllNodes": MessageLookupByLibrary.simpleMessage("Tous les serveurs"),
    "zolnitAllRegions": MessageLookupByLibrary.simpleMessage(
      "Toutes les régions",
    ),
    "zolnitAmountDue": MessageLookupByLibrary.simpleMessage("Montant à payer"),
    "zolnitAppleAutoRenewal": MessageLookupByLibrary.simpleMessage(
      "Abonnement App Store à renouvellement automatique",
    ),
    "zolnitAppleConsent": MessageLookupByLibrary.simpleMessage(
      "L’abonnement se renouvelle au prix App Store affiché jusqu’à son annulation dans les abonnements de l’App Store.",
    ),
    "zolnitAppleManage": MessageLookupByLibrary.simpleMessage(
      "Gérer les abonnements App Store",
    ),
    "zolnitApplePending": MessageLookupByLibrary.simpleMessage(
      "En attente de validation par l’App Store ou le serveur.",
    ),
    "zolnitAppleRestore": MessageLookupByLibrary.simpleMessage(
      "Restaurer les achats App Store",
    ),
    "zolnitAppleSubscribe": MessageLookupByLibrary.simpleMessage(
      "S’abonner avec l’App Store",
    ),
    "zolnitAppleUnavailable": MessageLookupByLibrary.simpleMessage(
      "Ce forfait n’est pas disponible à l’achat sur l’App Store.",
    ),
    "zolnitAuthorizeMonthly": MessageLookupByLibrary.simpleMessage(
      "Autoriser le paiement mensuel",
    ),
    "zolnitBalance": MessageLookupByLibrary.simpleMessage("Solde du compte"),
    "zolnitBilledMonthly": MessageLookupByLibrary.simpleMessage(
      "Facturation mensuelle, pour bien commencer",
    ),
    "zolnitBilledOnce": m88,
    "zolnitBillingUnavailable": MessageLookupByLibrary.simpleMessage(
      "Les informations de renouvellement sont temporairement indisponibles.",
    ),
    "zolnitBundleAutomaticPending": MessageLookupByLibrary.simpleMessage(
      "Le routage automatique est en cours de validation. Les choix manuel et direct sont disponibles.",
    ),
    "zolnitBundleExpired": MessageLookupByLibrary.simpleMessage(
      "Les informations de sélection automatique ont expiré. Actualisez la configuration ; les choix manuel et direct restent disponibles.",
    ),
    "zolnitBundleFetchHint": MessageLookupByLibrary.simpleMessage(
      "Obtenir la configuration de connexion",
    ),
    "zolnitBundleForbidden": MessageLookupByLibrary.simpleMessage(
      "La configuration n’est pas disponible pour ce compte. Vérifiez le forfait et le trafic restant.",
    ),
    "zolnitBundleInvalid": MessageLookupByLibrary.simpleMessage(
      "La validation de la configuration a échoué. La sélection automatique est suspendue.",
    ),
    "zolnitBundleNoCandidates": MessageLookupByLibrary.simpleMessage(
      "Aucune sortie n’a une admissibilité confirmée. La sélection automatique est indisponible ; choisissez manuellement ou une connexion directe.",
    ),
    "zolnitBundleRefreshFailed": MessageLookupByLibrary.simpleMessage(
      "Impossible d’actualiser la configuration. Les choix manuel et direct restent disponibles.",
    ),
    "zolnitBundleUnavailable": MessageLookupByLibrary.simpleMessage(
      "La configuration de connexion est temporairement indisponible.",
    ),
    "zolnitBuy": MessageLookupByLibrary.simpleMessage("Créer une commande"),
    "zolnitCancelOrder": MessageLookupByLibrary.simpleMessage(
      "Annuler la commande",
    ),
    "zolnitCancelOrderTip": MessageLookupByLibrary.simpleMessage(
      "Annuler cette commande impayée ?",
    ),
    "zolnitCancelRenewal": MessageLookupByLibrary.simpleMessage(
      "Annuler le renouvellement automatique",
    ),
    "zolnitCancelRenewalTip": MessageLookupByLibrary.simpleMessage(
      "Les prochains prélèvements automatiques seront arrêtés. Une première commande impayée sera aussi annulée. Les droits déjà payés suivent le résultat du serveur.",
    ),
    "zolnitCanceled": MessageLookupByLibrary.simpleMessage("Annulée"),
    "zolnitChangePassword": MessageLookupByLibrary.simpleMessage(
      "Modifier le mot de passe",
    ),
    "zolnitCheckoutExists": MessageLookupByLibrary.simpleMessage(
      "Un paiement est déjà en cours. Consultez son état dans Compte sans le soumettre à nouveau.",
    ),
    "zolnitCheckoutProcessing": MessageLookupByLibrary.simpleMessage(
      "Le paiement est en préparation ou en vérification. Réessayez dans un instant.",
    ),
    "zolnitChoosePlan": MessageLookupByLibrary.simpleMessage(
      "Choisir ce forfait",
    ),
    "zolnitCompleted": MessageLookupByLibrary.simpleMessage("Terminée"),
    "zolnitConnectAction": MessageLookupByLibrary.simpleMessage("Se connecter"),
    "zolnitConnectHeadline": MessageLookupByLibrary.simpleMessage(
      "Un geste, et vous êtes connecté",
    ),
    "zolnitConnectOnLaunch": MessageLookupByLibrary.simpleMessage(
      "Connexion automatique au lancement",
    ),
    "zolnitConnectOnLaunchHint": MessageLookupByLibrary.simpleMessage(
      "Au lancement, connexion automatique au dernier serveur utilisé.",
    ),
    "zolnitConnectSub": MessageLookupByLibrary.simpleMessage(
      "Connectez-vous aux serveurs inclus dans votre forfait.",
    ),
    "zolnitConnectionPageUnavailable": MessageLookupByLibrary.simpleMessage(
      "La page de connexion est indisponible. Réessayez.",
    ),
    "zolnitCopyCode": MessageLookupByLibrary.simpleMessage("Copier le code"),
    "zolnitCopyLink": MessageLookupByLibrary.simpleMessage("Copier le lien"),
    "zolnitCredentialsInvalid": MessageLookupByLibrary.simpleMessage(
      "Saisissez une adresse e-mail valide et un mot de passe d’au moins huit caractères.",
    ),
    "zolnitCredited": MessageLookupByLibrary.simpleMessage("Compensée"),
    "zolnitCurrentBadge": MessageLookupByLibrary.simpleMessage(
      "Forfait actuel",
    ),
    "zolnitCurrentPlanHint": m89,
    "zolnitCurrentPlanLabel": MessageLookupByLibrary.simpleMessage(
      "Forfait actuel",
    ),
    "zolnitCurrentPlanLine": m90,
    "zolnitCurrentSelection": MessageLookupByLibrary.simpleMessage(
      "Sélectionné",
    ),
    "zolnitCycleHalfYear": MessageLookupByLibrary.simpleMessage("6 mois"),
    "zolnitCycleQuarter": MessageLookupByLibrary.simpleMessage("1 trimestre"),
    "zolnitCycleThreeYears": MessageLookupByLibrary.simpleMessage("3 ans"),
    "zolnitCycleTwoYears": MessageLookupByLibrary.simpleMessage("2 ans"),
    "zolnitCycleYear": MessageLookupByLibrary.simpleMessage("1 an"),
    "zolnitDaysLeftLabel": m91,
    "zolnitDaysUnit": MessageLookupByLibrary.simpleMessage("jours"),
    "zolnitDevicesHint": MessageLookupByLibrary.simpleMessage(
      "Ce sont les sessions de connexion du compte, distinctes du nombre d\'IP en ligne d\'un nœud.",
    ),
    "zolnitDevicesTitle": MessageLookupByLibrary.simpleMessage(
      "Sessions de connexion",
    ),
    "zolnitDevicesUnavailable": MessageLookupByLibrary.simpleMessage(
      "Impossible de charger les sessions de connexion pour le moment. Veuillez réessayer.",
    ),
    "zolnitDisconnectAction": MessageLookupByLibrary.simpleMessage(
      "Déconnecter",
    ),
    "zolnitDisconnecting": MessageLookupByLibrary.simpleMessage("Déconnexion…"),
    "zolnitEmail": MessageLookupByLibrary.simpleMessage("Adresse e-mail"),
    "zolnitEveryScreen": MessageLookupByLibrary.simpleMessage(
      "Une expérience familière sur chaque écran",
    ),
    "zolnitExistingRenewal": MessageLookupByLibrary.simpleMessage(
      "Annulez le renouvellement automatique du forfait actuel dans Compte avant d\'activer le paiement mensuel d\'un autre forfait.",
    ),
    "zolnitExpiresOn": m92,
    "zolnitFailure": MessageLookupByLibrary.simpleMessage(
      "Impossible de terminer la demande. Vérifiez vos informations ou votre connexion, puis réessayez.",
    ),
    "zolnitFeatureDevices": m93,
    "zolnitFeatureSpeed": m94,
    "zolnitFeatureTraffic": m95,
    "zolnitFirstCharge": MessageLookupByLibrary.simpleMessage(
      "Premier paiement",
    ),
    "zolnitFollowingCharge": MessageLookupByLibrary.simpleMessage(
      "Paiements suivants",
    ),
    "zolnitForgotPassword": MessageLookupByLibrary.simpleMessage(
      "Mot de passe oublié ?",
    ),
    "zolnitGift": MessageLookupByLibrary.simpleMessage("Accès offert"),
    "zolnitGiftReplacement": MessageLookupByLibrary.simpleMessage(
      "La période payante commence après confirmation du premier paiement et remplace le temps offert restant.",
    ),
    "zolnitGlobalRoutes": MessageLookupByLibrary.simpleMessage(
      "Des routes mondiales sélectionnées",
    ),
    "zolnitGreeting": m96,
    "zolnitGreetingSub": MessageLookupByLibrary.simpleMessage(
      "Consultez votre forfait et les serveurs disponibles.",
    ),
    "zolnitHalfYearly": MessageLookupByLibrary.simpleMessage(
      "Tous les six mois",
    ),
    "zolnitHelpSupport": MessageLookupByLibrary.simpleMessage(
      "Aide et assistance",
    ),
    "zolnitInviteCode": MessageLookupByLibrary.simpleMessage(
      "Code d\'invitation",
    ),
    "zolnitInviteCodeCopied": MessageLookupByLibrary.simpleMessage(
      "Code copié",
    ),
    "zolnitInviteCommissionAvailable": MessageLookupByLibrary.simpleMessage(
      "Commission disponible",
    ),
    "zolnitInviteCommissionConfirmed": MessageLookupByLibrary.simpleMessage(
      "Commission confirmée",
    ),
    "zolnitInviteCommissionPending": MessageLookupByLibrary.simpleMessage(
      "Commission en attente",
    ),
    "zolnitInviteCommissionRate": MessageLookupByLibrary.simpleMessage(
      "Taux de commission",
    ),
    "zolnitInviteCopied": MessageLookupByLibrary.simpleMessage("Lien copié"),
    "zolnitInviteCreateCode": MessageLookupByLibrary.simpleMessage(
      "Créer un code d\'invitation",
    ),
    "zolnitInviteCreateFailed": MessageLookupByLibrary.simpleMessage(
      "Impossible de créer le code. Réessayez.",
    ),
    "zolnitInviteHeadline": MessageLookupByLibrary.simpleMessage(
      "Partagez la connexion, gagnez un bonus.",
    ),
    "zolnitInviteLink": MessageLookupByLibrary.simpleMessage(
      "Lien d\'invitation",
    ),
    "zolnitInviteLoadFailed": MessageLookupByLibrary.simpleMessage(
      "Impossible de charger les données d\'invitation. Réessayez.",
    ),
    "zolnitInviteNoData": MessageLookupByLibrary.simpleMessage(
      "Invitez vos amis pour commencer.",
    ),
    "zolnitInvitePeople": MessageLookupByLibrary.simpleMessage("pers."),
    "zolnitInviteRegistered": MessageLookupByLibrary.simpleMessage("Inscrits"),
    "zolnitInviteRules": MessageLookupByLibrary.simpleMessage(
      "Règles de parrainage",
    ),
    "zolnitInviteShare": MessageLookupByLibrary.simpleMessage(
      "Votre invitation",
    ),
    "zolnitInviteShareHint": MessageLookupByLibrary.simpleMessage(
      "Vos amis s\'inscrivent via le lien. Vous recevez une récompense après leur abonnement.",
    ),
    "zolnitInviteSubtitle": MessageLookupByLibrary.simpleMessage(
      "Invitez des amis à s\'inscrire et à s\'abonner via votre lien.",
    ),
    "zolnitLatency": MessageLookupByLibrary.simpleMessage("Latence"),
    "zolnitLatestNotices": MessageLookupByLibrary.simpleMessage(
      "Dernières annonces",
    ),
    "zolnitLoginDescription": MessageLookupByLibrary.simpleMessage(
      "Oubliez les réglages compliqués. Votre monde est à une connexion.",
    ),
    "zolnitLoginEyebrow": MessageLookupByLibrary.simpleMessage(
      "Un peu plus près de votre monde",
    ),
    "zolnitLoginSubtitle": MessageLookupByLibrary.simpleMessage(
      "Connectez-vous pour gérer votre forfait et vos connexions.",
    ),
    "zolnitLoginWebsite": MessageLookupByLibrary.simpleMessage(
      "S’inscrire ou récupérer son mot de passe",
    ),
    "zolnitManageRenewals": MessageLookupByLibrary.simpleMessage(
      "Gérer le renouvellement automatique",
    ),
    "zolnitMediaService": MessageLookupByLibrary.simpleMessage("Streaming"),
    "zolnitModeGlobal": MessageLookupByLibrary.simpleMessage("Global"),
    "zolnitModeSmart": MessageLookupByLibrary.simpleMessage(
      "Routage intelligent",
    ),
    "zolnitMonthly": MessageLookupByLibrary.simpleMessage("Mensuel"),
    "zolnitMonthlyEnrollment": MessageLookupByLibrary.simpleMessage(
      "Facturation mensuelle automatique",
    ),
    "zolnitMySpace": MessageLookupByLibrary.simpleMessage("Mon espace"),
    "zolnitNewPassword": MessageLookupByLibrary.simpleMessage(
      "Nouveau mot de passe",
    ),
    "zolnitNextRenewal": MessageLookupByLibrary.simpleMessage(
      "Prochain renouvellement",
    ),
    "zolnitNoCurrentPlanHint": MessageLookupByLibrary.simpleMessage(
      "Vous n’avez aucun forfait actif. Choisissez-en un ci-dessous pour commencer.",
    ),
    "zolnitNoDevices": MessageLookupByLibrary.simpleMessage(
      "Aucune session de connexion à afficher.",
    ),
    "zolnitNoMatchingNodes": MessageLookupByLibrary.simpleMessage(
      "Aucun serveur correspondant.",
    ),
    "zolnitNoMethods": MessageLookupByLibrary.simpleMessage(
      "Aucun moyen de paiement disponible",
    ),
    "zolnitNoNodes": MessageLookupByLibrary.simpleMessage(
      "Aucun nœud n’est disponible pour cet abonnement.",
    ),
    "zolnitNoNotices": MessageLookupByLibrary.simpleMessage(
      "Aucune annonce pour le moment",
    ),
    "zolnitNoOrders": MessageLookupByLibrary.simpleMessage(
      "Aucune commande pour le moment",
    ),
    "zolnitNoPlan": MessageLookupByLibrary.simpleMessage("Aucun forfait actif"),
    "zolnitNoRenewals": MessageLookupByLibrary.simpleMessage(
      "Aucun contrat de renouvellement automatique",
    ),
    "zolnitNodeMeasurementHint": MessageLookupByLibrary.simpleMessage(
      "La latence reflète le dernier test réel ; affiche — si aucun test n\'a été fait.",
    ),
    "zolnitNodeMultiplier": m97,
    "zolnitNodeName": MessageLookupByLibrary.simpleMessage("Serveur"),
    "zolnitNodeSyncHint": MessageLookupByLibrary.simpleMessage(
      "Les serveurs disponibles se mettent automatiquement à jour avec votre forfait.",
    ),
    "zolnitNodesCount": m98,
    "zolnitNodesHeadline": MessageLookupByLibrary.simpleMessage("Serveurs"),
    "zolnitNodesSubtitle": MessageLookupByLibrary.simpleMessage(
      "Les serveurs disponibles se mettent à jour depuis votre compte.",
    ),
    "zolnitNotConnected": MessageLookupByLibrary.simpleMessage(
      "Pas encore connecté",
    ),
    "zolnitNotices": MessageLookupByLibrary.simpleMessage("Annonces"),
    "zolnitOldPassword": MessageLookupByLibrary.simpleMessage(
      "Mot de passe actuel",
    ),
    "zolnitOneTime": MessageLookupByLibrary.simpleMessage("Paiement unique"),
    "zolnitOnlineDevices": MessageLookupByLibrary.simpleMessage(
      "Appareils en ligne",
    ),
    "zolnitOrders": MessageLookupByLibrary.simpleMessage("Commandes"),
    "zolnitOutOfDevices": m99,
    "zolnitPaid": MessageLookupByLibrary.simpleMessage("Accès payé"),
    "zolnitPaidThrough": MessageLookupByLibrary.simpleMessage(
      "Accès payé jusqu’au",
    ),
    "zolnitPasswordInvalid": MessageLookupByLibrary.simpleMessage(
      "Saisissez votre mot de passe actuel et un nouveau mot de passe différent d\'au moins huit caractères.",
    ),
    "zolnitPasswordUpdated": MessageLookupByLibrary.simpleMessage(
      "Mot de passe mis à jour.",
    ),
    "zolnitPay": MessageLookupByLibrary.simpleMessage("Payer la commande"),
    "zolnitPaymentReturn": MessageLookupByLibrary.simpleMessage(
      "L’état de la commande doit encore être confirmé après votre retour du paiement.",
    ),
    "zolnitPaymentStatus": MessageLookupByLibrary.simpleMessage(
      "État du paiement",
    ),
    "zolnitPaymentUnavailable": MessageLookupByLibrary.simpleMessage(
      "Ce moyen de paiement n’est pas encore disponible.",
    ),
    "zolnitPending": MessageLookupByLibrary.simpleMessage(
      "En attente de paiement",
    ),
    "zolnitPendingOrder": MessageLookupByLibrary.simpleMessage(
      "Vous avez une commande en attente. Poursuivez le paiement ou fermez-la dans Commandes avant d’en passer une autre.",
    ),
    "zolnitPerMonth": MessageLookupByLibrary.simpleMessage("/ mois"),
    "zolnitPlanSwitch": MessageLookupByLibrary.simpleMessage(
      "Le nouveau forfait commence après confirmation du premier paiement ou du crédit de la valeur restante.",
    ),
    "zolnitPlanValidity": MessageLookupByLibrary.simpleMessage(
      "Validité du forfait",
    ),
    "zolnitPlans": MessageLookupByLibrary.simpleMessage("Forfaits"),
    "zolnitPlansHeadline": MessageLookupByLibrary.simpleMessage("Forfaits"),
    "zolnitPlansSub": MessageLookupByLibrary.simpleMessage(
      "De la navigation quotidienne au streaming fluide, choisissez la connexion qui vous convient.",
    ),
    "zolnitPreferences": MessageLookupByLibrary.simpleMessage("Préférences"),
    "zolnitPreferencesHeadline": MessageLookupByLibrary.simpleMessage(
      "Paramètres",
    ),
    "zolnitPreferencesSafeHint": MessageLookupByLibrary.simpleMessage(
      "Le mode sécurisé conserve vos préférences, mais ne se connecte pas automatiquement et ne modifie pas le réseau du système.",
    ),
    "zolnitPreferencesSubtitle": MessageLookupByLibrary.simpleMessage(
      "Gérez les paramètres de démarrage et de connexion.",
    ),
    "zolnitProfileSource": MessageLookupByLibrary.simpleMessage(
      "Les serveurs disponibles se mettent à jour automatiquement depuis votre compte.",
    ),
    "zolnitQuarterly": MessageLookupByLibrary.simpleMessage("Trimestriel"),
    "zolnitQuoteBeforeConsent": MessageLookupByLibrary.simpleMessage(
      "Vérifiez le devis avant d’autoriser le renouvellement automatique.",
    ),
    "zolnitQuoteExpired": MessageLookupByLibrary.simpleMessage(
      "Ce devis a expiré. Actualisez pour continuer.",
    ),
    "zolnitQuoteLabel": MessageLookupByLibrary.simpleMessage("Devis"),
    "zolnitQuoteUnavailable": MessageLookupByLibrary.simpleMessage(
      "Le devis est indisponible. Réessayez.",
    ),
    "zolnitRateLimited": MessageLookupByLibrary.simpleMessage(
      "Trop de tentatives. Réessayez dans un instant.",
    ),
    "zolnitRecommendedNodes": MessageLookupByLibrary.simpleMessage(
      "Serveurs recommandés",
    ),
    "zolnitRecommendedNodesSub": MessageLookupByLibrary.simpleMessage(
      "Les plus proches d’abord, pour se connecter plus vite",
    ),
    "zolnitRecommendedRoute": MessageLookupByLibrary.simpleMessage(
      "Recommandé",
    ),
    "zolnitRecurringConsent": MessageLookupByLibrary.simpleMessage(
      "J’accepte les paiements récurrents de ce forfait selon les conditions affichées du premier paiement et des renouvellements.",
    ),
    "zolnitRecurringUnavailable": MessageLookupByLibrary.simpleMessage(
      "La facturation mensuelle automatique n’est pas disponible pour ce forfait pour le moment.",
    ),
    "zolnitRefresh": MessageLookupByLibrary.simpleMessage("Actualiser"),
    "zolnitRegister": MessageLookupByLibrary.simpleMessage("Créer un compte"),
    "zolnitRegistrationWebsiteHint": MessageLookupByLibrary.simpleMessage(
      "La création du compte et la récupération du mot de passe se font sur le site ZolNit avec vérification de l’adresse e-mail et de sécurité.",
    ),
    "zolnitRenewCurrent": MessageLookupByLibrary.simpleMessage(
      "Renouveler le forfait actuel",
    ),
    "zolnitRenewPlan": MessageLookupByLibrary.simpleMessage(
      "Renouveler le forfait",
    ),
    "zolnitRenewals": MessageLookupByLibrary.simpleMessage(
      "Renouvellement automatique",
    ),
    "zolnitResetInDays": m100,
    "zolnitResetTraffic": MessageLookupByLibrary.simpleMessage(
      "Réinitialiser le trafic",
    ),
    "zolnitRestoringSession": MessageLookupByLibrary.simpleMessage(
      "Restauration de la session…",
    ),
    "zolnitResumeRenewal": MessageLookupByLibrary.simpleMessage(
      "Reprendre le renouvellement automatique",
    ),
    "zolnitResumeRenewalTip": MessageLookupByLibrary.simpleMessage(
      "Reprendre les prélèvements automatiques selon le forfait autorisé.",
    ),
    "zolnitReturnDirect": MessageLookupByLibrary.simpleMessage(
      "Accès direct à la Chine",
    ),
    "zolnitReturnEnabled": MessageLookupByLibrary.simpleMessage(
      "Activer le routage vers la Chine",
    ),
    "zolnitReturnHkLite": MessageLookupByLibrary.simpleMessage(
      "Hong Kong préféré",
    ),
    "zolnitReturnHkOptimized": MessageLookupByLibrary.simpleMessage(
      "Hong Kong optimisé",
    ),
    "zolnitReturnLocal": MessageLookupByLibrary.simpleMessage(
      "Connexion locale directe",
    ),
    "zolnitReturnRoute": MessageLookupByLibrary.simpleMessage(
      "Itinéraire vers la Chine",
    ),
    "zolnitRevokeDevice": MessageLookupByLibrary.simpleMessage(
      "Se déconnecter de cette session",
    ),
    "zolnitRevokeDeviceDone": MessageLookupByLibrary.simpleMessage(
      "Session de connexion terminée.",
    ),
    "zolnitRevokeDeviceTip": MessageLookupByLibrary.simpleMessage(
      "Terminer cette session de connexion ? Cet appareil devra se reconnecter pour gérer le compte.",
    ),
    "zolnitRouteCurrent": m101,
    "zolnitRouteUnavailable": MessageLookupByLibrary.simpleMessage(
      "Indisponible",
    ),
    "zolnitSafeMode": MessageLookupByLibrary.simpleMessage("Mode sans échec"),
    "zolnitSafeModeConnect": MessageLookupByLibrary.simpleMessage(
      "Le mode sécurisé ne modifie jamais le réseau du système.",
    ),
    "zolnitSavePercent": m102,
    "zolnitSearchNodes": MessageLookupByLibrary.simpleMessage(
      "Rechercher un serveur ou une région",
    ),
    "zolnitSelectColumn": MessageLookupByLibrary.simpleMessage("Choisir"),
    "zolnitSelectServer": MessageLookupByLibrary.simpleMessage(
      "Choisir un serveur",
    ),
    "zolnitSessionExpired": MessageLookupByLibrary.simpleMessage(
      "Votre session a expiré. Reconnectez-vous.",
    ),
    "zolnitSignIn": MessageLookupByLibrary.simpleMessage("Se connecter"),
    "zolnitSignInRejected": MessageLookupByLibrary.simpleMessage(
      "Adresse e-mail ou mot de passe incorrect. Réessayez.",
    ),
    "zolnitSignOut": MessageLookupByLibrary.simpleMessage("Se déconnecter"),
    "zolnitStartOnBoot": MessageLookupByLibrary.simpleMessage(
      "Lancer ZolNit au démarrage",
    ),
    "zolnitStartOnBootHint": MessageLookupByLibrary.simpleMessage(
      "ZolNit est prêt dès l\'allumage de l\'appareil.",
    ),
    "zolnitStatusActive": MessageLookupByLibrary.simpleMessage("Actif"),
    "zolnitStatusExpired": MessageLookupByLibrary.simpleMessage("Expiré"),
    "zolnitStatusNoPlan": MessageLookupByLibrary.simpleMessage("Aucun forfait"),
    "zolnitSubscribePlan": MessageLookupByLibrary.simpleMessage(
      "Choisir un forfait",
    ),
    "zolnitSync": MessageLookupByLibrary.simpleMessage(
      "Synchroniser les données du compte",
    ),
    "zolnitSynced": MessageLookupByLibrary.simpleMessage(
      "Données du compte synchronisées",
    ),
    "zolnitSyncing": MessageLookupByLibrary.simpleMessage(
      "Synchronisation des données du compte…",
    ),
    "zolnitTabAccount": MessageLookupByLibrary.simpleMessage("Compte"),
    "zolnitTabInvite": MessageLookupByLibrary.simpleMessage("Parrainage"),
    "zolnitTabOrders": MessageLookupByLibrary.simpleMessage("Commandes"),
    "zolnitTagline": MessageLookupByLibrary.simpleMessage(
      "La connexion, en toute simplicité.",
    ),
    "zolnitThreeYearly": MessageLookupByLibrary.simpleMessage(
      "Tous les trois ans",
    ),
    "zolnitTrafficLeft": MessageLookupByLibrary.simpleMessage("Trafic restant"),
    "zolnitTrafficUsed": MessageLookupByLibrary.simpleMessage(
      "Consommé sur la période",
    ),
    "zolnitTwoYearly": MessageLookupByLibrary.simpleMessage(
      "Tous les deux ans",
    ),
    "zolnitUnknownDevice": MessageLookupByLibrary.simpleMessage(
      "Session de connexion",
    ),
    "zolnitViewMonthlyQuote": MessageLookupByLibrary.simpleMessage(
      "Voir le devis mensuel",
    ),
    "zolnitWebsite": MessageLookupByLibrary.simpleMessage(
      "Ouvrir le site ZolNit",
    ),
    "zolnitWelcome": MessageLookupByLibrary.simpleMessage(
      "Heureux de vous revoir",
    ),
    "zolnitWorkspace": MessageLookupByLibrary.simpleMessage("VOTRE ESPACE"),
    "zolnitYearly": MessageLookupByLibrary.simpleMessage("Annuel"),
  };
}
