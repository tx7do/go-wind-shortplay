package service

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/go-kratos/kratos/v2/log"
	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/kratos-bootstrap/bootstrap"
	"github.com/tx7do/go-utils/trans"

	permissionV1 "go-wind-shortplay/api/gen/go/permission/service/v1"

	"go-wind-shortplay/pkg/middleware/auth"
)

// NavigationNode 动态菜单节点（docs/API.md「Admin 端 RBAC 扩展」形状）。
type NavigationNode struct {
	ID        uint32            `json:"id,omitempty"`
	ParentID  *uint32           `json:"parentId,omitempty"`
	Name      string            `json:"name,omitempty"`
	Path      string            `json:"path,omitempty"`
	Component string            `json:"component,omitempty"`
	Icon      string            `json:"icon,omitempty"`
	Sort      int32             `json:"sort,omitempty"`
	Type      string            `json:"type,omitempty"`
	Visible   *bool             `json:"visible,omitempty"`
	Children  []*NavigationNode `json:"children,omitempty"`
}

// resolvableComponents React admin pageMap 可解析的 component 标识
// （前端 router/index.tsx pageMap + 别名键；基座 33 条菜单多为 Vue 底座组件路径，
// 本前端无对应页面，导航下发时过滤，避免死路由）。
var resolvableComponents = map[string]bool{
	"dashboard":              true,
	"videos":                 true,
	"series":                 true,
	"comments":               true,
	"reports":                true,
	"users":                  true,
	"sysconf":                true,
	"permission/roles":       true,
	"permission/menus":       true,
	"permission/apis":        true,
	"permission/departments": true,
	"permission/groups":      true,
}

// NavigationService 动态菜单服务（admin BFF）：读基座菜单域，映射为前端
// navigation 节点树；按钮类型与不可解析组件的节点不下发。
type NavigationService struct {
	log *log.Helper

	menuServiceClient permissionV1.MenuServiceClient
	accessTokenChecker auth.AccessTokenChecker
}

func NewNavigationService(
	ctx *bootstrap.Context,
	menuServiceClient permissionV1.MenuServiceClient,
	accessTokenChecker auth.AccessTokenChecker,
) *NavigationService {
	return &NavigationService{
		log:                ctx.NewLoggerHelper("navigation/service/admin-service"),
		menuServiceClient:  menuServiceClient,
		accessTokenChecker: accessTokenChecker,
	}
}

// ServeNavigation GET /admin/v1/navigation（手工路由：响应为自定义 JSON 形状）。
func (s *NavigationService) ServeNavigation(w http.ResponseWriter, r *http.Request) {
	if s.accessTokenChecker != nil {
		token, err := bearerTokenOf(r)
		if err != nil {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		if valid, _ := s.accessTokenChecker.IsValidAccessToken(r.Context(), token, false); !valid {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
	}

	menus, err := s.menuServiceClient.List(r.Context(), &paginationV1.PagingRequest{NoPaging: trans.Ptr(true)})
	if err != nil {
		s.log.Errorf("navigation: list menus failed: %s", err.Error())
		http.Error(w, "list menus failed", http.StatusInternalServerError)
		return
	}

	nodes := mapMenusToNodes(menus.GetItems())
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{"items": nodes})
}

// mapMenusToNodes 基座菜单 → navigation 节点树（过滤不可解析/按钮节点）。
// 目录节点（CATALOG / BasicLayout）必须放行：它们是树的父级，若被白名单过滤，
// 子节点会因父级缺失全部平铺为根节点（侧栏被打平的直接根因）；
// 目录是否下发自底向上由 keep 决定（无可解析子节点的目录整组裁剪）。
func mapMenusToNodes(menus []*permissionV1.Menu) []*NavigationNode {
	byID := make(map[uint32]*NavigationNode, len(menus))
	var roots []*NavigationNode

	for _, m := range menus {
		if m == nil || m.GetMeta().GetHideInMenu() {
			continue
		}
		component := strings.Trim(m.GetComponent(), "/")
		if m.GetType() == permissionV1.Menu_BUTTON {
			continue
		}
		isCatalog := m.GetType() == permissionV1.Menu_CATALOG || component == "BasicLayout"
		if component != "" && !isCatalog && !resolvableComponents[component] {
			continue
		}
		// 目录节点不下发 component：布局由前端统一合成，BasicLayout 形态的
		// component 若下发会被当作可解析叶子（childless 目录误下发）或双层布局
		nodeComponent := component
		if isCatalog {
			nodeComponent = ""
		}
		node := &NavigationNode{
			ID:        m.GetId(),
			ParentID:  m.ParentId,
			Name:      m.GetMeta().GetTitle(),
			Path:      m.GetPath(),
			Component: nodeComponent,
			Icon:      m.GetMeta().GetIcon(),
			Sort:      m.GetMeta().GetOrder(),
			Type:      m.GetType().String(),
			Visible:   trans.Ptr(true),
		}
		byID[m.GetId()] = node
	}

	for _, m := range menus {
		node, ok := byID[m.GetId()]
		if !ok {
			continue
		}
		if parentID := m.GetParentId(); parentID > 0 {
			if parent, ok := byID[parentID]; ok {
				parent.Children = append(parent.Children, node)
				continue
			}
		}
		roots = append(roots, node)
	}

	// 自底向上裁剪：目录节点无可解析子节点则整组不下发（本前端无对应页面）；
	// 页面节点（component 可解析）恒保留
	out := make([]*NavigationNode, 0, len(roots))
	var keep func(n *NavigationNode) bool
	keep = func(n *NavigationNode) bool {
		children := make([]*NavigationNode, 0, len(n.Children))
		for _, c := range n.Children {
			if keep(c) {
				children = append(children, c)
			}
		}
		n.Children = children
		if n.Type == permissionV1.Menu_CATALOG.String() {
			return len(children) > 0
		}
		return n.Component != "" || len(children) > 0
	}
	for _, r := range roots {
		if keep(r) {
			out = append(out, r)
		}
	}
	return out
}

func bearerTokenOf(r *http.Request) (string, error) {
	h := r.Header.Get("Authorization")
	if h == "" {
		return "", errNoBearer
	}
	const prefix = "Bearer "
	if !strings.HasPrefix(h, prefix) {
		return "", errNoBearer
	}
	return strings.TrimSpace(h[len(prefix):]), nil
}

type spErrString string

func (e spErrString) Error() string { return string(e) }

const errNoBearer = spErrString("missing bearer token")
