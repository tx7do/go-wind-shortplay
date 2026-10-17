package data

import (
	"os"

	kratosGrpc "github.com/go-kratos/kratos/v2/transport/grpc"
	"google.golang.org/grpc"

	"github.com/tx7do/kratos-bootstrap/bootstrap"

	feedV1 "go-wind-shortplay/api/gen/go/feed/service/v1"
	identityV1 "go-wind-shortplay/api/gen/go/identity/service/v1"
	interactionV1 "go-wind-shortplay/api/gen/go/interaction/service/v1"
	notifyV1 "go-wind-shortplay/api/gen/go/notify/service/v1"
	reportV1 "go-wind-shortplay/api/gen/go/report/service/v1"
	statsV1 "go-wind-shortplay/api/gen/go/stats/service/v1"
	ubaV1 "go-wind-shortplay/api/gen/go/uba/service/v1"
	videoV1 "go-wind-shortplay/api/gen/go/video/service/v1"
	"go-wind-shortplay/pkg/middleware/auth"
)

// CoreServiceAddr core 服务直连地址（dev 免注册中心；生产可切 etcd 发现）
func CoreServiceAddr() string {
	if addr := os.Getenv("CORE_SERVICE_ADDR"); addr != "" {
		return addr
	}
	return "127.0.0.1:6900"
}

// NewCoreConn 创建到 core 的 gRPC 连接（附带身份与调用面透传中间件）
func NewCoreConn(ctx *bootstrap.Context) (grpc.ClientConnInterface, func(), error) {
	conn, err := kratosGrpc.DialInsecure(
		ctx.Context(),
		kratosGrpc.WithEndpoint(CoreServiceAddr()),
		kratosGrpc.WithMiddleware(auth.NewClientMiddlewareFor("app")),
	)
	if err != nil {
		return nil, func() {}, err
	}
	return conn, func() { _ = conn.Close() }, nil
}

func NewAuthenticationServiceClient(conn grpc.ClientConnInterface) identityV1.AuthenticationServiceClient {
	return identityV1.NewAuthenticationServiceClient(conn)
}

func NewUserServiceClient(conn grpc.ClientConnInterface) identityV1.UserServiceClient {
	return identityV1.NewUserServiceClient(conn)
}

func NewVideoServiceClient(conn grpc.ClientConnInterface) videoV1.VideoServiceClient {
	return videoV1.NewVideoServiceClient(conn)
}

func NewFeedServiceClient(conn grpc.ClientConnInterface) feedV1.FeedServiceClient {
	return feedV1.NewFeedServiceClient(conn)
}

func NewInteractionServiceClient(conn grpc.ClientConnInterface) interactionV1.InteractionServiceClient {
	return interactionV1.NewInteractionServiceClient(conn)
}

func NewCommentServiceClient(conn grpc.ClientConnInterface) interactionV1.CommentServiceClient {
	return interactionV1.NewCommentServiceClient(conn)
}

func NewNotifyServiceClient(conn grpc.ClientConnInterface) notifyV1.NotifyServiceClient {
	return notifyV1.NewNotifyServiceClient(conn)
}

func NewReportServiceClient(conn grpc.ClientConnInterface) reportV1.ReportServiceClient {
	return reportV1.NewReportServiceClient(conn)
}

func NewUbaServiceClient(conn grpc.ClientConnInterface) ubaV1.UbaServiceClient {
	return ubaV1.NewUbaServiceClient(conn)
}

func NewDashboardServiceClient(conn grpc.ClientConnInterface) statsV1.DashboardServiceClient {
	return statsV1.NewDashboardServiceClient(conn)
}
