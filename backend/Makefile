.PHONY: build run test coverage coverage-html clean

build:
	go build -o tacklefish ./cmd/server/

run: build
	./tacklefish

test:
	go test ./tests/ -v -count=1

coverage:
	go test ./tests/ -coverprofile=coverage.out -coverpkg=github.com/tacklefish/backend/internal/...
	go tool cover -func=coverage.out
	@echo ""
	@echo "Total coverage: $$(go tool cover -func=coverage.out | tail -1 | awk '{print $$3}')"

coverage-html:
	go test ./tests/ -coverprofile=coverage.out -coverpkg=github.com/tacklefish/backend/internal/...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report: coverage.html"

clean:
	rm -f tacklefish coverage.out coverage.html
