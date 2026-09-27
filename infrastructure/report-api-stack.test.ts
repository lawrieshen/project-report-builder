import { test } from 'node:test';
import { App } from 'aws-cdk-lib';
import { Match, Template } from 'aws-cdk-lib/assertions';
import { ReportApiStack } from './report-api-stack';

test('all report routes require JWT and operation scope', () => {
  const template = Template.fromStack(new ReportApiStack(new App(), 'ApiTest'));
  template.resourceCountIs('AWS::ApiGatewayV2::Route', 3);
  for (const route of ['GET /reports', 'GET /reports/{reportID}', 'PUT /reports/{reportID}']) {
    template.hasResourceProperties('AWS::ApiGatewayV2::Route', {
      RouteKey: route, AuthorizationType: 'JWT', AuthorizerId: Match.anyValue(),
      AuthorizationScopes: [route.startsWith('PUT') ? 'reports/write' : 'reports/read'],
    });
  }
  template.resourceCountIs('AWS::Lambda::Url', 0);
  template.hasResourceProperties('AWS::Lambda::Permission', {
    Principal: 'apigateway.amazonaws.com', SourceAccount: Match.anyValue(), SourceArn: Match.anyValue(),
  });
});

test('runtime logs expire and role has only report and log actions', () => {
  const template = Template.fromStack(new ReportApiStack(new App(), 'ApiTest'));
  template.allResourcesProperties('AWS::Logs::LogGroup', { RetentionInDays: 14 });
  template.hasResourceProperties('AWS::IAM::Role', { Policies: [Match.objectLike({
    PolicyDocument: { Version: '2012-10-17', Statement: [
      Match.objectLike({ Action: ['dynamodb:GetItem', 'dynamodb:Query', 'dynamodb:PutItem'], Resource: Match.anyValue() }),
      Match.objectLike({ Action: ['logs:CreateLogStream', 'logs:PutLogEvents'], Resource: Match.anyValue() }),
    ] },
  })] });
});
