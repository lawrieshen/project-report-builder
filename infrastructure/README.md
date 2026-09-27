# AWS development foundation

Target: account `543123648742`, Sydney (`ap-southeast-2`).

This stack defines Cognito Essentials, a public OAuth client, Managed Login,
report read/write scopes, and an owner-partitioned DynamoDB table. It does not
create a test user, API, Lambda, S3 bucket, or authentication implementation.
The macOS client must implement PKCE S256, state validation, callback handling,
and token refresh; configuring code flow alone does not implement PKCE.

## Validate locally

```sh
cd infrastructure
npm ci
npm test
npm run synth -- --quiet
```

The generated template is `cdk.out/prb-dev-foundation.template.json`.
Dependencies and the lockfile are committed together. No AWS write access is
needed to synthesize or run these tests.

## Deployment status

Deployed on 2026-09-27 with stack status `CREATE_COMPLETE`. Non-secret IDs and
confirmed return URIs are in [dev-outputs.json](dev-outputs.json).
The `prb-deploy` profile uses the PRBFoundationDeploy permission set.
No test user, API, Lambda, or client login flow has been created.

## Before subsequent deployment

- `prb-dev` currently has ReadOnlyAccess and cannot create this stack.
- Confirm actual callback and logout URLs implemented by the macOS app. They
  are required CloudFormation parameters with no guessed defaults.
- Configure AWS budget notifications. Authentication's free allowance is not
  a spending cap; DynamoDB and other services have separate pricing.
- Use an authorized deployment role/profile. Do not replace the existing
  read-only permission set or store root access keys.

For this foundation only, an administrator can deploy the synthesized template
through CloudFormation without CDK bootstrap because there are no code assets.
The deployment identity (or CloudFormation service role) needs stack management
and the Cognito/DynamoDB create, describe, update, tagging, and deletion actions
needed by the template. Restrict it to the development account/region and scope
resource ARNs where supported. This stack creates no IAM roles.
If using a CloudFormation service role, the deployer also needs scoped iam:PassRole.
Have the AWS administrator review the generated template before granting access.

Alternatively, CDK deployment requires a bootstrapped environment. Bootstrap
creates deployment IAM roles, S3/ECR assets, and an SSM version parameter; an
administrator must review its execution policies. Do not blindly grant a
permanent AdministratorAccess permission set just to bootstrap this stack.

## Deploy the reviewed template

With an authorized profile and confirmed URLs, run from this directory:

```sh
aws cloudformation deploy \
  --profile prb-deploy \
  --region ap-southeast-2 \
  --stack-name prb-dev-foundation \
  --template-file cdk.out/prb-dev-foundation.template.json \
  --parameter-overrides CallbackUrl='<actual-callback-url>' LogoutUrl='<actual-logout-url>'
```

`prb-deploy` is configured locally; renew its SSO login before deployment when needed.
This asset-free stack uses BootstraplessSynthesizer; it does not require a
CDKToolkit stack. Revisit this when packaged Lambda assets are introduced.

After deployment, inspect Outputs for pool ID, client ID, issuer, domain, and
table name. Create a test user through Cognito's administrator interface, then
configure their approved `sub` in the future backend. Never commit the password.
Do not confuse this app user with the Identity Center developer `lawrence-dev`.

## Cleanup

The user pool and report table have deletion protection and RETAIN policies.
Deleting the stack does not delete these resources or their data and does not
necessarily end all charges. To remove the POC completely, explicitly review
and disable deletion protection and delete the retained resources when no data
is needed. Retained resource names can also prevent creating a replacement stack.
