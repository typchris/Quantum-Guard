# Cloudflare source synchronization required

The Worker source in this folder is **not** the authoritative source currently deployed to the Quantum Guard staging Worker.

The Cloudflare-enabled Work/Codex session already updated the live staging Worker to preserve private report routes, remove obsolete temporary upload routes, redact query strings, and serve the signed R2 updater flow. Those deployed changes have not yet been copied back into this Git branch.

The GitHub deployment workflow intentionally fails while this file exists.

Remove this file only in the same commit that replaces this folder with the exact reviewed source/configuration from the deployed staging Worker and after local Worker tests pass.

Do not deploy the older GitHub-proxy Worker over the live staging Worker.
