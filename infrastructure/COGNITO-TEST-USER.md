# Provision the single Cognito test user

The foundation is deployed, but app authentication and report APIs are not yet
implemented. This user is an app user, not the Identity Center user used by CLI.

## Create the user

Use an authorized administrator in the AWS console:

1. Select Sydney (`ap-southeast-2`) and open Amazon Cognito.
2. Open `prb-dev-users` (pool `ap-southeast-2_8f8EhWpSM`).
3. Open Users and choose Create user.
4. Enter the test user's email and choose the appropriate temporary-password
   option. Only mark the email verified after ownership has been established.
5. Configure invitation delivery explicitly if an email invitation is wanted.
   Do not put passwords in source files, shell history, logs, or chat.
6. The user changes the temporary password during their first Managed Login.

The deployed password policy requires at least 12 characters, including upper
and lower case letters, a number, and a symbol. Temporary passwords expire in
7 days. Recovery is administrator-only in this POC.

The foundation deployment role intentionally has no AdminCreateUser or password
management permissions. Creating a user requires an administrator or a separate,
pool-scoped user-provisioning permission. Do not broaden deployment permissions
just to administer accounts.

## Approve the user for the future report API

After creation, inspect the user attributes and record the `sub`. Configure this
exact subject in the backend's approved-user configuration; do not use the email
or accept an owner ID supplied in a request body. No report API exists yet, so
creating the user does not currently enable report access.

## Validate the login integration when implemented

- First login and temporary-password change complete through Managed Login.
- Authorization Code + PKCE S256 and callback state are checked.
- Cancellation returns to the app without changing local reports.
- Unapproved users cannot access report endpoints, even with valid tokens.
- Refresh credentials use Keychain; logout clears them and ends hosted login.
- Test the packaged macOS callback, not only an Xcode run.

## Foundation readiness check

On 2026-09-27, the public OIDC discovery endpoint returned the expected issuer,
authorization endpoint, token endpoint, and signing-key URL. A subsequent check found exactly one enabled user with status
`FORCE_CHANGE_PASSWORD`: the user must change their temporary password at first
login. The approved subject, issuer, and client ID are recorded in
[dev-auth-config.json](dev-auth-config.json). These identifiers are not passwords.
The file is preparation for the future authentication adapter; no deployed API
currently reads or enforces it. This is configuration evidence, not an
end-to-end login or upload test.
