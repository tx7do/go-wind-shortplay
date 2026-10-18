/// <reference types="vite/client" />

interface ImportMetaEnv {
    readonly VITE_API_URL: string

    /** 管理端 SSE 端点（后端 server.sse，默认 http://localhost:7601/events） */
    readonly VITE_SSE_URL: string

    readonly VITE_APP_TITLE: string
    readonly VITE_APP_NAMESPACE: string
    readonly VITE_APP_VERSION: string

    readonly VITE_ENV: string

    readonly VITE_ANALYZE: boolean
}

interface ImportMeta {
    readonly env: ImportMetaEnv
}

// React Router handle 类型增强
declare module 'react-router' {
    interface RouteMatch {
        handle: RouteHandle;
    }
}
