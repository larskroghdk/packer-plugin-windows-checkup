// Package report creates atomic host reports and evaluates compliance requirements.
package report

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/larskroghdk/packer-plugin-windows-checkup/internal/audit"
	"github.com/larskroghdk/packer-plugin-windows-checkup/internal/facts"
)

// Counts contains mutually exclusive finding totals.
type Counts struct {
	Total         int `json:"total"`
	Compliant     int `json:"compliant"`
	NonCompliant  int `json:"nonCompliant"`
	NotApplicable int `json:"notApplicable"`
	NotConfigured int `json:"notConfigured"`
	Errors        int `json:"errors"`
}

// Summary includes totals, successfully evaluated compliance, and grouped counts.
type Summary struct {
	Counts
	CompliancePercentage float64            `json:"compliancePercentage"`
	Evaluated            int                `json:"evaluated"`
	ByCategory           map[string]*Counts `json:"byCategory"`
	BySeverity           map[string]*Counts `json:"bySeverity"`
}

// Report is the versioned host-side execution record.
type Report struct {
	SchemaVersion       string          `json:"schemaVersion"`
	Plugin              string          `json:"plugin"`
	PluginVersion       string          `json:"pluginVersion"`
	ComputerName        string          `json:"computerName"`
	OperatingSystem     facts.OS        `json:"operatingSystem"`
	BaselineID          string          `json:"baselineId"`
	BaselineVersion     string          `json:"baselineVersion"`
	BaselineFingerprint string          `json:"baselineFingerprint"`
	SourceCommit        string          `json:"sourceCommit"`
	Profile             string          `json:"profile"`
	StartedAt           time.Time       `json:"startedAt"`
	EndedAt             time.Time       `json:"endedAt"`
	DurationSeconds     float64         `json:"durationSeconds"`
	ExecutionErrors     []string        `json:"executionErrors"`
	Summary             Summary         `json:"summary"`
	Findings            []audit.Finding `json:"findings"`
}

// count adds one finding to a mutually exclusive status bucket.
//
// Author: Lars Krogh
// Version: 0.1.0
func (c *Counts) count(status string) {
	c.Total++
	switch status {
	case "Compliant":
		c.Compliant++
	case "NonCompliant":
		c.NonCompliant++
	case "NotApplicable":
		c.NotApplicable++
	case "NotConfigured":
		c.NotConfigured++
	default:
		c.Errors++
	}
}

// Finish computes all totals after the last finding is available.
//
// Author: Lars Krogh
// Version: 0.1.0
func (r *Report) Finish(now time.Time) {
	r.EndedAt = now
	r.DurationSeconds = now.Sub(r.StartedAt).Seconds()
	r.Summary = Summary{ByCategory: map[string]*Counts{}, BySeverity: map[string]*Counts{}}
	if r.Findings == nil {
		r.Findings = []audit.Finding{}
	}
	if r.ExecutionErrors == nil {
		r.ExecutionErrors = []string{}
	}
	for _, f := range r.Findings {
		r.Summary.count(f.Status)
		for _, group := range []struct {
			m   map[string]*Counts
			key string
		}{{r.Summary.ByCategory, f.Category}, {r.Summary.BySeverity, f.Severity}} {
			if group.m[group.key] == nil {
				group.m[group.key] = &Counts{}
			}
			group.m[group.key].count(f.Status)
		}
	}
	r.Summary.Evaluated = r.Summary.Compliant + r.Summary.NonCompliant + r.Summary.NotConfigured
	if r.Summary.Evaluated > 0 {
		r.Summary.CompliancePercentage = 100 * float64(r.Summary.Compliant) / float64(r.Summary.Evaluated)
	}
}

// Write saves a complete JSON report through a synced sibling temporary file.
//
// Returns:
//   - The requested result and any validation or I/O error.
//
// Author: Lars Krogh
// Version: 0.1.0
func Write(path string, r *Report) (err error) {
	data, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		return fmt.Errorf("encode report: %w", err)
	}
	dir := filepath.Dir(path)
	if err = os.MkdirAll(dir, 0700); err != nil {
		return err
	}
	file, err := os.CreateTemp(dir, ".windows-checkup-*.json")
	if err != nil {
		return err
	}
	name := file.Name()
	defer func() { file.Close(); os.Remove(name) }()
	if _, err = file.Write(append(data, '\n')); err != nil {
		return err
	}
	if err = file.Sync(); err != nil {
		return err
	}
	if err = file.Close(); err != nil {
		return err
	}
	if err = os.Rename(name, path); err != nil {
		return fmt.Errorf("replace report: %w", err)
	}
	return nil
}

// Policy controls optional enforcement after the report is persisted.
type Policy struct {
	FailOnNoncompliance bool
	FailOnError         bool
	MinimumPercentage   float64
	SeverityThreshold   string
}

// SeverityRank orders supported severity labels; unknown labels are invalid.
//
// Author: Lars Krogh
// Version: 0.1.0
func SeverityRank(s string) int {
	return map[string]int{"Low": 1, "Medium": 2, "High": 3, "Critical": 4}[s]
}

// Enforce returns all unmet requirements; execution errors are independently enforced.
//
// Returns:
//   - The requested result and any validation or I/O error.
//
// Author: Lars Krogh
// Version: 0.1.0
func Enforce(r *Report, p Policy) error {
	var errs []error
	if p.FailOnError && (r.Summary.Errors > 0 || len(r.ExecutionErrors) > 0) {
		errs = append(errs, fmt.Errorf("audit errors: %d controls, %d execution failures", r.Summary.Errors, len(r.ExecutionErrors)))
	}
	if p.FailOnNoncompliance {
		for _, f := range r.Findings {
			if (f.Status == "NonCompliant" || f.Status == "NotConfigured") && SeverityRank(f.Severity) >= SeverityRank(p.SeverityThreshold) {
				errs = append(errs, fmt.Errorf("%s: %s (%s)", f.ID, f.Status, f.Severity))
			}
		}
	}
	if p.MinimumPercentage > 0 && (r.Summary.Evaluated == 0 || r.Summary.CompliancePercentage < p.MinimumPercentage) {
		errs = append(errs, fmt.Errorf("compliance %.2f%% (%d evaluated) is below required %.2f%%", r.Summary.CompliancePercentage, r.Summary.Evaluated, p.MinimumPercentage))
	}
	return errors.Join(errs...)
}
