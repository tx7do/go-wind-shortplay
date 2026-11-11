package data

// i64↔u64/u32 边界 helper（int64 定版：proto uint32/uint64 计数字段与 ent 列混用）。

func i64FromU64v(v uint64) *int64 {
	x := int64(v)
	return &x
}

func u64Val(v int64) *uint64 {
	x := uint64(v)
	return &x
}

func u64pI64(v *int64) *uint64 {
	if v == nil {
		return nil
	}
	x := uint64(*v)
	return &x
}

func derefU32v(v *uint32) uint32 {
	if v == nil {
		return 0
	}
	return *v
}
