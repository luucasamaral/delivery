import { defineConfig } from "vitest/config";
import { fileURLToPath } from "node:url";
export default defineConfig({
  resolve: { alias: { "@restaurant/types": fileURLToPath(new URL("./packages/types/src/index.ts", import.meta.url)) } },
  esbuild: { jsx: "automatic" },
  test: {
    include: ["apps/api/src/**/*.test.ts", "packages/ui/src/**/*.test.tsx"],
    exclude: ["**/node_modules/**", "**/*.integration.test.ts"],
  },
});
