import { CfnCondition, CfnOutput, CfnParameter, Fn, RemovalPolicy, Stack, StackProps, Tags } from 'aws-cdk-lib';
import { aws_apigatewayv2 as gateway, aws_iam as iam, aws_lambda as lambda, aws_logs as logs, aws_s3 as s3 } from 'aws-cdk-lib';
import { Construct } from 'constructs';

/** Expose the report service only through scoped Cognito JWT routes. */
export class ReportApiStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);
    Tags.of(this).add('Project', 'ProjectReportBuilder');
    Tags.of(this).add('Environment', 'dev');

    const bucket = new CfnParameter(this, 'ArtifactBucket', { description: 'Private deployment bucket in this region.' });
    const key = new CfnParameter(this, 'ArtifactKey', { description: 'Immutable S3 key for the tested Java JAR.' });
    const issuer = new CfnParameter(this, 'CognitoIssuer');
    const client = new CfnParameter(this, 'CognitoClientId');
    const subject = new CfnParameter(this, 'ApprovedSubject', { minLength: 1 });
    const aiThrottle = new CfnParameter(this, 'EnableAiRouteThrottling', {
      default: 'false', allowedValues: ['false', 'true'],
      description: 'Enable only after the separate AI stack has created POST /ai/compose.',
    });
    const hasAiRoute = new CfnCondition(this, 'HasAiRoute', {
      expression: Fn.conditionEquals(aiThrottle.valueAsString, 'true'),
    });
    const functionLogs = new logs.LogGroup(this, 'FunctionLogs', {
      logGroupName: '/aws/lambda/prb-dev-report-api', retention: logs.RetentionDays.TWO_WEEKS,
      removalPolicy: RemovalPolicy.RETAIN,
    });
    const apiLogs = new logs.LogGroup(this, 'ApiLogs', {
      logGroupName: '/prb-dev/report-api', retention: logs.RetentionDays.TWO_WEEKS,
      removalPolicy: RemovalPolicy.RETAIN,
    });
    const assets = new s3.Bucket(this, 'Assets', {
      bucketName: `prb-dev-assets-${this.account}-${this.region}`,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      objectOwnership: s3.ObjectOwnership.BUCKET_OWNER_ENFORCED,
      enforceSSL: true, removalPolicy: RemovalPolicy.RETAIN,
    });
    const role = new iam.Role(this, 'ExecutionRole', {
      roleName: 'prb-dev-report-api-execution', assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
      inlinePolicies: { Reports: new iam.PolicyDocument({ statements: [
        new iam.PolicyStatement({ actions: ['dynamodb:GetItem', 'dynamodb:Query', 'dynamodb:PutItem'],
          resources: [`arn:aws:dynamodb:${this.region}:${this.account}:table/prb-dev-reports`] }),
        new iam.PolicyStatement({ actions: ['s3:GetObject', 's3:PutObject'],
          resources: [assets.arnForObjects('reports/*')] }),
        new iam.PolicyStatement({ actions: ['logs:CreateLogStream', 'logs:PutLogEvents'],
          resources: [functionLogs.logGroupArn] }),
      ] }) },
    });
    const handler = new lambda.CfnFunction(this, 'Handler', {
      functionName: 'prb-dev-report-api', runtime: 'java21', architectures: ['arm64'],
      handler: 'com.projectreportbuilder.cloud.ReportApiHandler::handleRequest',
      role: role.roleArn, memorySize: 512, timeout: 20,
      code: { s3Bucket: bucket.valueAsString, s3Key: key.valueAsString },
      environment: { variables: {
        ASSETS_BUCKET: assets.bucketName, REPORTS_TABLE: 'prb-dev-reports', COGNITO_ISSUER: issuer.valueAsString,
        COGNITO_CLIENT_ID: client.valueAsString, APPROVED_SUBJECT: subject.valueAsString,
      } },
    });
    const api = new gateway.CfnApi(this, 'Api', { name: 'prb-dev-api', protocolType: 'HTTP' });
    const authorizer = new gateway.CfnAuthorizer(this, 'Authorizer', {
      apiId: api.ref, name: 'Cognito', authorizerType: 'JWT',
      identitySource: ['$request.header.Authorization'],
      jwtConfiguration: { issuer: issuer.valueAsString, audience: [client.valueAsString] },
    });
    const integration = new gateway.CfnIntegration(this, 'Integration', {
      apiId: api.ref, integrationType: 'AWS_PROXY', integrationUri: handler.attrArn,
      payloadFormatVersion: '2.0', timeoutInMillis: 25000,
    });
    const routes = [
      ['List', 'GET /reports', 'reports/read'],
      ['Get', 'GET /reports/{reportID}', 'reports/read'],
      ['UploadImage', 'POST /reports/{reportID}/assets/upload', 'reports/write'],
      ['DownloadImage', 'GET /reports/{reportID}/assets/{assetID}', 'reports/read'],
      ['Delete', 'DELETE /reports/{reportID}', 'reports/write'],
      ['Save', 'PUT /reports/{reportID}', 'reports/write'],
    ];
    for (const [name, routeKey, scope] of routes) {
      new gateway.CfnRoute(this, name, { apiId: api.ref, routeKey,
        target: `integrations/${integration.ref}`, authorizationType: 'JWT',
        authorizerId: authorizer.ref, authorizationScopes: [scope] });
    }
    new gateway.CfnStage(this, 'Stage', {
      apiId: api.ref, stageName: '$default', autoDeploy: true,
      defaultRouteSettings: { throttlingBurstLimit: 10, throttlingRateLimit: 5 },
      // Keep stage ownership here; the composer stack must not modify this stage directly.
      routeSettings: Fn.conditionIf(hasAiRoute.logicalId, {
        'POST /ai/compose': { ThrottlingBurstLimit: 2, ThrottlingRateLimit: 1 },
      }, {}),
      accessLogSettings: { destinationArn: apiLogs.logGroupArn, format: JSON.stringify({
        requestId: '$context.requestId', routeKey: '$context.routeKey', status: '$context.status',
      }) },
    });
    new lambda.CfnPermission(this, 'GatewayPermission', {
      action: 'lambda:InvokeFunction', functionName: handler.ref, principal: 'apigateway.amazonaws.com',
      sourceAccount: this.account,
      sourceArn: `arn:aws:execute-api:${this.region}:${this.account}:${api.ref}/*/*/reports*`,
    });
    new CfnOutput(this, 'ApiUrl', { value: api.attrApiEndpoint });
  }
}
