// Package provisioner integrates read-only Windows auditing with Packer.
package provisioner

import (
	"fmt"
	"math"

	"github.com/hashicorp/hcl/v2/hcldec"
	"github.com/hashicorp/packer-plugin-sdk/common"
	"github.com/hashicorp/packer-plugin-sdk/template/config"
	"github.com/hashicorp/packer-plugin-sdk/template/interpolate"
	"github.com/larskroghdk/packer-plugin-windows-checkup/internal/report"
)

// Config contains the supported HCL and legacy JSON provisioner options.
type Config struct {
	common.PackerConfig `mapstructure:",squash"`
	ReportPath          string  `mapstructure:"report_path"`
	ReportFormat        string  `mapstructure:"report_format"`
	FailOnNoncompliance bool    `mapstructure:"fail_on_noncompliance"`
	FailOnError         bool    `mapstructure:"fail_on_error"`
	MinimumPercentage   float64 `mapstructure:"minimum_compliance_percentage"`
	SeverityThreshold   string  `mapstructure:"severity_threshold"`
}

// ConfigSpec exposes the configuration types to Packer's HCL decoder.
//
// Author: Lars Krogh
// Version: 0.1.0
func (p *Provisioner) ConfigSpec() hcldec.ObjectSpec {
	return p.config.FlatMapstructure().HCL2Spec()
}

// Prepare decodes configuration and validates every enforcement option.
//
// Returns:
//   - The requested result and any validation or I/O error.
//
// Author: Lars Krogh
// Version: 0.1.0
func (p *Provisioner) Prepare(raws ...any) error {
	p.config = Config{}
	ctx := interpolate.Context{}
	if err := config.Decode(&p.config, &config.DecodeOpts{PluginType: "windows-checkup", Interpolate: true, InterpolateContext: &ctx}, raws...); err != nil {
		return err
	}
	if p.config.ReportPath == "" {
		p.config.ReportPath = "reports/windows-checkup.json"
	}
	if p.config.ReportFormat == "" {
		p.config.ReportFormat = "json"
	}
	if p.config.SeverityThreshold == "" {
		p.config.SeverityThreshold = "Low"
	}
	c := p.config
	if c.ReportPath == "" {
		return fmt.Errorf("report_path must not be empty")
	}
	if c.ReportFormat != "json" {
		return fmt.Errorf("report_format must be json")
	}
	if math.IsNaN(c.MinimumPercentage) || math.IsInf(c.MinimumPercentage, 0) || c.MinimumPercentage < 0 || c.MinimumPercentage > 100 {
		return fmt.Errorf("minimum_compliance_percentage must be between 0 and 100")
	}
	if report.SeverityRank(c.SeverityThreshold) == 0 {
		return fmt.Errorf("severity_threshold must be Low, Medium, High, or Critical")
	}
	return nil
}
