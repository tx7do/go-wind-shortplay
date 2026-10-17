/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** 后端网关地址，如 http://127.0.0.1:6600；开发态可填 /api 走 Vite 代理 */
  readonly VITE_API_BASE?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
