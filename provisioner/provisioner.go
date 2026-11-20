package provisioner

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/hashicorp/packer-plugin-sdk/packer"
	"github.com/hashicorp/packer-plugin-sdk/uuid"
	"github.com/larskroghdk/packer-plugin-windows-checkup/internal/audit"
	"github.com/larskroghdk/packer-plugin-windows-checkup/internal/baseline"
	"github.com/larskroghdk/packer-plugin-windows-checkup/internal/facts"
	"github.com/larskroghdk/packer-plugin-windows-checkup/internal/report"
)

// Provisioner audits the guest and writes findings to the Packer host.
type Provisioner struct {
	config  Config
	version string
}

// New constructs a provisioner carrying the binary's release version.
//
// Author: Lars Krogh
// Version: 0.1.0
func New(version string) *Provisioner { return &Provisioner{version: version} }

// Provision always writes the report before optional build enforcement.
//
// Returns:
//   - The requested result and any validation or I/O error.
//
// Author: Lars Krogh
// Version: 0.1.0
func (p *Provisioner) Provision(ctx context.Context, ui packer.Ui, comm packer.Communicator, generatedData map[string]any) error {
	r := &report.Report{SchemaVersion: "1.0", Plugin: "packer-plugin-windows-checkup", PluginVersion: p.version, StartedAt: time.Now().UTC(), SourceCommit: baseline.SourceCommit}
	remote := newRemote(comm, ui, uuid.TimeOrderedUUID())
	runErr := p.execute(ctx, remote, r, generatedData)
	if runErr != nil {
		r.ExecutionErrors = append(r.ExecutionErrors, runErr.Error())
	}
	r.Finish(time.Now().UTC())
	if err := report.Write(p.config.ReportPath, r); err != nil {
		return fmt.Errorf("write host report: %w", err)
	}
	ui.Say(fmt.Sprintf("Windows checkup: %d controls, %.2f%% compliant; report: %s", r.Summary.Total, r.Summary.CompliancePercentage, p.config.ReportPath))
	cleanupCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := remote.cleanup(cleanupCtx); err != nil {
		ui.Message("Could not remove temporary checkup files from guest")
	}
	if ctx.Err() != nil {
		return ctx.Err()
	}
	return report.Enforce(r, report.Policy{FailOnNoncompliance: p.config.FailOnNoncompliance, FailOnError: p.config.FailOnError, MinimumPercentage: p.config.MinimumPercentage, SeverityThreshold: p.config.SeverityThreshold})
}

// execute selects the same applicable baseline and profile as the hardening source.
//
// Returns:
//   - The requested result and any validation or I/O error.
//
// Author: Lars Krogh
// Version: 0.1.0
func (p *Provisioner) execute(ctx context.Context, remote *remote, r *report.Report, data map[string]any) error {
	if conn, _ := data["ConnType"].(string); conn != "" && conn != "winrm" {
		return fmt.Errorf("windows-checkup requires WinRM")
	}
	if err := remote.install(ctx); err != nil {
		return fmt.Errorf("install read-only readers: %w", err)
	}
	raw, err := remote.action(ctx, "Detect", nil)
	if err != nil {
		return fmt.Errorf("detect Windows: %w", err)
	}
	f, err := facts.Parse(raw)
	if err != nil {
		return err
	}
	var metadata struct {
		ComputerName string `json:"computerName"`
	}
	if err = json.Unmarshal(raw, &metadata); err != nil {
		return err
	}
	r.ComputerName = metadata.ComputerName
	r.OperatingSystem = f.OS
	if f.Domain == nil {
		return fmt.Errorf("domain membership is unavailable; cannot select profile")
	}
	classification := facts.Classify(f.OS, r.StartedAt)
	if classification.Status != facts.StatusSupported {
		return fmt.Errorf("unsupported Windows operating system: %s", classification.Reason)
	}
	catalog, err := baseline.Load()
	if err != nil {
		return err
	}
	b, err := catalog.Select(f.OS.ProductTypeName(), f.OS.Build)
	if err != nil {
		return err
	}
	profile := baseline.ProfileNonDomainJoined
	if f.Domain.PartOfDomain {
		profile = baseline.ProfileDomainJoined
	}
	r.BaselineID = b.ID
	r.BaselineVersion = b.Version
	r.Profile = string(profile)
	r.BaselineFingerprint, err = baseline.Fingerprint(b.ID)
	if err != nil {
		return err
	}
	settings := b.SettingsFor(profile)
	raw, err = remote.action(ctx, "Inspect", settings)
	if err != nil {
		r.Findings = audit.Evaluate(b, profile, nil, time.Now().UTC())
		return fmt.Errorf("inspect Windows configuration: %w", err)
	}
	states, err := audit.ParseStates(raw)
	r.Findings = audit.Evaluate(b, profile, states, time.Now().UTC())
	if err != nil {
		return fmt.Errorf("decode configuration observations: %w", err)
	}
	return nil
}
