// Package audit compares observed Windows configuration with the pinned baseline.
package audit

import (
	"encoding/json"
	"fmt"
	"reflect"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/larskroghdk/packer-plugin-windows-checkup/internal/baseline"
)

// State is a reader result. A nil value is never proof of compliance.
type State struct {
	ID      string  `json:"id"`
	Present bool    `json:"present"`
	Type    *string `json:"type"`
	Value   *string `json:"value"`
	Error   *string `json:"error"`
}

// Finding records a baseline requirement and its independently observed state.
type Finding struct {
	ID          string                 `json:"id"`
	Name        string                 `json:"name"`
	Description string                 `json:"description"`
	Category    string                 `json:"category"`
	Severity    string                 `json:"severity"`
	SupportedOS baseline.Applicability `json:"supportedOperatingSystems"`
	Expected    any                    `json:"expectedValue"`
	Actual      any                    `json:"actualValue"`
	Status      string                 `json:"status"`
	Evidence    any                    `json:"evidence"`
	Remediation *string                `json:"remediation"`
	ValidatedAt time.Time              `json:"validatedAt"`
	Reason      string                 `json:"reason,omitempty"`
}

// ParseStates rejects ambiguous duplicate reader results.
//
// Returns:
//   - The requested result and any validation or I/O error.
//
// Author: Lars Krogh
// Version: 0.1.0
func ParseStates(data []byte) (map[string]State, error) {
	var result struct {
		Items []State `json:"items"`
	}
	if err := json.Unmarshal(data, &result); err != nil {
		return nil, err
	}
	states := make(map[string]State, len(result.Items))
	for _, st := range result.Items {
		key := strings.ToLower(st.ID)
		if key == "" {
			return nil, fmt.Errorf("empty result ID")
		}
		if _, ok := states[key]; ok {
			return nil, fmt.Errorf("duplicate result %s", st.ID)
		}
		states[key] = st
	}
	return states, nil
}

// Expected preserves numeric values and SID sets rather than display strings.
//
// Author: Lars Krogh
// Version: 0.1.0
func Expected(s baseline.Setting) any {
	switch s.Kind {
	case baseline.KindRegistry:
		if s.Registry.Type == baseline.RegAbsent {
			return nil
		}
		if s.Registry.Type == baseline.RegDWORD {
			n, _ := strconv.ParseUint(s.Registry.Data, 10, 32)
			return n
		}
		return s.Registry.Data
	case baseline.KindUserRight:
		return sidSet(strings.Join(s.UserRight.SIDs, ","))
	case baseline.KindAccountPolicy:
		if n, err := strconv.ParseInt(s.AccountPolicy.Value, 10, 64); err == nil {
			return n
		}
		return s.AccountPolicy.Value
	case baseline.KindAuditPolicy:
		return int64(s.AuditPolicy.Setting)
	case baseline.KindService:
		return int64(s.Service.StartType)
	}
	return nil
}

// Evaluate returns one finding per control, sorted by stable source ID.
//
// Author: Lars Krogh
// Version: 0.1.0
func Evaluate(b *baseline.Baseline, profile baseline.Profile, states map[string]State, now time.Time) []Finding {
	out := make([]Finding, 0, len(b.Settings))
	for _, s := range b.SettingsFor(profile) {
		f := Finding{ID: s.ID, Name: s.Description, Description: s.Description, Category: s.Component, Severity: "Medium", SupportedOS: b.AppliesTo, Expected: Expected(s), Status: "Error", Evidence: s, ValidatedAt: now}
		remediation := "Configure " + s.ID + " to " + s.ExpectedValue() + " using the baseline policy; review WinRM impact before applying."
		f.Remediation = &remediation
		st, ok := states[strings.ToLower(s.ID)]
		switch {
		case !ok:
			f.Reason = "Reader returned no result"
		case st.Error != nil:
			f.Reason = "Configuration reader failed"
		case !st.Present:
			switch {
			case s.Kind == baseline.KindRegistry && s.Registry.Type == baseline.RegAbsent:
				f.Status = "Compliant"
			case s.Kind == baseline.KindService:
				f.Status = "NotApplicable"
				f.Reason = "Service is not installed"
			default:
				f.Status = "NotConfigured"
			}
		case st.Value == nil:
			f.Reason = "Reader returned a present value without data"
		default:
			var err error
			f.Actual, err = actual(s, st)
			if err != nil {
				f.Reason = err.Error()
				break
			}
			f.Status = "NonCompliant"
			typeMatches := s.Kind != baseline.KindRegistry || (st.Type != nil && *st.Type == s.Registry.Type)
			if typeMatches && reflect.DeepEqual(f.Expected, f.Actual) {
				f.Status = "Compliant"
			}
		}
		f.Evidence = struct {
			Definition baseline.Setting `json:"definition"`
			Present    bool             `json:"present"`
			Type       *string          `json:"actualType"`
		}{s, st.Present, st.Type}
		if f.Status == "Compliant" || f.Status == "NotApplicable" {
			f.Remediation = nil
		}
		out = append(out, f)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out
}

// actual decodes a reader value using the baseline's declared storage type.
//
// Returns:
//   - The requested result and any validation or I/O error.
//
// Author: Lars Krogh
// Version: 0.1.0
func actual(s baseline.Setting, st State) (any, error) {
	v := *st.Value
	switch s.Kind {
	case baseline.KindRegistry:
		if st.Type == nil {
			return nil, fmt.Errorf("Registry reader omitted the value type")
		}
		if *st.Type == baseline.RegDWORD {
			n, e := strconv.ParseUint(v, 10, 32)
			return n, e
		}
		return v, nil
	case baseline.KindUserRight:
		values := sidSet(v)
		for _, sid := range values {
			if !strings.HasPrefix(sid, "S-1-") {
				return nil, fmt.Errorf("Unresolved user-right principal")
			}
		}
		return values, nil
	case baseline.KindAccountPolicy:
		if _, ok := Expected(s).(int64); !ok {
			return v, nil
		}
	}
	n, err := strconv.ParseInt(strings.TrimSpace(v), 10, 64)
	return n, err
}

// sidSet normalizes an unordered SID assignment and removes duplicate entries.
//
// Author: Lars Krogh
// Version: 0.1.0
func sidSet(value string) []string {
	set := map[string]bool{}
	for _, sid := range strings.Split(value, ",") {
		sid = strings.ToUpper(strings.TrimPrefix(strings.TrimSpace(sid), "*"))
		if sid != "" {
			set[sid] = true
		}
	}
	result := make([]string, 0, len(set))
	for sid := range set {
		result = append(result, sid)
	}
	sort.Strings(result)
	return result
}
