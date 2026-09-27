# Cloud Report Service

Store and retrieve project reports and images for signed-in users. Each account
has its own reports, and revision checks help prevent accidental overwrites.

This Java service handles report storage. AI drafting runs in the separate
[AI Report Composer](../ai-backend/README.md).

[API contract](contracts/openapi.json)
