// Command packer-plugin-windows-checkup is a Packer provisioner plugin that
// audits Microsoft security baseline configuration on Windows images over WinRM.
package main

import (
	"fmt"
	"os"

	"github.com/hashicorp/packer-plugin-sdk/plugin"
	sdkversion "github.com/hashicorp/packer-plugin-sdk/version"
	"github.com/larskroghdk/packer-plugin-windows-checkup/provisioner"
)

var (
	version           = "0.1.0"
	versionPrerelease = "dev"
)

// main registers the windows-checkup provisioner with the Packer plugin SDK and
// serves it. It exits with status 1 when the plugin server fails.
//
// Author: Lars Krogh
// Version: 1.0.0
func main() {
	pluginVersion := sdkversion.NewPluginVersion(version, versionPrerelease, "")

	plugins := plugin.NewSet()
	plugins.RegisterProvisioner(plugin.DEFAULT_NAME, provisioner.New(pluginVersion.FormattedVersion()))
	plugins.SetVersion(pluginVersion)
	if err := plugins.Run(); err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(1)
	}
}
