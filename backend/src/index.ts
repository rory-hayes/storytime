import { createApp } from "./app.js";
import { loadEnv } from "./lib/env.js";
import { logger } from "./lib/logger.js";

const env = loadEnv();
const app = createApp({ env });

app.listen(env.PORT, () => {
  logger.info({ port: env.PORT }, "StoryTime backend listening");
});
