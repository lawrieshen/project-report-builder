import { CfnCondition, CfnOutput, CfnParameter, Fn, RemovalPolicy, Stack, StackProps, Tags } from 'aws-cdk-lib';
import { aws_apigatewayv2 as gateway, aws_dynamodb as dynamodb, aws_iam as iam,
  aws_lambda as lambda, aws_logs as logs, aws_cloudwatch as cloudwatch,
  aws_cloudwatch_actions as actions, aws_sns as sns } from 'aws-cdk-lib';
import { Construct } from 'constructs';

/** Provision an isolated, initially disabled composer on the existing report API. */
export class AiComposeStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);
    Tags.of(this).add('Project', 'ProjectReportBuilder');
    Tags.of(this).add('Environment', 'dev');
    const bucket = new CfnParameter(this, 'ArtifactBucket');
    const key = new CfnParameter(this, 'ArtifactKey', {
      description: 'Immutable key of the tested Python 3.12 Linux arm64 deployment ZIP.',
    });
    const enabled = new CfnParameter(this, 'AiEnabled', { default: 'false', allowedValues: ['false', 'true'] });
    const policy = new CfnParameter(this, 'BudgetPolicy', { default: '',
      description: 'Verified BudgetPolicy JSON; required before explicit enablement.' });
    const pricesExpire = new CfnParameter(this, 'PriceValidUntil', { default: '',
      description: 'UTC ISO timestamp after which the verified prices must not be used.' });
    const api = new CfnParameter(this, 'HttpApiId');
    const authorizer = new CfnParameter(this, 'JwtAuthorizerId');
    const issuer = new CfnParameter(this, 'CognitoIssuer');
    const client = new CfnParameter(this, 'CognitoClientId');
    const subject = new CfnParameter(this, 'ApprovedSubject', { minLength: 1 });
    const secretArn = 'arn:aws:secretsmanager:ap-southeast-2:543123648742:secret:prb-dev/gemini-api-key-NWLQoy';
    const table = new dynamodb.Table(this, 'Usage', {
      tableName: 'prb-dev-ai-usage', partitionKey: { name: 'pk', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST, timeToLiveAttribute: 'expiresAt',
      removalPolicy: RemovalPolicy.RETAIN,
    });
    const functionLogs = new logs.LogGroup(this, 'Logs', {
      logGroupName: '/aws/lambda/prb-dev-ai-compose', retention: logs.RetentionDays.TWO_WEEKS,
      removalPolicy: RemovalPolicy.RETAIN,
    });
    const budgetMetric = new logs.MetricFilter(this, 'BudgetMetric', {
      logGroup: functionLogs, filterPattern: logs.FilterPattern.stringValue('$.event', '=', 'ai_budget'),
      metricNamespace: 'ProjectReportBuilder/AI', metricName: 'BudgetPercent',
      metricValue: '$.budgetPercent',
    });
    const alertEmail = new CfnParameter(this, 'BudgetAlertEmail', {
      default: '', description: 'Owner-approved notification address; requires email subscription confirmation.',
      allowedPattern: '^$|^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$',
    });
    const hasAlertEmail = new CfnCondition(this, 'HasAlertEmail', {
      expression: Fn.conditionNot(Fn.conditionEquals(alertEmail.valueAsString, '')),
    });
    const alertTopic = new sns.Topic(this, 'BudgetAlerts', { topicName: 'prb-dev-ai-budget-alerts' });
    const subscription = new sns.CfnSubscription(this, 'BudgetEmail', {
      topicArn: alertTopic.topicArn, protocol: 'email', endpoint: alertEmail.valueAsString,
    });
    subscription.cfnOptions.condition = hasAlertEmail;
    const alarm = new cloudwatch.Alarm(this, 'BudgetWarning', {
      alarmName: 'prb-dev-ai-budget-warning',
      alarmDescription: 'Application AI budget reservations reached 80%; review before further generation.',
      metric: budgetMetric.metric({ statistic: 'Maximum' }), threshold: 80, evaluationPeriods: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    alertTopic.addToResourcePolicy(new iam.PolicyStatement({
      principals: [new iam.ServicePrincipal('cloudwatch.amazonaws.com')],
      actions: ['sns:Publish'], resources: [alertTopic.topicArn],
      conditions: { StringEquals: { 'aws:SourceAccount': this.account },
        ArnEquals: { 'aws:SourceArn': alarm.alarmArn } },
    }));
    alarm.addAlarmAction(new actions.SnsAction(alertTopic));
    const role = new iam.Role(this, 'ExecutionRole', {
      roleName: 'prb-dev-ai-compose-execution', assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
      inlinePolicies: { Compose: new iam.PolicyDocument({ statements: [
        new iam.PolicyStatement({ actions: ['secretsmanager:GetSecretValue'], resources: [secretArn] }),
        new iam.PolicyStatement({ actions: ['dynamodb:GetItem', 'dynamodb:PutItem'], resources: [table.tableArn] }),
        new iam.PolicyStatement({ actions: ['logs:CreateLogStream', 'logs:PutLogEvents'],
          resources: [functionLogs.logGroupArn] }),
      ] }) },
    });
    // TransactWriteItems authorizes its individual Put operations with dynamodb:PutItem.
    const handler = new lambda.CfnFunction(this, 'Handler', {
      functionName: 'prb-dev-ai-compose', runtime: 'python3.12', architectures: ['arm64'],
      handler: 'prb_ai.handler.lambda_handler', role: role.roleArn,
      memorySize: 512, timeout: 25, reservedConcurrentExecutions: 2,
      code: { s3Bucket: bucket.valueAsString, s3Key: key.valueAsString },
      environment: { variables: {
        AI_ENABLED: enabled.valueAsString, AI_BUDGET_POLICY: policy.valueAsString,
        AI_PRICE_VALID_UNTIL: pricesExpire.valueAsString, AI_USAGE_TABLE: table.tableName, GEMINI_SECRET_ARN: secretArn,
        COGNITO_ISSUER: issuer.valueAsString, COGNITO_CLIENT_ID: client.valueAsString,
        APPROVED_SUBJECT: subject.valueAsString,
      } },
    });
    handler.addDependency(functionLogs.node.defaultChild as logs.CfnLogGroup);
    const integration = new gateway.CfnIntegration(this, 'Integration', {
      apiId: api.valueAsString, integrationType: 'AWS_PROXY', integrationUri: handler.attrArn,
      payloadFormatVersion: '2.0', timeoutInMillis: 29000,
    });
    new gateway.CfnRoute(this, 'Compose', {
      apiId: api.valueAsString, routeKey: 'POST /ai/compose', target: `integrations/${integration.ref}`,
      authorizationType: 'JWT', authorizerId: authorizer.valueAsString, authorizationScopes: ['reports/write'],
    });
    new lambda.CfnPermission(this, 'GatewayPermission', {
      action: 'lambda:InvokeFunction', functionName: handler.ref, principal: 'apigateway.amazonaws.com',
      sourceAccount: this.account,
      sourceArn: `arn:aws:execute-api:${this.region}:${this.account}:${api.valueAsString}/*/POST/ai/compose`,
    });
    new CfnOutput(this, 'UsageTable', { value: table.tableName });
  }
}
