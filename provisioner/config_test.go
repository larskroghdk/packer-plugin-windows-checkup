package provisioner

import (
	"testing"

	"github.com/hashicorp/hcl/v2"
	"github.com/hashicorp/hcl/v2/hcldec"
	"github.com/hashicorp/hcl/v2/hclsyntax"
)

// TestConfiguration exercises the SDK HCL spec and configuration decoder together.
//
// Author: Lars Krogh
// Version: 0.1.0
func TestConfiguration(t *testing.T) {
	p := New("test")
	file, diags := hclsyntax.ParseConfig([]byte("report_path = \"reports/test.json\"\nreport_format = \"json\"\nfail_on_noncompliance = true\nminimum_compliance_percentage = 90\nseverity_threshold = \"Medium\"\n"), "test.hcl", hcl.Pos{Line: 1, Column: 1})
	if diags.HasErrors() {
		t.Fatal(diags)
	}
	decoded, diags := hcldec.Decode(file.Body, p.ConfigSpec(), nil)
	if diags.HasErrors() {
		t.Fatal(diags)
	}
	if err := p.Prepare(decoded); err != nil {
		t.Fatal(err)
	}
	if p.config.ReportPath != "reports/test.json" || !p.config.FailOnNoncompliance || p.config.MinimumPercentage != 90 || p.config.SeverityThreshold != "Medium" {
		t.Fatal(p.config)
	}
	if err := p.Prepare(map[string]any{"report_path": "reports/test.json", "fail_on_noncompliance": true, "minimum_compliance_percentage": 90}); err != nil {
		t.Fatal(err)
	}
	if !p.config.FailOnNoncompliance || p.config.MinimumPercentage != 90 {
		t.Fatal(p.config)
	}
	for _, raw := range []map[string]any{{"report_format": "xml"}, {"minimum_compliance_percentage": 101}, {"minimum_compliance_percentage": -1}, {"severity_threshold": "unknown"}, {"unknown_option": true}} {
		if err := p.Prepare(raw); err == nil {
			t.Fatalf("accepted %v", raw)
		}
	}
	if err := p.Prepare(nil); err != nil {
		t.Fatal(err)
	}
	if p.config.FailOnError || p.config.FailOnNoncompliance {
		t.Fatal("defaults enforce compliance")
	}
	emptyFile, diags := hclsyntax.ParseConfig(nil, "empty.hcl", hcl.Pos{Line: 1, Column: 1})
	if diags.HasErrors() {
		t.Fatal(diags)
	}
	emptyConfig, diags := hcldec.Decode(emptyFile.Body, p.ConfigSpec(), nil)
	if diags.HasErrors() {
		t.Fatal(diags)
	}
	if err := p.Prepare(emptyConfig); err != nil {
		t.Fatal(err)
	}
	if p.config.ReportPath != "reports/windows-checkup.json" || p.config.ReportFormat != "json" || p.config.SeverityThreshold != "Low" {
		t.Fatal("HCL decoding lost defaults", p.config)
	}
}
