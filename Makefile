GOPATH              := $(shell go env GOPATH | tr '\\' '/')
GOVERSION           := $(shell go env GOVERSION)
GORELEASER_VERSION  := 2.18.2
STATICCHECK_VERSION := 2025.1.1
GOVULNCHECK_VERSION := 1.10.0
ACTIONLINT_VERSION  := 1.7.11
PACKER_SDC_VERSION  := $(shell go list -m -f '{{.Version}}' github.com/hashicorp/packer-plugin-sdk)
GORELEASER          ?= $(GOPATH)/bin/goreleaser
PACKER_SDC          ?= $(GOPATH)/bin/packer-sdc
PWSH                ?= pwsh
PESTER_SHELL        ?= powershell.exe
PACKER              ?= packer
EXE                 := $(if $(filter Windows_NT,$(OS)),.exe,)
PLUGIN              := bin/packer-plugin-windows-checkup$(EXE)
API_VERSION          = $(shell go run . describe 2>/dev/null | jq -r .api_version)

.PHONY: check lint fmt-check tidy-check doccheck staticcheck pslint pslint-ai hclfmt actionlint \
	typecheck vulncheck schema-check test test-go test-ps test-ai fmt generate generate-check \
	init build validate release-snapshot clean

check: lint typecheck vulncheck schema-check test build

lint: fmt-check tidy-check doccheck staticcheck pslint pslint-ai hclfmt actionlint

fmt-check:
	@out="$$(gofmt -l $$(git ls-files '*.go'))"; if [ -n "$$out" ]; then echo "gofmt needed:"; echo "$$out"; exit 1; fi

tidy-check:
	go mod tidy -diff

doccheck:
	go run ./cmd/doccheck main.go provisioner internal guest cmd test

staticcheck:
	GOTOOLCHAIN=$(GOVERSION) go run honnef.co/go/tools/cmd/staticcheck@$(STATICCHECK_VERSION) ./...

pslint:
	$(PWSH) -NoProfile -Command '$$ErrorActionPreference = "Stop"; Import-Module PSScriptAnalyzer -RequiredVersion 1.22.0; $$r = "guest/scripts", "test/pester" | ForEach-Object { Invoke-ScriptAnalyzer -Path $$_ -Recurse -Severity Error }; $$r; if ($$r) { exit 1 }'

pslint-ai:
	$(PWSH) -NoProfile -Command '$$ErrorActionPreference = "Stop"; Import-Module PSScriptAnalyzer -RequiredVersion 1.22.0; $$r = "scripts/ai", "test/ai" | ForEach-Object { Invoke-ScriptAnalyzer -Path $$_ -Recurse -Severity Warning, Error }; $$r; if ($$r) { exit 1 }'

hclfmt:
	$(PACKER) fmt -check -recursive examples

actionlint:
	go run github.com/rhysd/actionlint/cmd/actionlint@v$(ACTIONLINT_VERSION)

typecheck:
	go build ./...
	go vet ./...

vulncheck:
	GOTOOLCHAIN=$(GOVERSION) go run golang.org/x/vuln/cmd/govulncheck@v$(GOVULNCHECK_VERSION) ./...

schema-check:
	$(PWSH) -NoProfile -Command '$$ErrorActionPreference = "Stop"; if (-not (Get-Content docs/sample-report.json -Raw | Test-Json -SchemaFile docs/report.schema.json)) { exit 1 }'

test: test-go test-ps test-ai

test-go:
	go test ./...

test-ps:
	$(PESTER_SHELL) -NoProfile -ExecutionPolicy Bypass -Command '$$ErrorActionPreference = "Stop"; $$env:PSModulePath = (Join-Path ([Environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell\Modules") + ";" + [Environment]::GetEnvironmentVariable("PSModulePath", "Machine"); Import-Module Pester -RequiredVersion 5.6.1; $$c = New-PesterConfiguration; $$c.Run.Path = "test/pester"; $$c.TestRegistry.Enabled = $$false; $$c.Run.Exit = $$true; $$c.Output.Verbosity = "Detailed"; Invoke-Pester -Configuration $$c'

test-ai:
	$(PWSH) -NoProfile -Command '$$ErrorActionPreference = "Stop"; Import-Module Pester -RequiredVersion 5.6.1; $$c = New-PesterConfiguration; $$c.Run.Path = "test/ai"; $$c.Run.Exit = $$true; $$c.Output.Verbosity = "Detailed"; Invoke-Pester -Configuration $$c'

fmt:
	gofmt -w $$(git ls-files '*.go')
	$(PACKER) fmt -recursive examples

generate: $(PACKER_SDC)
	cd provisioner && GOFILE=config.go GOPACKAGE=provisioner $(PACKER_SDC) mapstructure-to-hcl2 -type Config
	gofmt -w provisioner/config.hcl2spec.go

generate-check: generate
	git diff --exit-code provisioner/config.hcl2spec.go || (echo 'provisioner/config.hcl2spec.go is stale: run make generate and commit it'; exit 1)

init: $(PACKER_SDC)
	go mod download

$(GORELEASER) $(PACKER_SDC): Makefile go.mod

$(GORELEASER):
	GOTOOLCHAIN=auto go install github.com/goreleaser/goreleaser/v2@v$(GORELEASER_VERSION)

$(PACKER_SDC):
	go install github.com/hashicorp/packer-plugin-sdk/cmd/packer-sdc@$(PACKER_SDC_VERSION)

build:
	go build -ldflags '-X main.versionPrerelease=' -o $(PLUGIN) .
	./$(PLUGIN) describe

validate: build
	$(PACKER) plugins install --path $(PLUGIN) github.com/larskroghdk/windows-checkup
	$(PACKER) validate examples/local

release-snapshot: $(GORELEASER)
	API_VERSION="$(API_VERSION)" $(GORELEASER) release --snapshot --skip=publish,sign --clean

clean:
	rm -rf bin dist reports
