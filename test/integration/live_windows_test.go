//go:build windows && integration

// Package integration exercises real readers only on an explicitly opted-in Windows guest.
package integration

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"encoding/json"
	"github.com/larskroghdk/packer-plugin-windows-checkup/guest"
	"github.com/larskroghdk/packer-plugin-windows-checkup/internal/audit"
	"github.com/larskroghdk/packer-plugin-windows-checkup/internal/baseline"
	"github.com/larskroghdk/packer-plugin-windows-checkup/internal/facts"
)

// TestLiveWindowsReaders compares an actual DWORD observation with a separate reg.exe query.
//
// Author: Lars Krogh
// Version: 0.1.0
func TestLiveWindowsReaders(t *testing.T) {
	if os.Getenv("WINDOWS_CHECKUP_LIVE") != "1" {
		t.Skip("requires explicit opt-in on an elevated disposable Windows guest")
	}
	dir := t.TempDir()
	scripts, err := guest.Scripts()
	if err != nil {
		t.Fatal(err)
	}
	for name, data := range scripts {
		if err = os.WriteFile(filepath.Join(dir, name), data, 0600); err != nil {
			t.Fatal(err)
		}
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	run := func(action string, input string) []byte {
		t.Helper()
		output := filepath.Join(dir, strings.ToLower(action)+".json")
		args := []string{"-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", filepath.Join(dir, guest.EntryScript), "-Action", action, "-OutputPath", output}
		if input != "" {
			args = append(args, "-InputPath", input)
		}
		if result, err := exec.CommandContext(ctx, "powershell.exe", args...).CombinedOutput(); err != nil {
			t.Fatalf("%s: %v: %s", action, err, result)
		}
		data, err := os.ReadFile(output)
		if err != nil {
			t.Fatal(err)
		}
		return data
	}
	f, err := facts.Parse(run("Detect", ""))
	if err != nil {
		t.Fatal(err)
	}
	catalog, err := baseline.Load()
	if err != nil {
		t.Fatal(err)
	}
	b, err := catalog.Select(f.OS.ProductTypeName(), f.OS.Build)
	if err != nil {
		t.Fatal(err)
	}
	if f.Domain == nil {
		t.Fatal("missing domain membership")
	}
	profile := baseline.ProfileNonDomainJoined
	if f.Domain.PartOfDomain {
		profile = baseline.ProfileDomainJoined
	}
	settings := b.SettingsFor(profile)
	input := filepath.Join(dir, "settings.json")
	data, err := json.Marshal(settings)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(input, data, 0600); err != nil {
		t.Fatal(err)
	}
	states, err := audit.ParseStates(run("Inspect", input))
	if err != nil {
		t.Fatal(err)
	}
	findings := audit.Evaluate(b, profile, states, time.Now().UTC())
	if len(findings) != len(settings) {
		t.Fatal("incomplete findings")
	}
	for _, s := range settings {
		st, ok := states[strings.ToLower(s.ID)]
		if !ok || s.Registry == nil || s.Registry.Type != baseline.RegDWORD || !st.Present || st.Error != nil || st.Value == nil {
			continue
		}
		output, err := exec.CommandContext(ctx, "reg.exe", "query", `HKLM\`+s.Registry.Path, "/v", s.Registry.Name, "/reg:64").CombinedOutput()
		if err != nil {
			t.Fatalf("independent registry query: %v", err)
		}
		fields := strings.Fields(string(output))
		for i, field := range fields {
			if field == "REG_DWORD" && i+1 < len(fields) {
				n, err := strconv.ParseUint(fields[i+1], 0, 32)
				if err != nil || strconv.FormatUint(n, 10) != *st.Value {
					t.Fatalf("reader disagrees with reg.exe for %s", s.ID)
				}
				return
			}
		}
		t.Fatal("reg.exe did not return a DWORD")
	}
	t.Fatal("no readable DWORD available for independent cross-check")
}
