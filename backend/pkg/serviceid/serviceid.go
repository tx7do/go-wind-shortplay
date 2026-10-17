package serviceid

const (
	ProjectName = "gowind-shortplay"
)

// 服务名（服务发现 / 日志标识）
const (
	AdminService = "admin-service" // 后台网关 BFF（React admin 走这里）
	AppService   = "app-service"   // 前台网关 BFF（Flutter 走这里）
	CoreService  = "core-service"  // 核心服务（唯一数据落点）
)

// NewDiscoveryName 构建服务发现名称
func NewDiscoveryName(serviceName string) string {
	return ProjectName + "/" + serviceName
}

// MakeDiscoveryAddress 构建服务发现地址
func MakeDiscoveryAddress(serviceName string) string {
	return "discovery:///" + serviceName
}
