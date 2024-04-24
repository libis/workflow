-include .env
export

VERSION=$(shell ruby -e "require_relative 'lib/libis/workflow/version'; puts Libis::Workflow::VERSION")

.SILENT:

.PHONY: release

changelog:
	rake changelog
	git commit -a -m "Changelog update" || true
	git push

version_bump:
	echo "Gem version: v$(VERSION)"
	git commit -am "Version bump: v$(VERSION)" || true
	git tag --force "v$(VERSION)"
	git push --tags

release: version_bump changelog
