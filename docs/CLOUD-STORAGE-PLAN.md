# Cloud storage plan and implementation status

[Back to README](../README.md)


The proposed cloud storage POC will use an existing identity service with
one pre-provisioned test user. Amazon Cognito Essentials with Email/Password
and Managed Login is the planned identity provider;
server-side verification and user approval are not implemented yet.
Self-service registration, password-reset UI, and role management are outside
the POC scope.

Cloud APIs must still authenticate requests and verify that the signed-in user
owns the report before allowing access. The app must not embed cloud administrator
credentials or a shared permanent API secret. This is a planning decision, not
an implemented login or cloud storage feature.

## Local milestone status

The [Java service and API contract](../backend/README.md) now cover text-only
report creation, reading, updates, owner isolation, pagination, and atomic revision
checks using in-memory storage. JUnit and JSON contract tests run locally and
are configured in the backend CI workflow.

No HTTP server, AWS adapter, authentication endpoint, image transfer, or macOS
cloud integration is implemented. Request retries cannot duplicate a committed
revision, but operation-ID replay support remains future work. This milestone
does not change the app's local persistence or enable uploads.

## Java backend technology decision

The current planning baseline is **Maven + Java Lambda handlers** behind
API Gateway. Spring Boot and Jakarta EE are alternatives to reconsider if
the deployment model or team requirements change; they are not required
dependencies for this POC.

| Technology | Responsibility | Role in this plan |
| --- | --- | --- |
| Maven | Manage dependencies, compile, test, and package Java code | Use for backend builds and CI |
| Spring / Spring Boot | Provide application infrastructure; Boot simplifies configuration and startup | Consider for a standalone REST service deployed as a container, especially if the team already knows Spring |
| Jakarta EE (formerly Java EE) | Define enterprise Java APIs implemented by compatible runtimes | Consider when an existing enterprise runtime or team standard requires it |

Maven is a build tool, not an application framework. It can be used with
Spring Boot, Jakarta EE, or plain Java Lambda handlers; these are not three
mutually exclusive choices.

For the initial report storage API, keep handlers responsible for request and
response mapping, services responsible for report rules and ownership checks,
and repositories responsible for persistence. Use straightforward constructor
injection and test these layers independently. This separation does not require
a framework.

Before backend implementation:

1. Confirm the Lambda deployment approach and select supported Java and
   dependency versions; pin them in the build configuration.
2. Scaffold the Maven project and test the report service with an in-memory
   repository before integrating cloud storage.
3. Add authentication verification, AWS adapters, and integration tests.
4. Revisit Spring Boot only for a concrete benefit, such as an agreed move to
   a container-hosted API or substantial use of its application infrastructure.
   Revisit Jakarta EE if the hosting environment requires its standards.

If the framework or hosting choice changes, update infrastructure, deployment,
and testing plans together. Do not add multiple backend frameworks merely to
demonstrate technology breadth.

## Cognito authentication decision

Use Cognito Essentials and its Managed Login pages to keep authentication and
report infrastructure in AWS. This replaces the earlier Firebase proposal.
No Apple sign-in integration or Apple Developer Program membership is needed
for this authentication flow; app distribution requirements are separate.

### Configuration

- Create a dedicated Cognito User Pool in the backend's region.
- Enable Email/Password sign-in and disable self-service sign-up at the pool.
- Manually create one test user and explicitly approve their `sub` in backend
  configuration. Never automatically approve the first person who signs in.
- Create a public app client without a client secret.
- Use Authorization Code with PKCE (S256), a Cognito-provided domain, and
  explicitly registered callback and sign-out URLs.
- Define report API scopes for read and write access. Request only needed
  scopes, including `openid` for login identity.
- Do not create an Identity Pool: the app accesses reports through the API,
  rather than obtaining AWS credentials for direct database or bucket access.
- Do not enable Plus, SMS login, or machine-to-machine client credentials for
  this POC. Evaluate any future MFA requirement separately.

### App and backend flow

1. Start a system authentication session from macOS and open Managed Login.
2. Validate callback state and exchange the code using its PKCE verifier.
   Handle cancellation and the first-login temporary-password change flow.
3. Keep refresh credentials in Keychain; refresh access tokens when needed.
   Logout clears local credentials and ends the hosted login session.
4. Send the Cognito **access token**, not the ID token, as an HTTPS bearer token
   to the report API.
5. The authentication adapter validates the signature against the pool's keys,
   issuer, expiry, `token_use=access`, expected app client, and required scopes.
   Use a maintained JWT library and account for signing-key rotation.
6. Check the approved `sub` and construct `ReportService.Principal` from that
   verified subject. ReportService continues checking report ownership.

A gateway authorizer may perform token checks, but any trusted identity passed
on to Java must originate from verified authorizer context, never request-body
owner IDs or arbitrary headers. API scopes do not replace ownership checks.

The app exposes login and logout only. It does not implement registration,
password-reset UI, or role management; provider-hosted account flows may still
appear. Passwords stay with Cognito and are not sent to the report service.
Local editing, autosave, and recovery remain available without login.

### Cost assumptions

As checked on 2026-09-27, Cognito Essentials and Lite include 10,000 monthly
active users for direct or social sign-in per AWS account or organization.
One test user is expected to have zero MAU charges if that shared allowance
is available. This is a free usage allowance, not a hard spending cap.

AWS API, compute, storage, logs, and applicable email/SMS delivery have separate
pricing. Plus and machine-to-machine use do not share this direct-sign-in free
allowance. Configure budget notifications and recheck pricing before deployment.

### Implementation and validation

- Provision the User Pool, public app client, scopes, and domain through the
  infrastructure project. Record region, pool ID, client ID, issuer, callback,
  and logout URLs; do not create or embed an app client secret.
- Implement the Cognito token verifier and tests for invalid signature, wrong
  issuer/client/token type, expired tokens, insufficient scopes, and unapproved
  subjects before exposing report endpoints.
- Add macOS login, refresh, logout, and cancelled-login handling. Test the
  callback using the intended packaged app, not only an Xcode run.
- Verify owner isolation, token expiry, and report upload/download end to end.

Cognito foundation resources are deployed. The token verifier and app login
remain unimplemented; existing in-memory tests do not prove authenticated HTTP access.

References:
- [Cognito pricing](https://aws.amazon.com/cognito/pricing/)
- [Public app clients and PKCE](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-settings-client-apps.html)
- [User pool feature plans](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-sign-in-feature-plans.html)

## AWS foundation preparation

The [infrastructure project](../infrastructure/README.md) now defines Cognito
Essentials and report storage, with local template tests. These definitions
were deployed on 2026-09-27 as `prb-dev-foundation` in Sydney.
`prb-dev` remains read-only; `prb-deploy` uses PRBFoundationDeploy.
Confirmed callback/logout URIs and deployed IDs are recorded in
[dev outputs](../infrastructure/dev-outputs.json). The app still needs to implement
these callbacks.
No HTTP API, cloud authentication adapter, or image transfer is implemented yet.
