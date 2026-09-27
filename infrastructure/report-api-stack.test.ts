import { test } from 'node:test';
import { App } from 'aws-cdk-lib';
import { Match, Template } from 'aws-cdk-lib/assertions';
import { ReportApiStack } from './report-api-stack';

test('AI route throttle is opt-in and leaves report defaults intact', () => {
  const template = Template.fromStack(new ReportApiStack(new App(), 'ThrottleTest'));
  template.hasParameter('EnableAiRouteThrottling', {
    Default: 'false', AllowedValues: ['false', 'true'],
  });
  template.hasCondition('HasAiRoute', { 'Fn::Equals': [{ Ref: 'EnableAiRouteThrottling' }, 'true'] });
  template.hasResourceProperties('AWS::ApiGatewayV2::Stage', {
    DefaultRouteSettings: { ThrottlingBurstLimit: 10, ThrottlingRateLimit: 5 },
    RouteSettings: { 'Fn::If': ['HasAiRoute', {
      'POST /ai/compose': { ThrottlingBurstLimit: 2, ThrottlingRateLimit: 1 },
    }, {}] },
  });
});

test('all report routes require JWT and operation scope', () => {
  const template = Template.fromStack(new ReportApiStack(new App(), 'ApiTest'));
  template.resourceCountIs('AWS::ApiGatewayV2::Route', 6);
  for (const route of ['GET /reports', 'GET /reports/{reportID}', 'DELETE /reports/{reportID}', 'PUT /reports/{reportID}', 'POST /reports/{reportID}/assets/upload', 'GET /reports/{reportID}/assets/{assetID}']) {
    template.hasResourceProperties('AWS::ApiGatewayV2::Route', {
      RouteKey: route, AuthorizationType: 'JWT', AuthorizerId: Match.anyValue(),
      AuthorizationScopes: [(route.startsWith('PUT') || route.startsWith('POST') || route.startsWith('DELETE')) ? 'reports/write' : 'reports/read'],
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
      Match.objectLike({ Action: ['s3:GetObject', 's3:PutObject'], Resource: Match.anyValue() }),
      Match.objectLike({ Action: ['logs:CreateLogStream', 'logs:PutLogEvents'], Resource: Match.anyValue() }),
    ] },
  })] });
});

 test('image bucket is private, encrypted and retained', () => {
  const template = Template.fromStack(new ReportApiStack(new App(), 'AssetsTest'));
  template.hasResource('AWS::S3::Bucket', {
    DeletionPolicy: 'Retain',
    Properties: Match.objectLike({
      PublicAccessBlockConfiguration: { BlockPublicAcls: true, BlockPublicPolicy: true,
        IgnorePublicAcls: true, RestrictPublicBuckets: true },
      BucketEncryption: { ServerSideEncryptionConfiguration: [{ ServerSideEncryptionByDefault: { SSEAlgorithm: 'AES256' } }] },
    }),
  });
});
