package data

import (
	"strings"

	fieldmaskpb "google.golang.org/genproto/protobuf/field_mask"
)

// FilterViewMask 从 FieldMask 中剔除 excludeFields 列出的字段；
// 剔除后为空时返回 nil（等价"不限定字段"由调用方决定语义）。
func FilterViewMask(excludeFields []string, mask *fieldmaskpb.FieldMask) *fieldmaskpb.FieldMask {
	if mask == nil {
		return nil
	}
	if len(excludeFields) == 0 {
		return mask
	}

	excludeMap := make(map[string]struct{})
	for _, field := range excludeFields {
		excludeMap[field] = struct{}{}
	}

	var paths []string
	for _, path := range mask.Paths {
		path = strings.TrimSpace(path)
		if _, exist := excludeMap[path]; !exist {
			paths = append(paths, path)
		}
	}

	if len(paths) == 0 {
		return nil
	}

	return &fieldmaskpb.FieldMask{Paths: paths}
}
