# Makefile — S3 Namespace Migration
#
# Targets are ordered to reflect the recommended migration workflow:
#   1. plan             → review what will be migrated (no S3 changes)
#   2. migrate          → copy blobs into namespaced folders
#   3. verify           → confirm all active blobs are at their namespaced paths
#   4. orphans          → move unreferenced blobs to orphaned/ folder
#   5. cleanup          → delete original root-level blobs after grace period
#   6. cleanup-orphans  → manually delete blobs from orphaned/ folder
#
# All scripts honour the BUCKET, INPUT_DIR, and RELEASES_DIR variables so
# you can override defaults at the command line, e.g.:
#   make plan BUCKET=my-test-bucket

BUCKET       ?= buildpacks.cloudfoundry.org
INPUT_DIR    ?= ../uuid-mapper/output
RELEASES_DIR ?= ../../../../buildpacks-release
BUILDPACK    ?=
GRACE_DAYS   ?= 30

# Internal helpers
PLAN_SCRIPT           := ./generate-migration-plan.py
MIGRATE_SCRIPT        := ./migrate-blobs.sh
ORPHAN_SCRIPT         := ./migrate-orphans.sh
VERIFY_SCRIPT         := ./verify-migration.sh
CLEANUP_SCRIPT        := ./cleanup-blobs.sh
CLEANUP_ORPHAN_SCRIPT := ./cleanup-orphans.sh

_filter_flag = $(if $(BUILDPACK),--buildpack $(BUILDPACK),)

.PHONY: help plan plan-csv plan-json migrate migrate-dry-run verify verify-sha \
        orphans orphans-dry-run \
        cleanup cleanup-dry-run cleanup-force \
        cleanup-orphans cleanup-orphans-dry-run \
        uuid-mapper-output check-prereqs

##@ General

help: ## Show this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} \
	     /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-26s\033[0m %s\n", $$1, $$2 } \
	     /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

##@ Pre-flight

check-prereqs: ## Verify AWS CLI, python3, and PyYAML are available
	@command -v aws      >/dev/null 2>&1 || { echo "ERROR: aws CLI not found"; exit 1; }
	@command -v python3  >/dev/null 2>&1 || { echo "ERROR: python3 not found"; exit 1; }
	@python3 -c "import yaml" 2>/dev/null || { echo "ERROR: PyYAML not installed (pip install pyyaml)"; exit 1; }
	@echo "All prerequisites found."

uuid-mapper-output: ## Run uuid-mapper to generate CSV input files (required before migrate/plan)
	@echo "Running uuid-mapper..."
	cd ../uuid-mapper && python3 mapper.py --no-serve

##@ Planning (read-only)

plan: check-prereqs ## Generate human-readable migration plan (text format)
	$(PLAN_SCRIPT) --input-dir $(INPUT_DIR) --bucket $(BUCKET) $(_filter_flag)

plan-csv: check-prereqs ## Generate migration plan in CSV format
	$(PLAN_SCRIPT) --input-dir $(INPUT_DIR) --bucket $(BUCKET) --format csv $(_filter_flag)

plan-json: check-prereqs ## Generate migration plan in JSON format
	$(PLAN_SCRIPT) --input-dir $(INPUT_DIR) --bucket $(BUCKET) --format json $(_filter_flag)

##@ Migration

migrate-dry-run: check-prereqs ## Dry-run: print copy commands without touching S3
	$(MIGRATE_SCRIPT) --bucket $(BUCKET) --input-dir $(INPUT_DIR) --dry-run $(_filter_flag)

migrate: check-prereqs ## Copy blobs from bucket root into namespaced folders (writes output.json)
	$(MIGRATE_SCRIPT) --bucket $(BUCKET) --input-dir $(INPUT_DIR) $(_filter_flag)

##@ Verification

verify: check-prereqs ## Verify all active blobs exist at their namespaced S3 paths
	$(VERIFY_SCRIPT) --bucket $(BUCKET) --releases-dir $(RELEASES_DIR) $(_filter_flag)

verify-sha: check-prereqs ## Verify blobs and confirm SHA256 checksums (slow — downloads each blob)
	$(VERIFY_SCRIPT) --bucket $(BUCKET) --releases-dir $(RELEASES_DIR) --check-sha $(_filter_flag)

##@ Orphan handling

orphans-dry-run: check-prereqs ## Dry-run: print move commands for orphaned blobs without touching S3
	$(ORPHAN_SCRIPT) --bucket $(BUCKET) --input-dir $(INPUT_DIR) --dry-run

orphans: check-prereqs ## Move orphaned blobs to orphaned/ folder (interactive confirmation required)
	$(ORPHAN_SCRIPT) --bucket $(BUCKET) --input-dir $(INPUT_DIR)

##@ Cleanup (post-grace-period)

cleanup-dry-run: check-prereqs ## Dry-run: print root-blob delete commands without touching S3
	$(CLEANUP_SCRIPT) --bucket $(BUCKET) --input-dir $(INPUT_DIR) \
	  --grace-days $(GRACE_DAYS) --dry-run $(_filter_flag)

cleanup: check-prereqs ## Delete root-level flat UUID blobs after grace period (interactive confirmation)
	$(CLEANUP_SCRIPT) --bucket $(BUCKET) --input-dir $(INPUT_DIR) \
	  --grace-days $(GRACE_DAYS) $(_filter_flag)

cleanup-force: check-prereqs ## Delete root-level blobs, bypassing the grace-period check (use with caution)
	$(CLEANUP_SCRIPT) --bucket $(BUCKET) --input-dir $(INPUT_DIR) \
	  --grace-days $(GRACE_DAYS) --force $(_filter_flag)

cleanup-orphans-dry-run: check-prereqs ## Dry-run: print orphaned/ delete commands without touching S3
	$(CLEANUP_ORPHAN_SCRIPT) --bucket $(BUCKET) --input-dir $(INPUT_DIR) --dry-run

cleanup-orphans: check-prereqs ## Permanently delete blobs from orphaned/ folder (interactive confirmation)
	$(CLEANUP_ORPHAN_SCRIPT) --bucket $(BUCKET) --input-dir $(INPUT_DIR)
