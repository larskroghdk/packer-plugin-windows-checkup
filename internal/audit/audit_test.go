package audit

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/larskroghdk/packer-plugin-windows-checkup/internal/baseline"
)

// observation creates a reader-shaped fixture from an independently decoded control payload.
//
// Author: Lars Krogh
// Version: 0.1.0
func observation(s baseline.Setting) State {
	st := State{ID: s.ID, Present: true}
	v := ""
	typ := ""
	switch s.Kind {
	case baseline.KindRegistry:
		v = s.Registry.Data
		typ = s.Registry.Type
		st.Type = &typ
		st.Present = typ != baseline.RegAbsent
	case baseline.KindUserRight:
		v = strings.Join(s.UserRight.SIDs, ",")
	case baseline.KindAccountPolicy:
		v = s.AccountPolicy.Value
	case baseline.KindAuditPolicy:
		v = fmt.Sprint(s.AuditPolicy.Setting)
	case baseline.KindService:
		v = fmt.Sprint(s.Service.StartType)
	}
	st.Value = &v
	return st
}

// TestEveryControl checks both profiles and failure paths for every embedded control.
//
// Author: Lars Krogh
// Version: 0.1.0
func TestEveryControl(t *testing.T) {
	catalog, err := baseline.Load()
	if err != nil {
		t.Fatal(err)
	}
	for _, b := range catalog.Baselines() {
		for _, profile := range []baseline.Profile{baseline.ProfileDomainJoined, baseline.ProfileNonDomainJoined} {
			for _, s := range b.SettingsFor(profile) {
				t.Run(b.ID+"/"+string(profile)+"/"+s.ID, func(t *testing.T) {
					single := *b
					single.Settings = []baseline.Setting{s}
					single.NonDomainJoinedOverrides = nil
					evaluate := func(st State) Finding {
						return Evaluate(&single, profile, map[string]State{strings.ToLower(s.ID): st}, time.Now())[0]
					}
					st := observation(s)
					if f := evaluate(st); f.Status != "Compliant" {
						t.Fatalf("matching state: %+v", f)
					}
					failure := "access denied"
					st.Error = &failure
					if f := evaluate(st); f.Status != "Error" {
						t.Fatalf("reader error: %s", f.Status)
					}
					st = State{ID: s.ID}
					want := "NotConfigured"
					if s.Kind == baseline.KindService {
						want = "NotApplicable"
					}
					if s.Kind == baseline.KindRegistry && s.Registry.Type == baseline.RegAbsent {
						want = "Compliant"
					}
					if f := evaluate(st); f.Status != want {
						t.Fatalf("missing: %s, want %s", f.Status, want)
					}
					st = observation(s)
					st.Present = true
					st.Value = nil
					if f := evaluate(st); f.Status != "Error" {
						t.Fatalf("nil data: %s", f.Status)
					}
					st = observation(s)
					st.Present = true
					bad := "999999"
					st.Value = &bad
					if s.Kind == baseline.KindUserRight {
						bad = "S-1-5-999999"
					}
					if s.Kind == baseline.KindRegistry {
						typ := baseline.RegSZ
						st.Type = &typ
						bad = "different"
					}
					if f := evaluate(st); f.Status != "NonCompliant" {
						t.Fatalf("mismatched: %+v", f)
					}
				})
			}
		}
	}
}

// TestSIDSet compares unordered assignments, duplicate entries, and SID prefixes.
//
// Author: Lars Krogh
// Version: 0.1.0
func TestSIDSet(t *testing.T) {
	a := sidSet("*s-1-5-32-544,S-1-5-11,S-1-5-11")
	b := sidSet("S-1-5-11,S-1-5-32-544")
	if fmt.Sprint(a) != fmt.Sprint(b) {
		t.Fatalf("%v != %v", a, b)
	}
}

// TestParseStatesRejectsDuplicates prevents ambiguous observations from overwriting each other.
//
// Author: Lars Krogh
// Version: 0.1.0
func TestParseStatesRejectsDuplicates(t *testing.T) {
	for _, data := range []string{`{`, `{"items":[{"id":"A"},{"id":"a"}]}`, `{"items":[{}]}`} {
		if _, err := ParseStates([]byte(data)); err == nil {
			t.Fatalf("accepted %s", data)
		}
	}
}

// TestNativeJSON ensures expected DWORD values remain JSON numbers.
//
// Author: Lars Krogh
// Version: 0.1.0
func TestNativeJSON(t *testing.T) {
	s := baseline.Setting{Kind: baseline.KindRegistry, Registry: &baseline.RegistryValue{Type: baseline.RegDWORD, Data: "4294967295"}}
	data, err := json.Marshal(Expected(s))
	if err != nil || string(data) != "4294967295" {
		t.Fatalf("%s %v", data, err)
	}
}
