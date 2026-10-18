package service

import (
	"context"

	"github.com/go-kratos/kratos/v2/log"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"google.golang.org/protobuf/types/known/emptypb"

	mediaV1 "go-wind-shortplay/api/gen/go/media/service/v1"

	"go-wind-shortplay/app/core/service/internal/data"
)

type MediaAssetService struct {
	mediaV1.UnimplementedMediaAssetServiceServer

	mediaAssetRepo *data.MediaAssetRepo
	log            *log.Helper
}

func NewMediaAssetService(ctx *bootstrap.Context, uc *data.MediaAssetRepo) *MediaAssetService {
	return &MediaAssetService{
		log:            ctx.NewLoggerHelper("media-asset/service/core-service"),
		mediaAssetRepo: uc,
	}
}

// ListDuplicatedMediaAssets 重复资源分组（同租户内同内容哈希 >1 条）。
func (s *MediaAssetService) ListDuplicatedMediaAssets(ctx context.Context, req *mediaV1.ListDuplicatedMediaAssetsRequest) (*mediaV1.ListDuplicatedMediaAssetsResponse, error) {
	groups, err := s.mediaAssetRepo.ListDuplicatedGroups(ctx, int(req.GetLimit()))
	if err != nil {
		return nil, err
	}
	return &mediaV1.ListDuplicatedMediaAssetsResponse{
		Groups: groups,
		Total:  uint64(len(groups)),
	}, nil
}

func (s *MediaAssetService) List(ctx context.Context, req *paginationV1.PagingRequest) (*mediaV1.ListMediaAssetResponse, error) {
	return s.mediaAssetRepo.List(ctx, req)
}

func (s *MediaAssetService) Get(ctx context.Context, req *mediaV1.GetMediaAssetRequest) (*mediaV1.MediaAsset, error) {
	return s.mediaAssetRepo.Get(ctx, req)
}

// FindByHash 按内容哈希查重。
func (s *MediaAssetService) FindByHash(ctx context.Context, req *mediaV1.FindMediaAssetByHashRequest) (*mediaV1.FindMediaAssetByHashResponse, error) {
	if req == nil || req.GetFileHash() == "" {
		return nil, mediaV1.ErrorBadRequest("invalid parameter")
	}
	asset, err := s.mediaAssetRepo.FindByHash(ctx, req.GetFileHash())
	if err != nil {
		return nil, err
	}
	return &mediaV1.FindMediaAssetByHashResponse{Asset: asset}, nil
}

func (s *MediaAssetService) Create(ctx context.Context, req *mediaV1.CreateMediaAssetRequest) (*mediaV1.MediaAsset, error) {
	return s.mediaAssetRepo.Create(ctx, req)
}

func (s *MediaAssetService) Update(ctx context.Context, req *mediaV1.UpdateMediaAssetRequest) (*mediaV1.MediaAsset, error) {
	return s.mediaAssetRepo.Update(ctx, req)
}

func (s *MediaAssetService) Delete(ctx context.Context, req *mediaV1.DeleteMediaAssetRequest) (*emptypb.Empty, error) {
	_, err := s.mediaAssetRepo.Delete(ctx, req)
	if err != nil {
		return nil, err
	}
	return &emptypb.Empty{}, nil
}
