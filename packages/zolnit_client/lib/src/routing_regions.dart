const routingRegionPolicyVersion = '2026-10-24';

const routingRegionSources = <String, String>{
  'chatgpt':
      'https://help.openai.com/en/articles/7947663-chatgpt-supported-countries',
  'openai_api':
      'https://help.openai.com/en/articles/5347006-openai-api-supported-countries-and-territories',
  'claude':
      'https://support.claude.com/en/articles/8461763-where-can-i-access-claude',
  'gemini_api': 'https://ai.google.dev/gemini-api/docs/available-regions',
  'gemini_web': 'https://support.google.com/gemini/answer/13575153?hl=en',
  'netflix': 'https://help.netflix.com/en/node/14164',
};

Set<String> _countries(String codes) =>
    Set<String>.unmodifiable(codes.split(' '));

final routingCountryCodes = _countries(
  'AD AE AF AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI '
  'BJ BL BM BN BO BQ BR BS BT BV BW BY BZ CA CC CD CF CG CH CI CK CL CM CN '
  'CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK '
  'FM FO FR GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM '
  'HN HR HT HU ID IE IL IM IN IO IQ IR IS IT JE JM JO JP KE KG KH KI KM KN '
  'KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK '
  'ML MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP '
  'NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO RS RU RW '
  'SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ TC TD TF '
  'TG TH TJ TK TL TM TN TO TR TT TV TW TZ UA UG UM US UY UZ VA VC VE VG VI '
  'VN VU WF WS YE YT ZA ZM ZW',
);

// Country-only metadata cannot resolve territorial exceptions in Ukraine.
final routingProviderCountries = Map<String, Set<String>>.unmodifiable({
  'chatgpt': _countries(
    'AD AE AF AG AL AM AO AR AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM '
    'BN BO BR BS BT BW BZ CA CD CF CG CH CI CL CM CO CR CV CY CZ DE DJ DK DM '
    'DO DZ EC EE EG ER ES ET FI FJ FM FO FR GA GB GD GE GF GH GL GM GN GP GQ '
    'GR GT GW GY HN HR HT HU ID IE IL IN IQ IS IT JM JO JP KE KG KH KI KM KN '
    'KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML '
    'MM MN MQ MR MT MU MV MW MX MY MZ NA NC NE NG NI NL NO NP NR NZ OM PA PE '
    'PF PG PH PK PL PM PS PT PW PY QA RE RO RS RW SA SB SC SD SE SG SH SI SJ '
    'SK SL SM SN SO SR SS ST SV SZ TD TF TG TH TJ TL TM TN TO TR TT TV TW TZ '
    'UG US UY UZ VA VC VN VU WF WS YE YT ZA ZM ZW',
  ),
  'openai_api': _countries(
    'AD AE AF AG AL AM AO AR AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM '
    'BN BO BR BS BT BW BZ CA CD CF CG CH CI CL CM CO CR CV CY CZ DE DJ DK DM '
    'DO DZ EC EE EG ER ES ET FI FJ FM FO FR GA GB GD GE GF GH GL GM GN GP GQ '
    'GR GT GW GY HN HR HT HU ID IE IL IN IQ IS IT JM JO JP KE KG KH KI KM KN '
    'KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML '
    'MM MN MQ MR MT MU MV MW MX MY MZ NA NC NE NG NI NL NO NP NR NZ OM PA PE '
    'PF PG PH PK PL PM PS PT PW PY QA RE RO RS RW SA SB SC SD SE SG SH SI SJ '
    'SK SL SM SN SO SR SS ST SV SZ TD TF TG TH TJ TL TM TN TO TR TT TV TW TZ '
    'UG US UY UZ VA VC VN VU WF WS YE YT ZA ZM ZW',
  ),
  'claude': _countries(
    'AD AE AG AL AM AO AR AT AU AZ BA BB BD BE BF BG BH BI BJ BN BO BR BS BT '
    'BW BZ CA CG CH CI CL CM CO CR CV CY CZ DE DJ DK DM DO DZ EC EE EG ES FI '
    'FJ FM FR GA GB GD GE GH GM GN GQ GR GT GW GY HN HR HT HU ID IE IL IN IQ '
    'IS IT JM JO JP KE KG KH KI KM KN KR KW KZ LA LB LC LI LK LR LS LT LU LV '
    'MA MC MD ME MG MH MK MN MR MT MU MV MW MX MY MZ NA NE NG NL NO NP NR NZ '
    'OM PA PE PG PH PK PL PS PT PW PY QA RO RS RW SA SB SC SE SG SI SK SL SM '
    'SN SR ST SV SZ TD TG TH TJ TL TM TN TO TR TT TV TW TZ UA UG US UY UZ VA '
    'VC VN VU WS ZA ZM ZW',
  ),
  'gemini_api': _countries(
    'AD AE AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ '
    'BL BM BN BO BQ BR BS BT BW BZ CA CC CD CF CG CH CI CK CL CM CO CR CV CW '
    'CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR GA GB '
    'GD GE GF GG GH GI GL GM GN GQ GR GS GT GU GW GY HM HN HR HT HU ID IE IL '
    'IM IN IO IQ IS IT JE JM JO JP KE KG KH KI KM KN KR KW KY KZ LA LB LC LI '
    'LK LR LS LT LU LV LY MA MC MD ME MG MH MK ML MN MP MR MS MT MU MV MW MX '
    'MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PG PH PK PL PM PN PR '
    'PS PT PW PY QA RE RO RS RW SA SB SC SD SE SG SH SI SK SL SM SN SO SR SS '
    'ST SV SZ TC TD TG TH TJ TK TL TM TN TO TR TT TV TW TZ UA UG UM US UY UZ '
    'VA VC VE VG VI VN VU WF WS YE ZA ZM ZW',
  ),
  'gemini_web': _countries(
    'AD AE AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ '
    'BL BM BN BO BQ BR BS BT BW BZ CA CC CD CF CG CH CI CK CL CM CO CR CV CW '
    'CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR GA GB '
    'GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID '
    'IE IL IM IN IO IQ IS IT JE JM JO JP KE KG KH KI KM KN KR KW KY KZ LA LB '
    'LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MO MP MQ MR '
    'MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF '
    'PG PH PK PL PM PN PR PS PT PW PY QA RE RO RS RW SA SB SC SD SE SG SH SI '
    'SJ SK SL SM SN SO SR SS ST SV SX SZ TC TD TF TG TH TJ TK TL TM TN TO TR '
    'TT TV TW TZ UA UG UM US UY UZ VA VC VE VG VI VN VU WF WS YE YT ZA ZM ZW',
  ),
  'netflix': Set<String>.unmodifiable(
    routingCountryCodes.difference(const {'CN', 'KP', 'RU', 'SY', 'UA'}),
  ),
  'operator': routingCountryCodes,
});

const routingAiProviders = {
  'chatgpt',
  'openai_api',
  'claude',
  'gemini_api',
  'gemini_web',
};

Set<String> supportedRoutingCountries(
  Iterable<String> providers,
  Set<String> declared, {
  required bool isAi,
}) {
  var result = declared.intersection(routingCountryCodes);
  if (providers.isEmpty) return const {};
  for (final provider in providers) {
    final countries = routingProviderCountries[provider];
    if (countries == null || (isAi && !routingAiProviders.contains(provider))) {
      return const {};
    }
    result = result.intersection(countries);
  }
  if (isAi) result.remove('HK');
  return Set<String>.unmodifiable(result);
}
