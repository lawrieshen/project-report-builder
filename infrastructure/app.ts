import { AiComposeStack } from './ai-compose-stack';
import { ReportApiStack } from './report-api-stack';
import { App, BootstraplessSynthesizer } from 'aws-cdk-lib';
import { FoundationStack } from './foundation-stack';

const app = new App();
new FoundationStack(app, 'prb-dev-foundation', {
  synthesizer: new BootstraplessSynthesizer(),
  env: { account: '543123648742', region: 'ap-southeast-2' },
});

// Opt in so existing foundation-only deploys do not require API artifact inputs.
if (app.node.tryGetContext('includeReportApi') === 'true') {
  new ReportApiStack(app, 'prb-dev-report-api', {
    synthesizer: new BootstraplessSynthesizer(),
    env: { account: '543123648742', region: 'ap-southeast-2' },
  });
}

// AI deployment is independent of existing CRUD and foundation deployments.
if (app.node.tryGetContext('includeAiCompose') === 'true') {
  new AiComposeStack(app, 'prb-dev-ai-compose', {
    synthesizer: new BootstraplessSynthesizer(),
    env: { account: '543123648742', region: 'ap-southeast-2' },
  });
}
