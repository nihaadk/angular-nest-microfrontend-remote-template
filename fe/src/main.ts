import { initFederation } from '@angular-architects/native-federation';
import { loadRuntimeEnv } from './app/core/runtime-env';

// Resolve where this remote's own backend lives (see runtime-env.ts /
// env.json) before bootstrapping, so services like ExampleService can use
// it - same mechanism the shell host uses for the same reason.
loadRuntimeEnv()
  .then((env) => {
    window.__env__ = env;
    return initFederation(
      {},
      {
        hostRemoteEntry: { url: './remoteEntry.json' },
      },
    );
  })
  .catch((err) => console.error(err))
  .then((_) => import('./bootstrap'))
  .catch((err) => console.error(err));
