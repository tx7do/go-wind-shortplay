import { fileURLToPath, URL } from 'node:url';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    port: 5173,
    // 后端网关未开启 CORS，开发态通过 Vite 代理转发到 :6600，避免跨域问题
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:6600',
        changeOrigin: true,
        rewrite: (pathname) => pathname.replace(/^\/api/, ''),
      },
    },
  },
});
