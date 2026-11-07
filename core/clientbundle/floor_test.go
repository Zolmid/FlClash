package clientbundle

import (
	"path/filepath"
	"testing"
)

func TestReplayFloorPersistsTombstoneAndRejectsEquivocation(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state", "floor.json")
	floor := ReplayFloor{Serial: 7, Digest: "revoke", Revoked: true}
	if err := SaveReplayFloor(path, floor); err != nil {
		t.Fatal(err)
	}
	loaded, err := LoadReplayFloor(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := loaded.Accept(7, "late-bundle", false); err == nil {
		t.Fatal("same serial equivocation accepted")
	}
	if err := loaded.Accept(6, "old", false); err == nil {
		t.Fatal("old bundle accepted")
	}
	if err := loaded.Accept(8, "next", false); err != nil {
		t.Fatal(err)
	}
}
