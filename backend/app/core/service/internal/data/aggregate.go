package data

import (
	"context"

	"go-wind-shortplay/app/core/service/internal/data/ent"
)

// sumColumn 视频表单列求和。
//
// 本版本 ent 的 Selector.Scan 只接受切片参数（标量直接报
// "sql/scan: invalid type ... expected slice"），故统一走切片取首元素；
// SUM 结果为 NULL（无行匹配）时切片为空，按 0 兜底。
func sumColumn(ctx context.Context, q *ent.VideoQuery, field string) (int64, error) {
	var sums []int64
	if err := q.Aggregate(ent.Sum(field)).Scan(ctx, &sums); err != nil {
		return 0, err
	}
	if len(sums) == 0 {
		return 0, nil
	}
	return sums[0], nil
}
