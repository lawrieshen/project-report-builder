const { test } = require('node:test');
const assert = require('node:assert/strict');
const { handler } = require('./native-auth-trigger');
process.env.APP_CLIENT_ID = 'mac-client';
process.env.APPROVED_SUBJECT = 'approved-user';
const event = () => ({ version: '2', callerContext: { clientId: 'mac-client' },
  request: { userAttributes: { sub: 'approved-user' } }, response: {} });
test('approved sign-in and refresh receive report scopes', async () => {
  for (const source of ['TokenGeneration_Authentication', 'TokenGeneration_RefreshTokens']) {
    const result = await handler({ ...event(), triggerSource: source });
    assert.deepEqual(result.response.claimsAndScopeOverrideDetails.accessTokenGeneration.scopesToAdd,
      ['reports/read', 'reports/write']);
  }
});
test('other accounts, clients and event versions are rejected', async () => {
  const otherUser = event(); otherUser.request.userAttributes.sub = 'other';
  const otherClient = event(); otherClient.callerContext.clientId = 'other';
  for (const request of [otherUser, otherClient, { ...event(), version: '1' }]) {
    await assert.rejects(handler(request));
  }
});
