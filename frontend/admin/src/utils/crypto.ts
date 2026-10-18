import CryptoJS from 'crypto-js';

/**
 * 传输加密工具（从 go-wind-cms utils/crypto 拷回适配）：
 * 与登录同规的 AES-128-CBC（key = iv = VITE_AES_KEY，PKCS7，base64 输出）。
 * 后端登录以 NeedDecrypt 解密密码，前端必须密文传输。
 *
 * 与 cms 的差异：shortplay 后端当前固定 dev key「f51d66a73d8a0927」，
 * 未注入 VITE_AES_KEY 时回退到该 dev key（生产必须经环境变量覆盖）。
 */

/** 与后端约定的缺省 dev key（仅限本地开发；生产经 VITE_AES_KEY 注入） */
const FALLBACK_DEV_KEY = 'f51d66a73d8a0927';

function encryptData(data: string, key: string, iv: string): string {
  const keyUtf8 = CryptoJS.enc.Utf8.parse(key);
  const ivUtf8 = CryptoJS.enc.Utf8.parse(iv);
  const encrypted = CryptoJS.AES.encrypt(data, keyUtf8, {
    iv: ivUtf8,
    mode: CryptoJS.mode.CBC,
    padding: CryptoJS.pad.Pkcs7,
  });
  return encrypted.toString();
}

export function encryptPassword(password: string): string {
  const key = import.meta.env.VITE_AES_KEY || FALLBACK_DEV_KEY;
  if (!key) {
    throw new Error('VITE_AES_KEY is not set in environment');
  }
  return encryptData(password, key, key);
}
