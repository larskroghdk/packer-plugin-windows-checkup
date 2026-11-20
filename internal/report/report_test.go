package report

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/larskroghdk/packer-plugin-windows-checkup/internal/audit"
)

// TestSummaryAndEnforcement checks all statuses and excludes errors and inapplicable controls from the denominator.
//
// Author: Lars Krogh
// Version: 0.1.0
func TestSummaryAndEnforcement(t *testing.T) {
	r := &Report{StartedAt: time.Now()}
	for _, status := range []string{"Compliant", "NonCompliant", "NotConfigured", "NotApplicable", "Error"} {
		r.Findings = append(r.Findings, audit.Finding{ID: status, Status: status, Severity: "Medium", Category: "Test"})
	}
	r.Finish(time.Now())
	if r.Summary.Total != 5 || r.Summary.Evaluated != 3 || r.Summary.CompliancePercentage != 100.0/3 {
		t.Fatalf("%+v", r.Summary)
	}
	if r.Summary.ByCategory["Test"].Total != 5 || r.Summary.BySeverity["Medium"].Errors != 1 {
		t.Fatal(r.Summary)
	}
	for _, tc := range []struct {
		p    Policy
		fail bool
	}{
		{Policy{}, false}, {Policy{FailOnError: true}, true}, {Policy{FailOnNoncompliance: true, SeverityThreshold: "Low"}, true},
		{Policy{FailOnNoncompliance: true, SeverityThreshold: "High"}, false}, {Policy{MinimumPercentage: 50}, true},
	} {
		if err := Enforce(r, tc.p); (err != nil) != tc.fail {
			t.Fatalf("%+v: %v", tc, err)
		}
	}
	empty := &Report{}
	empty.Finish(time.Now())
	if Enforce(empty, Policy{MinimumPercentage: 1}) == nil {
		t.Fatal("empty audit passed threshold")
	}
}

// TestAtomicWrite validates nested paths, replacement, JSON integrity and temporary-file cleanup.
//
// Author: Lars Krogh
// Version: 0.1.0
func TestAtomicWrite(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "reports", "audit.json")
	r := &Report{SchemaVersion: "1.0", StartedAt: time.Now()}
	r.Finish(time.Now())
	for range 2 {
		if err := Write(path, r); err != nil {
			t.Fatal(err)
		}
	}
	data, err := os.ReadFile(path)
	if err != nil || !json.Valid(data) {
		t.Fatalf("%s %v", data, err)
	}
	entries, _ := os.ReadDir(filepath.Dir(path))
	if len(entries) != 1 {
		t.Fatal(entries)
	}
	if err := Write(filepath.Dir(path), r); err == nil {
		t.Fatal("replaced a directory")
	}
}
