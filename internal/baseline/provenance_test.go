package baseline

import (
	"encoding/json"
	"os"
	"testing"
)

// TestSnapshotFingerprint detects unreviewed baseline drift from the source snapshot.
//
// Author: Lars Krogh
// Version: 0.1.0
func TestSnapshotFingerprint(t *testing.T) {
	data, err := os.ReadFile("data-manifest.json")
	if err != nil {
		t.Fatal(err)
	}
	var manifest struct {
		SourceCommit string            `json:"sourceCommit"`
		Files        map[string]string `json:"files"`
	}
	if err = json.Unmarshal(data, &manifest); err != nil {
		t.Fatal(err)
	}
	c, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if manifest.SourceCommit != SourceCommit || len(manifest.Files) != len(c.Baselines()) {
		t.Fatal("snapshot metadata mismatch")
	}
	for _, b := range c.Baselines() {
		got, err := Fingerprint(b.ID)
		if err != nil || got != manifest.Files[b.ID+".json"] {
			t.Fatalf("%s: %s %v", b.ID, got, err)
		}
	}
}
