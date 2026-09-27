# Cloud storage plan (not implemented)

[Back to README](../README.md)


The proposed cloud storage POC will use an existing identity service with
one pre-provisioned test user. Sign in with Apple is the planned identity provider;
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
