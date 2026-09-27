"""Extract a recovery import template from CDK output without making AWS calls."""
import json
from pathlib import Path

root = Path(__file__).resolve().parent
output = root / 'cdk.out'
template = json.loads((output / 'prb-dev-ai-compose.template.json').read_text())
identifiers = {
    'AWS::DynamoDB::Table': ('TableName', 'prb-dev-ai-usage'),
    'AWS::Logs::LogGroup': ('LogGroupName', '/aws/lambda/prb-dev-ai-compose'),
}
resources = {}
imports = []
for logical_id, resource in template['Resources'].items():
    if resource['Type'] not in identifiers:
        continue
    field, name = identifiers[resource['Type']]
    if resource['Properties'].get(field) != name or resource.get('DeletionPolicy') != 'Retain':
        raise SystemExit('Retained resource definition changed; review recovery before continuing.')
    resources[logical_id] = resource
    imports.append({'ResourceType': resource['Type'], 'LogicalResourceId': logical_id,
                    'ResourceIdentifier': {field: name}})
if len(resources) != 2:
    raise SystemExit('Expected exactly the retained usage table and log group.')

(output / 'ai-retained.template.json').write_text(json.dumps({
    'AWSTemplateFormatVersion': '2010-09-09', 'Resources': resources,
}, indent=2) + '\n')
(output / 'ai-retained.imports.json').write_text(json.dumps(imports, indent=2) + '\n')
print('Prepared import template and resource identifiers in cdk.out; no AWS calls made.')
