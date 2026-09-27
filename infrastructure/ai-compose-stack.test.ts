import { test } from 'node:test';
import { deepStrictEqual, ok } from 'node:assert';
import { App } from 'aws-cdk-lib';
import { Match, Template } from 'aws-cdk-lib/assertions';
import { AiComposeStack } from './ai-compose-stack';

function template() {
  return Template.fromStack(new AiComposeStack(new App(), 'AiTest', {
    env: { account: '543123648742', region: 'ap-southeast-2' },
  }));
}

test('AI route uses existing JWT and exact invoke path', () => {
  const stack = template();
  stack.resourceCountIs('AWS::ApiGatewayV2::Api', 0);
  stack.resourceCountIs('AWS::ApiGatewayV2::Stage', 0);
  stack.resourceCountIs('AWS::ApiGatewayV2::Route', 1);
  stack.hasResourceProperties('AWS::ApiGatewayV2::Route', {
    ApiId: { Ref: 'HttpApiId' }, RouteKey: 'POST /ai/compose', AuthorizationType: 'JWT',
    AuthorizerId: { Ref: 'JwtAuthorizerId' }, AuthorizationScopes: ['reports/write'],
  });
  stack.hasResourceProperties('AWS::ApiGatewayV2::Integration', { TimeoutInMillis: 29000, PayloadFormatVersion: '2.0' });
  ok(JSON.stringify(stack.findResources('AWS::Lambda::Permission')).includes('/*/POST/ai/compose'));
  stack.resourceCountIs('AWS::Lambda::Url', 0);
});

test('isolated Python runtime is bounded and disabled', () => {
  const stack = template();
  stack.hasParameter('AiEnabled', { Default: 'false', AllowedValues: ['false', 'true'] });
  stack.hasResourceProperties('AWS::Lambda::Function', {
    Runtime: 'python3.12', Architectures: ['arm64'], Timeout: 25, ReservedConcurrentExecutions: 2,
    Handler: 'prb_ai.handler.lambda_handler',
    Environment: { Variables: Match.objectLike({ AI_ENABLED: { Ref: 'AiEnabled' } }) },
  });
  stack.hasResource('AWS::DynamoDB::Table', {
    DeletionPolicy: 'Retain', UpdateReplacePolicy: 'Retain',
    Properties: Match.objectLike({ BillingMode: 'PAY_PER_REQUEST',
      KeySchema: [{ AttributeName: 'pk', KeyType: 'HASH' }],
      TimeToLiveSpecification: { AttributeName: 'expiresAt', Enabled: true } }),
  });
  stack.allResourcesProperties('AWS::Logs::LogGroup', { RetentionInDays: 14 });
});

test('role only accesses its secret, ledger and logs', () => {
  const roles = template().findResources('AWS::IAM::Role');
  const statements = Object.values(roles)[0].Properties.Policies[0].PolicyDocument.Statement;
  deepStrictEqual(statements.map((s: { Action: unknown }) => s.Action), [
    'secretsmanager:GetSecretValue', ['dynamodb:GetItem', 'dynamodb:PutItem'],
    ['logs:CreateLogStream', 'logs:PutLogEvents'],
  ]);
  deepStrictEqual(statements[0].Resource,
    'arn:aws:secretsmanager:ap-southeast-2:543123648742:secret:prb-dev/gemini-api-key-NWLQoy');
  for (const statement of statements) ok(statement.Resource !== '*');
});

test('budget warning watches reservations without report content', () => {
  const stack = template();
  stack.hasResourceProperties('AWS::Logs::MetricFilter', {
    FilterPattern: '{ $.event = "ai_budget" }',
    MetricTransformations: [Match.objectLike({ MetricNamespace: 'ProjectReportBuilder/AI',
      MetricName: 'BudgetPercent', MetricValue: '$.budgetPercent' })],
  });
  stack.hasResourceProperties('AWS::CloudWatch::Alarm', {
    Threshold: 80, EvaluationPeriods: 1, TreatMissingData: 'notBreaching', Statistic: 'Maximum',
  });
});
