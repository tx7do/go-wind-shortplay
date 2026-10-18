// Package configenv 为 kratos-bootstrap 的配置装载接通环境变量覆盖链路。
//
// 背景：kratos-bootstrap 仅注册 file source 加载 configs/*.yaml，yaml 中的
// `${VAR:default}` 占位符按「配置内键优先、缺省值兜底」解析——进程环境变量
// 根本不参与解析，`.env` / docker-compose 注入的 DB_PASSWORD 等变量实际不生效。
//
// 本包利用 kratos-bootstrap 预留的远程配置源工厂扩展点（RegisterFactory），
// 注册一个名为 "env" 的配置源：kratos 的 env source 把进程环境变量以顶层键
// 并入配置表，使 `${VAR:default}` 按「环境变量优先、缺省值兜底」解析。
// 各服务在其 configs/config.yaml 中声明 `config: { type: env }` 启用。
//
// 另提供 OverrideAESKeyFromEnv：基座的登录密码传输加密（AES-CBC，key=iv）
// 代码路径直接引用 tx7do/go-utils 的包级变量 crypto.DefaultAESKey（公开的
// dev 缺省值），配置文件中的 authenticator.aes_key 并不参与解密；此处提供
// AES_KEY 环境变量统一覆盖入口，前后端需同步更换（前端 VITE_AES_KEY）。
package configenv

import (
	"fmt"
	"os"

	"github.com/go-kratos/kratos/v2/config"
	kenv "github.com/go-kratos/kratos/v2/config/env"
	txcrypto "github.com/tx7do/go-utils/crypto"
	conf "github.com/tx7do/kratos-bootstrap/api/gen/go/conf/v1"
	bconfig "github.com/tx7do/kratos-bootstrap/config"
)

// envSourceName 是注册到 kratos-bootstrap 的配置源工厂名，
// 与各服务 configs/config.yaml 中 config.type 对应。
const envSourceName bconfig.Type = "env"

func init() {
	bconfig.MustRegisterFactory(envSourceName, func(_ *conf.RemoteConfig) (config.Source, error) {
		return kenv.NewSource(), nil
	})
}

// OverrideAESKeyFromEnv 用 AES_KEY 环境变量覆盖基座 crypto.DefaultAESKey。
// 未设置时保持基座 dev 缺省（仅限本地开发）；长度必须为 16/24/32 字节。
func OverrideAESKeyFromEnv() error {
	k := os.Getenv("AES_KEY")
	if k == "" {
		return nil
	}
	if l := len(k); l != 16 && l != 24 && l != 32 {
		return fmt.Errorf("configenv: AES_KEY 长度必须为 16/24/32 字节（AES-%d），当前 %d", l*8, l)
	}
	txcrypto.DefaultAESKey = []byte(k)
	return nil
}
