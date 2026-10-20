package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	"go-wind-shortplay/app/core/service/internal/data"

	permissionV1 "go-wind-shortplay/api/gen/go/permission/service/v1"

	"go-wind-shortplay/pkg/constants"
	appViewer "go-wind-shortplay/pkg/entgo/viewer"
)

type MenuService struct {
	permissionV1.UnimplementedMenuServiceServer

	log *log.Helper

	menuRepo *data.MenuRepo
}

func NewMenuService(ctx *bootstrap.Context, menuRepo *data.MenuRepo) *MenuService {
	svc := &MenuService{
		log:      ctx.NewLoggerHelper("menu/service/core-service"),
		menuRepo: menuRepo,
	}

	svc.init()

	return svc
}

func (s *MenuService) init() {
	ctx := appViewer.NewSystemViewerContext(context.Background())
	if count, _ := s.menuRepo.Count(ctx, nil); count == 0 {
		_ = s.createDefaultMenus(ctx)
	}
	// 既有库升级补种：缺省菜单按 Id 幂等补齐。空表播种受 count 门控，
	// 老库感知不到新增条目（如剧集管理 76）；存在即跳过，已有行不动。
	_ = s.ensureDefaultMenus(ctx)
}

// ensureDefaultMenus 按 Id 幂等补种缺省菜单（不受 count 门控）。
func (s *MenuService) ensureDefaultMenus(ctx context.Context) error {
	for _, m := range constants.DefaultMenus {
		exist, err := s.menuRepo.Get(ctx, &permissionV1.GetMenuRequest{
			QueryBy: &permissionV1.GetMenuRequest_Id{Id: m.GetId()},
		})
		if err == nil && exist != nil && exist.GetId() > 0 {
			continue
		}
		if err := s.menuRepo.Create(ctx, &permissionV1.CreateMenuRequest{Data: m}); err != nil {
			s.log.Errorf("ensure default menu %s failed: %v", m.GetPath(), err)
			return err
		}
	}
	return nil
}

func (s *MenuService) List(ctx context.Context, req *paginationV1.PagingRequest) (*permissionV1.ListMenuResponse, error) {
	ret, err := s.menuRepo.List(ctx, req, false)
	if err != nil {

		return nil, err
	}

	return ret, nil
}

func (s *MenuService) Count(ctx context.Context, req *paginationV1.PagingRequest) (*permissionV1.CountMenuResponse, error) {
	count, err := s.menuRepo.Count(ctx, req)
	if err != nil {
		return nil, err
	}

	return &permissionV1.CountMenuResponse{
		Count: uint64(count),
	}, nil
}

func (s *MenuService) Get(ctx context.Context, req *permissionV1.GetMenuRequest) (*permissionV1.Menu, error) {
	ret, err := s.menuRepo.Get(ctx, req)
	if err != nil {

		return nil, err
	}

	return ret, nil
}

func (s *MenuService) Create(ctx context.Context, req *permissionV1.CreateMenuRequest) (*emptypb.Empty, error) {
	if req == nil || req.Data == nil {
		return nil, permissionV1.ErrorBadRequest("invalid parameter")
	}

	if err := s.menuRepo.Create(ctx, req); err != nil {
		return nil, err
	}

	return &emptypb.Empty{}, nil
}

func (s *MenuService) Update(ctx context.Context, req *permissionV1.UpdateMenuRequest) (*emptypb.Empty, error) {
	if req == nil || req.Data == nil {
		return nil, permissionV1.ErrorBadRequest("invalid parameter")
	}

	if err := s.menuRepo.Update(ctx, req); err != nil {
		return nil, err
	}

	return &emptypb.Empty{}, nil
}

func (s *MenuService) Delete(ctx context.Context, req *permissionV1.DeleteMenuRequest) (*emptypb.Empty, error) {
	if err := s.menuRepo.Delete(ctx, req); err != nil {
		return nil, err
	}
	return &emptypb.Empty{}, nil
}

func (s *MenuService) createDefaultMenus(ctx context.Context) error {
	for _, m := range constants.DefaultMenus {
		if err := s.menuRepo.Create(ctx, &permissionV1.CreateMenuRequest{Data: m}); err != nil {
			s.log.Errorf("create default menu err: %v", err)
			return err
		}
	}
	return nil
}
