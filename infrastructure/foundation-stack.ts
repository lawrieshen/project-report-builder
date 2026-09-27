import { CfnOutput, CfnParameter, RemovalPolicy, Stack, StackProps, Tags } from 'aws-cdk-lib';
import { aws_cognito as cognito, aws_dynamodb as dynamodb } from 'aws-cdk-lib';
import { Construct } from 'constructs';

/** Provision identity and report storage before exposing report APIs. */
export class FoundationStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);
    Tags.of(this).add('Project', 'ProjectReportBuilder');
    Tags.of(this).add('Environment', 'dev');

    const callback = new CfnParameter(this, 'CallbackUrl', {
      description: 'Exact macOS authentication callback URL; must be implemented by the client.',
      allowedPattern: '^[a-z][a-z0-9+.-]*://[^\\s#]+$',
    });
    const logout = new CfnParameter(this, 'LogoutUrl', {
      description: 'Exact logout return URL implemented by the client.',
      allowedPattern: '^[a-z][a-z0-9+.-]*://[^\\s#]+$',
    });

    const pool = new cognito.CfnUserPool(this, 'Users', {
      userPoolName: 'prb-dev-users',
      userPoolTier: 'ESSENTIALS',
      usernameAttributes: ['email'],
      usernameConfiguration: { caseSensitive: false },
      autoVerifiedAttributes: ['email'],
      adminCreateUserConfig: { allowAdminCreateUserOnly: true },
      accountRecoverySetting: { recoveryMechanisms: [{ name: 'admin_only', priority: 1 }] },
      policies: { passwordPolicy: {
        minimumLength: 12, requireLowercase: true, requireUppercase: true,
        requireNumbers: true, requireSymbols: true, temporaryPasswordValidityDays: 7,
      } },
      deletionProtection: 'ACTIVE',
    });
    pool.applyRemovalPolicy(RemovalPolicy.RETAIN);

    const scopes = new cognito.CfnUserPoolResourceServer(this, 'ReportScopes', {
      userPoolId: pool.ref, identifier: 'reports', name: 'Report API',
      scopes: [
        { scopeName: 'read', scopeDescription: 'Read owned reports' },
        { scopeName: 'write', scopeDescription: 'Write owned reports' },
      ],
    });
    const client = new cognito.CfnUserPoolClient(this, 'MacClient', {
      userPoolId: pool.ref, clientName: 'prb-dev-macos', generateSecret: false,
      supportedIdentityProviders: ['COGNITO'],
      allowedOAuthFlowsUserPoolClient: true, allowedOAuthFlows: ['code'],
      allowedOAuthScopes: ['openid', 'email', 'reports/read', 'reports/write'],
      callbackUrLs: [callback.valueAsString], logoutUrLs: [logout.valueAsString],
      preventUserExistenceErrors: 'ENABLED', enableTokenRevocation: true,
      accessTokenValidity: 60, idTokenValidity: 60, refreshTokenValidity: 1,
      tokenValidityUnits: { accessToken: 'minutes', idToken: 'minutes', refreshToken: 'days' },
    });
    client.addResourceDependency(scopes);
    const domainPrefix = `prb-dev-${this.account}-${this.region}`;
    const domain = new cognito.CfnUserPoolDomain(this, 'LoginDomain', {
      userPoolId: pool.ref, domain: domainPrefix, managedLoginVersion: 2,
    });
    const branding = new cognito.CfnManagedLoginBranding(this, 'LoginBranding', {
      userPoolId: pool.ref, clientId: client.ref, useCognitoProvidedValues: true,
    });
    branding.addResourceDependency(domain);

    const reports = new dynamodb.Table(this, 'Reports', {
      tableName: 'prb-dev-reports',
      partitionKey: { name: 'ownerID', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'reportID', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
      deletionProtection: true, removalPolicy: RemovalPolicy.RETAIN,
    });
    new CfnOutput(this, 'UserPoolId', { value: pool.ref });
    new CfnOutput(this, 'AppClientId', { value: client.ref });
    new CfnOutput(this, 'Issuer', {
      value: `https://cognito-idp.${this.region}.amazonaws.com/${pool.ref}`,
    });
    new CfnOutput(this, 'LoginDomainUrl', {
      value: `https://${domainPrefix}.auth.${this.region}.amazoncognito.com`,
    });
    new CfnOutput(this, 'ReportsTableName', { value: reports.tableName });
  }
}
