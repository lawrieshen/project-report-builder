# Native email/password sign-in

The macOS sign-in card now calls Cognito `USER_PASSWORD_AUTH` directly over HTTPS.
The client has no secret and the app contains no AWS credentials. Passwords are
kept only for the current request; only refresh tokens are persisted in Keychain.
Refresh uses `REFRESH_TOKEN_AUTH`; revocation continues using the Cognito domain.
The existing browser configuration is retained for deployment rollback.

## Deploy before using the new app

1. Update the deployment permission set with `policies/foundation-deploy.json`.
   It adds access only to the named native-auth Lambda, execution role and log group.
2. Refresh `prb-deploy` SSO if required: `aws sso login --profile prb-deploy`.
3. Run `npm test` and `npm run synth -- prb-dev-foundation` from `infrastructure`.
4. Create/review a CloudFormation change set for `prb-dev-foundation`, using
   `cdk.out/prb-dev-foundation.template.json` and `CAPABILITY_NAMED_IAM`.
   Preserve CallbackUrl and LogoutUrl with UsePreviousValue. Supply:
   - NativeAppClientId: `50140nj121i4sbsra4m8o37cqq`
   - ApprovedSubject: `092e2408-5041-706a-684d-db818c51805c`
5. Confirm it adds the native-auth Lambda/role/log group and updates the existing
   pool and client without replacing the pool or DynamoDB table. Execute it.

The V2 pre-token trigger permits the configured client and subject only, for both
initial authentication and refresh, then adds `reports/read` and `reports/write`.
The API's JWT scope checks and owner isolation remain enabled. Trigger logs retain
14 days and never intentionally log events, credentials or tokens.

The client parameter refers to the existing client to avoid a CloudFormation
pool → trigger → client → pool cycle. For a fresh environment, provision the
pool/client first, then enable this trigger with that client's actual ID.

## Verification

- Sign in with the provisioned email/password and read/write a report and image.
- For a temporary password, complete the new-password card and repeat the checks.
- Restart and confirm session restoration; sign out and confirm the form returns.
- Check wrong password, throttling, network failure and expired refresh behavior.
- Confirm an unapproved account/client cannot receive report scopes.
- MFA/profile-attribute challenges are not implemented; the app requests admin
  assistance instead of treating them as a successful login.

UI tests run in GitHub Actions. Live account verification requires the user to
enter credentials in the app; do not paste passwords or tokens into logs/chat.

## Deployment status

On 2026-09-27, change set `native-email-sign-in` completed with
`UPDATE_COMPLETE` in `prb-dev-foundation`. Read-back verified password and
refresh auth flows, the V2 token trigger, and invocation restricted to the
expected Cognito pool and AWS account. Live email/password login and report
access verification remain pending user testing in the app.
