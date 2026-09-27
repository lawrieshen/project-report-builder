import { App, BootstraplessSynthesizer } from 'aws-cdk-lib';
import { FoundationStack } from './foundation-stack';

const app = new App();
new FoundationStack(app, 'prb-dev-foundation', {
  synthesizer: new BootstraplessSynthesizer(),
  env: { account: '543123648742', region: 'ap-southeast-2' },
});
