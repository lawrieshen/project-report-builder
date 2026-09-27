// Issue report scopes only to the approved POC account and public app client.
exports.handler = async (event) => {
  if (event.version !== '2' ||
      event.callerContext?.clientId !== process.env.APP_CLIENT_ID ||
      event.request?.userAttributes?.sub !== process.env.APPROVED_SUBJECT) {
    throw new Error('This account or application is not approved for report access.');
  }
  event.response = {
    ...event.response,
    claimsAndScopeOverrideDetails: {
      accessTokenGeneration: {
        scopesToAdd: ['reports/read', 'reports/write'],
      },
    },
  };
  return event;
};
