# Report API deployment preparation

The Java Lambda adapter and CDK stack are implemented and locally tested.
The API was deployed successfully on 2026-09-27. See
[dev-api-outputs.json](dev-api-outputs.json) for its endpoint and artifact.
Settings > Cloud Account now provides manual saved-report upload and download.

## Build and synthesize

From the repository root:

```sh
bash backend/package.sh
npm --prefix infrastructure test
npm --prefix infrastructure run synth -- --context includeReportApi=true prb-dev-report-api --quiet
```

Deploy `backend/target/report-api.zip`, which places the shaded JAR in `lib/`.
Use an immutable artifact key (for example, the ZIP's SHA-256 followed by `.zip`)
in a private S3 deployment bucket in Sydney. This bucket holds code artifacts,
not user image assets. Block public access and enable server-side encryption.

The synthesized template is
`infrastructure/cdk.out/prb-dev-report-api.template.json`.
It accepts these parameters:

| Parameter | Value |
| --- | --- |
| ArtifactBucket | Private deployment bucket name |
| ArtifactKey | Immutable uploaded ZIP key |
| CognitoIssuer | `issuer` from `dev-outputs.json` |
| CognitoClientId | `appClientId` from `dev-outputs.json` |
| ApprovedSubject | `approvedSubject` from `dev-auth-config.json` |

## Assign the deployment permission set

1. In IAM Identity Center (Sydney), open Permission sets and create a custom
   permission set named `PRBReportApiDeploy`, with a one-hour session duration.
2. Add [report-api-deploy.json](policies/report-api-deploy.json) as its inline
   policy. No AdministratorAccess managed policy is needed.
3. Under AWS accounts, select `543123648742`, assign `lawrence-dev` to this
   permission set, and wait until provisioning completes.
4. Tell the deployment operator the assignment is complete. Configure a separate
   CLI profile for `PRBReportApiDeploy` using the existing `prb-dev` SSO session.
   Keep the foundation profile unchanged.

The policy was checked with IAM Access Analyzer on 2026-09-27 (no findings).
That validates policy structure, not guaranteed successful deployment.
API Gateway management covers HTTP APIs in Sydney because the API ID is not
known until creation; narrow those ARNs to the created API afterward. Log
delivery setup needs region-wide permissions. IAM policy management is limited
to the named execution role, but still grants the operator control over that
role's inline permissions; reserve this permission set for trusted deployers.

The private artifact bucket template is [artifacts.template.json](artifacts.template.json).
It passed CloudFormation template validation and has not been deployed. It
uses the proposed name `prb-dev-artifacts-543123648742-ap-southeast-2`, blocks
public access, enforces TLS and bucket-owner ownership, and uses SSE-S3.
Global name availability is only confirmed when the bucket is created.

## Deployment permissions still required

The existing `PRBFoundationDeploy` permission set covers only the foundation
stack. It must not be assumed to authorize this deployment. An administrator
must provide a scoped deployment role/permission set covering:

- CloudFormation operations on `prb-dev-report-api`.
- The private artifact bucket and uploaded code object.
- Lambda operations on `prb-dev-report-api`.
- IAM creation/update of `prb-dev-report-api-execution`, including inline policy
  management and `iam:PassRole` restricted to that role and Lambda.
- API Gateway HTTP API resources in `ap-southeast-2`.
- The two CloudWatch log groups declared in the template.

Review a CloudFormation change set before execution. The execution role has
only GetItem, Query and PutItem access to `prb-dev-reports`, plus writes to its
own log group. Both log groups retain logs for 14 days. No report deletion,
public function URL, user registration, or image bucket is introduced.

## Authentication boundary

API Gateway's JWT authorizer verifies signatures, issuer, audience and token
times. Each route requires its read or write scope. Lambda consumes only the
trusted `requestContext.authorizer.jwt.claims` and additionally requires
`token_use=access`, the configured client, unexpired token, operation scope,
and approved subject. Request bodies cannot select an owner.

This design trusts the gateway integration, not arbitrary caller-supplied
Lambda events. Do not expose another invoke path or grant untrusted users
`lambda:InvokeFunction`. Direct IAM-authorized Lambda invocation is a privileged
administrative capability. Unit tests of event claims do not test cryptographic
JWT verification: that is an AWS-managed boundary and needs deployment smoke
checks. API Gateway JWT validation does not consult Cognito revocation status;
an already issued access token can remain usable until expiry.

## Verification after deployment

- Missing, forged, expired, wrong-issuer and wrong-client JWTs are rejected.
- ID tokens and access tokens without the route scope are rejected.
- A valid token for an unapproved subject cannot access reports.
- Create a report, read/list it, then update with the current revision.
- Retry a stale revision and confirm HTTP 409 without overwriting data.
- Unknown body fields (including ownerID and assets), malformed UUIDs/dates,
  missing fields and scalar coercion are rejected with HTTP 400.
- Confirm reports survive separate Lambda invocations and logs contain neither
  tokens nor report contents. Delete test records using an administrator only.

Local tests use fake DynamoDB responses; live conditional-write behavior and
owner isolation must also be checked against the deployed table/API. authenticated macOS upload/download verification is still required.

## Deployment attempt — 2026-09-27

- `prb-dev-artifacts`: CREATE_COMPLETE. The private ZIP artifact is uploaded.
- `prb-dev-report-api`: ROLLBACK_COMPLETE. Stage creation was denied the
  `apigateway:TagResource` action. The API is not available.
- `report-api-deploy.json` now includes this action scoped to stage collections.
  Update the assigned permission set and reprovision before retrying.
- IAM Access Analyzer labels this action INVALID_ACTION despite API Gateway
  requiring it. AWS documents the discrepancy in this
  [support answer](https://repost.aws/questions/QUJNhKhE88QfWw-sD7DNinvg/i-have-added-apigateway-tagresource-in-iam-policy-and-its-giving-error).
  The earlier no-findings result applies to the original policy, not this revision.
- Before recreating the failed stack, inspect retained log groups. Reuse/import
  them, or remove only empty groups from this failed attempt to avoid name clashes.

## Successful deployment retry — 2026-09-27

After the administrator provisioned the Stage tagging permission, the failed
stack record and its two verified-empty retained log groups were removed.
The recreated stack reached CREATE_COMPLETE, and Lambda reports Active with
LastUpdateStatus Successful on Java 21. All three routes require JWT and their
respective reports/read or reports/write scope. The authorizer has the expected
Cognito issuer and app client audience.

Live GET /reports checks returned HTTP 401 both without a token and with an
invalid token. This does not invoke the handler or verify authenticated data
access. Valid-token create/read/update/conflict tests remain pending. The macOS
transfer UI is now implemented. No test reports were written during these checks.

## Check transfers in the signed-in app

1. Save a small report without images, then open Settings > Cloud Account.
2. Select the local project and choose Upload Saved Version. Confirm it appears
   in Cloud Reports as Version 1.
3. Save a local change and upload again. Confirm Version 2.
4. Download Copy and return to Browser. Confirm a new project appears and the
   original project and any open draft remain unchanged.
5. Try a report with images: it must show an unsupported message without upload.
6. Verify offline errors preserve local reports and that retrying a successful
   upload whose response was lost reconciles only matching content/revision.

Do not paste access tokens into chat or store them in scripts or Git.

## Test-user subject correction — 2026-09-27

Authenticated requests reached Lambda but were rejected because ApprovedSubject
still referenced the earlier test-user sub. Cognito now has one confirmed user,
whose sub is recorded in dev-auth-config.json. The stack parameter was updated
through a change set; no JWT or owner-isolation checks were removed. The local
upload-history namespace now uses the current subject, leaving any old file
untouched. Recreating a Cognito user requires reviewing and updating this
allowlist even if the email is unchanged.

## Initial query correction — 2026-09-27

After correcting the approved subject, the first authenticated GET /reports
returned HTTP 500. A count-only DynamoDB reproduction rejected an explicitly
empty ExclusiveStartKey. The repository now omits that parameter on the first
page. The Lambda logs exception class and AWS error code without logging report
contents or credentials. The client distinguishes HTTP 5xx and 403 from invalid
report requests. Java verification passed 18 tests; macOS build passed.
Authenticated retry from the app remains required to confirm the live result.

## Manual verification result — 2026-09-27

After the subject and initial-query corrections, the developer reported that
all guided cloud transfer steps worked. This is manual verification evidence;
it does not replace the remaining negative-token and multi-client conflict
checks listed above.
