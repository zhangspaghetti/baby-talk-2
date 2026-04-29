import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

const currentDir = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, currentDir, '');
  const adminApiTarget = env.VITE_ADMIN_API_PROXY_TARGET || 'http://127.0.0.1:8090';

  return {
    root: currentDir,
    plugins: [react()],
    build: {
      rollupOptions: {
        output: {
          manualChunks(id) {
            if (id.includes('@ant-design/pro-components') || id.includes('@ant-design/pro-utils') || id.includes('@ant-design/pro-provider')) {
              return 'vendor-pro-components';
            }
            if (id.includes('node_modules/@ant-design') || id.includes('node_modules/antd') || id.includes('node_modules/rc-')) {
              return 'vendor-antd';
            }
          },
        },
      },
    },
    server: {
      host: '0.0.0.0',
      port: 3000,
      strictPort: true,
      proxy: {
        '/api': {
          target: adminApiTarget,
          changeOrigin: true,
        },
      },
    },
    preview: {
      host: '0.0.0.0',
      port: 3000,
      strictPort: true,
    },
  };
});
