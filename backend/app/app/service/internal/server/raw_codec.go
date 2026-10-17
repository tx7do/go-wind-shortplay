package server

import (
	"fmt"

	"github.com/go-kratos/kratos/v2/encoding"
)

// rawCodec 支持 application/octet-stream 原始二进制 body。
//
// 仅用于 bytes 字段直传（视频分片上传 UploadChunk 的 body:"data"）：
// 请求体原样落到 []byte 字段，不做任何序列化协议包装；
// 响应仍走 JSON 编码器（本编解码器只注册给请求方向使用）。
type rawCodec struct{}

func (rawCodec) Marshal(v interface{}) ([]byte, error) {
	switch data := v.(type) {
	case []byte:
		return data, nil
	case *[]byte:
		return *data, nil
	default:
		return nil, fmt.Errorf("raw codec only supports []byte body")
	}
}

func (rawCodec) Unmarshal(data []byte, v interface{}) error {
	switch b := v.(type) {
	case *[]byte:
		*b = data
		return nil
	default:
		return fmt.Errorf("raw codec only supports []byte target")
	}
}

func (rawCodec) Name() string { return "octet-stream" }

func init() {
	encoding.RegisterCodec(rawCodec{})
}
