package guest

import (
	"strings"
	"testing"
)

// TestScriptsAreReadOnly guards against packaging hardening actions in the audit plugin.
//
// Author: Lars Krogh
// Version: 0.1.0
func TestScriptsAreReadOnly(t *testing.T) {
	scripts, err := Scripts()
	if err != nil {
		t.Fatal(err)
	}
	if len(scripts) != 7 {
		t.Fatalf("unexpected scripts: %d", len(scripts))
	}
	for name, data := range scripts {
		for _, forbidden := range []string{"Set-Service ", ".SetValue(", ".CreateSubKey(", ".DeleteValue(", "'/configure'", "'/set'", "Register-ScheduledTask", "Set-MpPreference", "Set-NetFirewall"} {
			if strings.Contains(string(data), forbidden) {
				t.Errorf("%s contains writer %s", name, forbidden)
			}
		}
	}
}
