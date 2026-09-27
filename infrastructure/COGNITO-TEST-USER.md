# Provision the single Cognito test user

This user is an app user, not the Identity Center user used by CLI.
Deploy [native sign-in](NATIVE-SIGN-IN.md) before using the email/password card.

## Create the user

Use an authorized administrator in the AWS console:

1. Select Sydney (`ap-southeast-2`) and open Amazon Cognito.
2. Open `prb-dev-users` (pool `ap-southeast-2_8f8EhWpSM`).
3. Open Users and choose Create user.
4. Enter the test user's email and choose the appropriate temporary-password
   option. Only mark the email verified after ownership has been established.
5. Configure invitation delivery explicitly if an email invitation is wanted.
   Do not put passwords in source files, shell history, logs, or chat.
6. The user changes the temporary password in the app during their first sign-in.

The deployed password policy requires at least 12 characters, including upper
and lower case letters, a number, and a symbol. Temporary passwords expire in
7 days. Recovery is administrator-only in this POC.

The foundation deployment role intentionally has no AdminCreateUser or password
management permissions. Creating a user requires an administrator or a separate,
pool-scoped user-provisioning permission. Do not broaden deployment permissions
just to administer accounts.

## Approve the user for report access

After creation, inspect the user attributes and record the `sub`. Configure this
exact subject in both the backend's approved-user configuration and the foundation
`ApprovedSubject` parameter. Do not authorize by email or by an owner ID from a
request body. The native-auth trigger also checks the app client ID.

## Try the macOS login integration

1. Launch the app and enter the provisioned Cognito user's email and password.
   Use the app test user, not the AWS root or Identity Center account.
2. Complete the new-password card if the account has a temporary password.
3. Confirm the cloud report browser opens and verify report and image reads/writes.
4. Restart the app to verify Keychain-backed session restoration.
5. Sign out in Settings > Cloud Account and confirm the sign-in card returns.

## Manual validation checklist

- Wrong passwords and network failures keep the user signed out with a clear message.
- Temporary passwords require a successful password change before entering reports.
- Unapproved users cannot access reports, even with otherwise valid credentials.
- Refresh credentials use Keychain; logout clears them and attempts revocation.
- No password or token is written to source, logs, shell history, or chat.
- MFA and extra profile-attribute challenges show an administrator-assistance message.

The current approved subject, issuer, and client ID are recorded in
[dev-auth-config.json](dev-auth-config.json). These identifiers are not secrets.
The native-login foundation was deployed on 2026-09-27. Live sign-in and report
access verification in the app remain pending.
