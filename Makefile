.PHONY: check fmt build test vet generate
check: fmt vet test build

fmt:
	@test -z "$$(gofmt -l $$(git ls-files '*.go'))"

vet:
	go vet ./...
	go run ./cmd/doccheck main.go provisioner internal guest cmd test

test:
	go test ./...

build:
	go build -ldflags '-X main.versionPrerelease=' -o bin/packer-plugin-windows-checkup .

generate:
	cd provisioner && GOFILE=config.go GOPACKAGE=provisioner packer-sdc mapstructure-to-hcl2 -type Config
