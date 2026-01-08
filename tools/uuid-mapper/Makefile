.PHONY: help install run clean test

help:
	@echo "UUID Mapper Tool - Available targets:"
	@echo ""
	@echo "  make install    - Install Python dependencies"
	@echo "  make run        - Run the mapper with default settings"
	@echo "  make run-bash   - Run the bash version"
	@echo "  make clean      - Remove workspace and output files"
	@echo "  make test       - Run a quick test on one repo"
	@echo ""

install:
	pip install -r requirements.txt

run:
	./mapper.py

clean:
	rm -rf uuid-mapper-workspace output
	@echo "Cleaned workspace and output directories"

test:
	@echo "Running quick test on java-buildpack-release only..."
	@mkdir -p test-workspace/repos
	@git clone --quiet --depth 50 https://github.com/cloudfoundry/java-buildpack-release test-workspace/repos/java-buildpack-release || true
	@echo "Analyzing last 10 commits..."
	@cd test-workspace/repos/java-buildpack-release && git log --format=%H -n 10 -- config/blobs.yml
	@rm -rf test-workspace
