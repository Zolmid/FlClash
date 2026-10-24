import 'dart:convert';

Map<String, dynamic> routingFixture() =>
    jsonDecode(
          jsonEncode(<String, dynamic>{
            'mode': 'rule',
            'rules': [
              'DOMAIN-SUFFIX,openai.com,AI 服务',
              'DOMAIN-SUFFIX,netflix.com,海外影音',
              'MATCH,节点选择',
            ],
            'proxies': [
              for (final name in ['hk-exit', 'us-exit', 'jp-exit'])
                {'name': name, 'type': 'ss'},
            ],
            'proxy-groups': [
              {
                'name': '节点选择',
                'type': 'url-test',
                'proxies': ['hk-exit', 'us-exit', 'jp-exit'],
              },
              {
                'name': 'AI 服务',
                'type': 'select',
                'proxies': ['节点选择', 'DIRECT'],
              },
              {
                'name': '海外影音',
                'type': 'select',
                'proxies': ['节点选择', 'DIRECT'],
              },
            ],
            'x-zolnit-routing': {
              'version': 1,
              'authority': 'zolnit',
              'revision': 'inventory-v1',
              'services': [
                {
                  'id': 'ai',
                  'kind': 'ai',
                  'group': 'AI 服务',
                  'automatic': 'AI 自动',
                  'manual': 'AI 手动',
                  'providers': ['chatgpt', 'claude', 'gemini_api'],
                  'allowed_countries': ['HK', 'US', 'JP', 'SG', 'TW'],
                },
                {
                  'id': 'media',
                  'kind': 'media',
                  'group': '海外影音',
                  'automatic': '影音自动',
                  'manual': '影音手动',
                  'providers': ['netflix'],
                  'allowed_countries': ['HK', 'US', 'JP'],
                },
              ],
              'nodes': [
                for (final country in ['hk', 'us', 'jp'])
                  {
                    'id': country,
                    'proxy_name': '$country-exit',
                    'final_egress': {
                      'country': country.toUpperCase(),
                      'verified': true,
                      'source': 'operator_verified',
                    },
                    'failure_domain': 'machine-$country',
                    'services': ['ai', 'media'],
                    'enabled': true,
                    'revision': 'egress-v1',
                  },
              ],
            },
          }),
        )
        as Map<String, dynamic>;
