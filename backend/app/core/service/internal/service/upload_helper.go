package service

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/google/uuid"

	passCrypto "github.com/tx7do/go-utils/password"
)

// hashPassword 密码哈希（argon2，与登录校验共用算法）
func hashPassword(plain string) (string, error) {
	crypto, err := passCrypto.CreateCrypto("argon2")
	if err != nil {
		return "", err
	}
	return crypto.Encrypt(plain)
}

// videoExtOf 取文件扩展名（小写、带点）
func videoExtOf(fileName string) string {
	idx := strings.LastIndex(fileName, ".")
	if idx < 0 {
		return ""
	}
	return strings.ToLower(fileName[idx:])
}

// newTaskID 生成上传任务号
func newTaskID() string {
	return uuid.NewString()
}

// chunkTempDir 分片暂存目录：{root}/{taskID}/
func chunkTempDir(root, taskID string) string {
	return filepath.Join(root, taskID)
}

// chunkFilePath 单个分片文件路径
func chunkFilePath(root, taskID string, chunkIndex uint32) string {
	return filepath.Join(chunkTempDir(root, taskID), fmt.Sprintf("%06d.part", chunkIndex))
}

// mergeChunks 顺序合并分片到目标文件
func mergeChunks(root, taskID, targetPath string, totalChunks uint32) error {
	if err := os.MkdirAll(filepath.Dir(targetPath), 0o755); err != nil {
		return err
	}
	target, err := os.OpenFile(targetPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
	if err != nil {
		return err
	}
	defer target.Close()

	for i := uint32(0); i < totalChunks; i++ {
		part, err := os.Open(chunkFilePath(root, taskID, i))
		if err != nil {
			return fmt.Errorf("chunk %d missing: %w", i, err)
		}
		if _, err := target.ReadFrom(part); err != nil {
			part.Close()
			return err
		}
		part.Close()
	}
	return nil
}

// extractCoverLocal 用 FFmpeg 从本地视频抽单帧封面，返回本地 jpg 路径。
//
// 开源版策略：FFmpeg 不可用或失败时返回空串（无封面），不阻塞发布；
// 商业增值包在此挂接多码率转码 / 多尺寸封面流水线。
func extractCoverLocal(videoPath, workDir string) string {
	ffmpegPath, lookErr := exec.LookPath("ffmpeg")
	if lookErr != nil {
		return "" // 未安装 FFmpeg：静默降级
	}
	coverPath := filepath.Join(workDir, "cover.jpg")
	// -ss 1 从第 1 秒抽帧（不足 1 秒的视频 ffmpeg 自动取首帧）
	cmd := exec.Command(ffmpegPath, "-y", "-ss", "1", "-i", videoPath,
		"-frames:v", "1", "-vf", "scale=720:-2", coverPath)
	if _, execErr := cmd.CombinedOutput(); execErr != nil {
		_ = execErr
		return ""
	}
	return coverPath
}

// allowedVideoExt 校验扩展名是否允许
func allowedVideoExt(ext string, allowed []string) bool {
	if len(allowed) == 0 {
		return true
	}
	for _, a := range allowed {
		if strings.EqualFold(a, ext) {
			return true
		}
	}
	return false
}
