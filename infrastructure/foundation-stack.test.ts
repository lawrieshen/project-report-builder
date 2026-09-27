import { test } from 'node:test';
import { App } from 'aws-cdk-lib';
import { Template } from 'aws-cdk-lib/assertions';
import { FoundationStack } from './foundation-stack';

const template = Template.fromStack(new FoundationStack(new App(), 'Test', {
  env: { account: '543123648742', region: 'ap-southeast-2' },
}));

test('login is admin-provisioned with a public authorization-code client', () => {
  template.hasResourceProperties('AWS::Cognito::UserPool', {
    UserPoolTier: 'ESSENTIALS',
    AdminCreateUserConfig: { AllowAdminCreateUserOnly: true },
    DeletionProtection: 'ACTIVE',
  });
  template.hasResourceProperties('AWS::Cognito::UserPoolClient', {
    GenerateSecret: false, AllowedOAuthFlows: ['code'],
    ExplicitAuthFlows: ['ALLOW_USER_PASSWORD_AUTH', 'ALLOW_REFRESH_TOKEN_AUTH'],
    AllowedOAuthScopes: ['openid', 'email', 'reports/read', 'reports/write'],
    EnableTokenRevocation: true,
  });
});

test('reports are owner-partitioned and retained on stack deletion', () => {
  template.hasResource('AWS::DynamoDB::Table', {
    DeletionPolicy: 'Retain', UpdateReplacePolicy: 'Retain',
    Properties: {
      BillingMode: 'PAY_PER_REQUEST', DeletionProtectionEnabled: true,
      KeySchema: [
        { AttributeName: 'ownerID', KeyType: 'HASH' },
        { AttributeName: 'reportID', KeyType: 'RANGE' },
      ],
    },
  });
});

test('foundation exposes no report endpoint before authentication adapters exist', () => {
  template.resourceCountIs('AWS::Lambda::Function', 1);
  template.resourceCountIs('AWS::ApiGatewayV2::Api', 0);
});

 test('native sign-in customizes access tokens with a V2 trigger', () => {
  template.hasResourceProperties('AWS::Cognito::UserPool', {
    LambdaConfig: { PreTokenGenerationConfig: { LambdaVersion: 'V2_0' } },
  });
  template.hasResourceProperties('AWS::Lambda::Permission', {
    Principal: 'cognito-idp.amazonaws.com', SourceAccount: '543123648742',
  });
});
