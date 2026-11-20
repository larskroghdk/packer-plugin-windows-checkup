package provisioner

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/hashicorp/packer-plugin-sdk/packer"
	"github.com/larskroghdk/packer-plugin-windows-checkup/internal/report"
)

// auditCommunicator supplies protocol fixtures without claiming live Windows validation.
type auditCommunicator struct {
	packer.MockCommunicator
	failInspect bool
}

// TestCancellationStillWritesReport preserves diagnostics even when execution is cancelled.
//
// Author: Lars Krogh
// Version: 0.1.0
func TestCancellationStillWritesReport(t *testing.T) {
	path := filepath.Join(t.TempDir(), "report.json")
	p := New("test")
	if err := p.Prepare(map[string]any{"report_path": path}); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	err := p.Provision(ctx, &packer.BasicUi{Writer: io.Discard}, &auditCommunicator{}, nil)
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("expected cancellation, got %v", err)
	}
	if data, err := os.ReadFile(path); err != nil || !json.Valid(data) {
		t.Fatalf("missing cancellation report: %v", err)
	}
}

// Download returns Detect or Inspect protocol responses selected by the requested path.
//
// Returns:
//   - The requested result and any validation or I/O error.
//
// Author: Lars Krogh
// Version: 0.1.0
func (c *auditCommunicator) Download(path string, w io.Writer) error {
	data := `{"items":[]}`
	if strings.Contains(path, "detect") {
		data = `{"computerName":"FIXTURE","os":{"build":20348,"product_type":3,"edition_id":"ServerStandard"},"domain":{"part_of_domain":false}}`
	}
	if strings.Contains(path, "inspect") && c.failInspect {
		return io.ErrUnexpectedEOF
	}
	_, err := io.WriteString(w, data)
	return err
}

// TestReportBeforeEnforcement verifies report persistence on both inspection and compliance failures.
//
// Author: Lars Krogh
// Version: 0.1.0
func TestReportBeforeEnforcement(t *testing.T) {
	for _, failInspect := range []bool{false, true} {
		t.Run(map[bool]string{false: "missing-results", true: "download-failure"}[failInspect], func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "report.json")
			p := New("test")
			if err := p.Prepare(map[string]any{"report_path": path, "fail_on_error": true}); err != nil {
				t.Fatal(err)
			}
			comm := &auditCommunicator{failInspect: failInspect}
			if err := p.Provision(context.Background(), &packer.BasicUi{Writer: io.Discard}, comm, nil); err == nil {
				t.Fatal("audit errors did not fail build")
			}
			data, err := os.ReadFile(path)
			if err != nil {
				t.Fatal(err)
			}
			var r report.Report
			if err = json.Unmarshal(data, &r); err != nil {
				t.Fatal(err)
			}
			if len(r.Findings) == 0 || r.Summary.Errors != r.Summary.Total || r.PluginVersion != "test" {
				t.Fatalf("%+v", r.Summary)
			}
			if !comm.UploadCalled || !comm.StartCalled {
				t.Fatal("communicator protocol was bypassed")
			}
		})
	}
}

// TestUnsupportedCommunicatorReportsError checks audit-only behavior and diagnostic reporting.
//
// Author: Lars Krogh
// Version: 0.1.0
func TestUnsupportedCommunicatorReportsError(t *testing.T) {
	path := filepath.Join(t.TempDir(), "report.json")
	p := New("test")
	if err := p.Prepare(map[string]any{"report_path": path}); err != nil {
		t.Fatal(err)
	}
	if err := p.Provision(context.Background(), &packer.BasicUi{Writer: io.Discard}, &packer.MockCommunicator{}, map[string]any{"ConnType": "ssh"}); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var r report.Report
	if err = json.Unmarshal(data, &r); err != nil || len(r.ExecutionErrors) != 1 || r.Summary.Compliant != 0 {
		t.Fatalf("%s %v", data, err)
	}
}
