-- 一次性迁移：Phase 2 种子/冒烟遗留的业务行 tenant_id 0 → 1（shortplay 租户）
--
-- 背景：业务行（视频/互动/评论/关注/举报/埋点/上传任务）创建路径在平台/系统
-- 上下文下未归属租户，落成 tenant_id=0；C 端租户用户（shortplay, tid=1）经
-- 基座 TenantPrivacy 按 tenant_id 过滤后"看得到点不了"。
-- 配套代码修复：core 数据层 businessTenantID() 为无租户上下文的业务创建
-- 缺省归属 shortplay 租户（本文件只修存量，代码修增量）。
--
-- 说明：
--   * sys_users 保持不动（用户归属由注册/管理路径各自决定）；
--   * sp_sys_configs 无 tenant_id 列（单行配置表，未挂 TenantID mixin），无需迁移；
--   * sp_video_tags / sp_video_tag_rels 为共享内容分类，不在本次范围；
--   * 可重复执行（幂等：只搬 tenant_id=0 的行）。
--   * 目标租户按 code 定位，避免环境间租户 ID 漂移。

-- 目标租户必须存在且启用
DO $$
DECLARE
    tid integer;
BEGIN
    SELECT id INTO tid FROM sys_tenants WHERE code = 'shortplay' AND status = 'ON';
    IF tid IS NULL THEN
        RAISE EXCEPTION 'default tenant "shortplay" not found or not ON';
    END IF;

    UPDATE sp_videos        SET tenant_id = tid WHERE tenant_id = 0;
    UPDATE sp_video_likes   SET tenant_id = tid WHERE tenant_id = 0;
    UPDATE sp_video_collects SET tenant_id = tid WHERE tenant_id = 0;
    UPDATE sp_user_follows  SET tenant_id = tid WHERE tenant_id = 0;
    UPDATE sp_video_comments SET tenant_id = tid WHERE tenant_id = 0;
    UPDATE sp_video_reports SET tenant_id = tid WHERE tenant_id = 0;
    UPDATE sp_uba_events    SET tenant_id = tid WHERE tenant_id = 0;
    UPDATE sp_upload_tasks  SET tenant_id = tid WHERE tenant_id = 0;
    UPDATE sp_video_drafts  SET tenant_id = tid WHERE tenant_id = 0;

    RAISE NOTICE 'business rows backfilled to tenant %', tid;
END $$;
