package data

import (
	"testing"

	paginationV1 "github.com/tx7do/go-crud/api/gen/go/pagination/v1"
	"github.com/tx7do/go-utils/trans"

	"go-wind-shortplay/app/core/service/internal/data/ent"
	"go-wind-shortplay/app/core/service/internal/data/ent/video"
)

func pagingWithQuerySP(query string) *paginationV1.PagingRequest {
	return &paginationV1.PagingRequest{
		FilteringType: &paginationV1.PagingRequest_Query{Query: query},
	}
}

func TestSeriesAdminListFilter(t *testing.T) {
	r := &SeriesRepo{}

	if ps := r.adminListFilter(nil); len(ps) != 0 {
		t.Fatalf("nil req: expect 0 predicates, got %d", len(ps))
	}
	// 非 JSON query 原样忽略（BFF 已翻译，防御性）
	if ps := r.adminListFilter(pagingWithQuerySP("not-json")); len(ps) != 0 {
		t.Fatalf("non-json query: expect 0 predicates, got %d", len(ps))
	}
	// 标题模糊 + 作者
	ps := r.adminListFilter(pagingWithQuerySP(`{"title___icontains":"abc","author_id":7}`))
	if len(ps) != 2 {
		t.Fatalf("title+author: expect 2 predicates, got %d", len(ps))
	}
	// author_id=0 视为不过滤
	if ps = r.adminListFilter(pagingWithQuerySP(`{"author_id":0}`)); len(ps) != 0 {
		t.Fatalf("zero author: expect 0 predicates, got %d", len(ps))
	}
}

func TestPickEpisodeCovers(t *testing.T) {
	coverOf := func(s string) *string { return trans.Ptr(s) }

	cases := []struct {
		name    string
		videos  []*ent.Video
		wantAny map[uint32]string
		wantPub map[uint32]string
	}{
		{
			name:    "empty",
			videos:  nil,
			wantAny: map[uint32]string{},
			wantPub: map[uint32]string{},
		},
		{
			name: "published preferred over draft (later episode)",
			videos: []*ent.Video{
				{SeriesID: 1, EpisodeNumber: 1, Status: video.StatusDraft, CoverURL: coverOf("draft.jpg")},
				{SeriesID: 1, EpisodeNumber: 2, Status: video.StatusPublished, CoverURL: coverOf("pub.jpg")},
			},
			wantAny: map[uint32]string{1: "draft.jpg"},
			wantPub: map[uint32]string{1: "pub.jpg"},
		},
		{
			name: "first cover wins within same status (episode order)",
			videos: []*ent.Video{
				{SeriesID: 2, EpisodeNumber: 1, Status: video.StatusPublished, CoverURL: coverOf("ep1.jpg")},
				{SeriesID: 2, EpisodeNumber: 2, Status: video.StatusPublished, CoverURL: coverOf("ep2.jpg")},
			},
			wantAny: map[uint32]string{2: "ep1.jpg"},
			wantPub: map[uint32]string{2: "ep1.jpg"},
		},
		{
			name: "episodes without cover skipped",
			videos: []*ent.Video{
				{SeriesID: 3, EpisodeNumber: 1, Status: video.StatusPublished, CoverURL: nil},
				{SeriesID: 3, EpisodeNumber: 2, Status: video.StatusPublished, CoverURL: coverOf("")},
				{SeriesID: 3, EpisodeNumber: 3, Status: video.StatusPublished, CoverURL: coverOf("ep3.jpg")},
			},
			wantAny: map[uint32]string{3: "ep3.jpg"},
			wantPub: map[uint32]string{3: "ep3.jpg"},
		},
		{
			name: "multi series isolation",
			videos: []*ent.Video{
				{SeriesID: 4, EpisodeNumber: 1, Status: video.StatusPublished, CoverURL: coverOf("s4.jpg")},
				{SeriesID: 5, EpisodeNumber: 1, Status: video.StatusOffline, CoverURL: coverOf("s5.jpg")},
			},
			wantAny: map[uint32]string{4: "s4.jpg", 5: "s5.jpg"},
			wantPub: map[uint32]string{4: "s4.jpg"},
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			gotAny, gotPub := pickEpisodeCovers(tc.videos)
			if len(gotAny) != len(tc.wantAny) {
				t.Fatalf("firstAny: expect %d entries, got %d (%v)", len(tc.wantAny), len(gotAny), gotAny)
			}
			for sid, want := range tc.wantAny {
				if gotAny[sid] != want {
					t.Fatalf("firstAny[%d]: expect %q, got %q", sid, want, gotAny[sid])
				}
			}
			for sid, want := range tc.wantPub {
				if gotPub[sid] != want {
					t.Fatalf("firstPub[%d]: expect %q, got %q", sid, want, gotPub[sid])
				}
			}
		})
	}
}
