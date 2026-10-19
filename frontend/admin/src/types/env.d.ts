/// <reference types="vite/client" />

interface ImportMetaEnv {
    readonly VITE_API_URL: string

    /** 管理端 SSE 端点（后端 server.sse，默认 http://localhost:7601/events） */
    readonly VITE_SSE_URL: string

    /** 媒体（MinIO）公开基地址（<host>/<桶>）：对象键字段（videoUrl）的拼址前缀，须与后端 OSS_DOWNLOAD_HOST + OSS_BUCKET 一致；缺省 http://127.0.0.1:9000/shortplay */
    readonly VITE_MEDIA_BASE_URL: string

    readonly VITE_APP_TITLE: string
    readonly VITE_APP_NAMESPACE: string
    readonly VITE_APP_VERSION: string

    readonly VITE_ENV: string

    readonly VITE_ANALYZE: boolean

    /** 登录密码传输加密密钥（AES key=iv，须与后端 AES_KEY 一致；未设置时回退基座 dev 缺省，仅限本地） */
    readonly VITE_AES_KEY: string
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
