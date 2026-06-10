IMAGE_NAME = h5ai-local
TAG = latest
TEST_HOST ?= localhost

.PHONY: build test trivy clean

build:
	docker build -t $(IMAGE_NAME):$(TAG) .

trivy: build
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(HOME)/.cache:/root/.cache \
		aquasec/trivy:latest image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed $(IMAGE_NAME):$(TAG)

test: build
	@echo "Testing container without authentication..."
	docker run -d --name h5ai-test-noauth -p 8890:80 -v $(CURDIR):/share:ro $(IMAGE_NAME):$(TAG)
	@sleep 3
	@if curl -s -I http://$(TEST_HOST):8890/ | grep -q "HTTP/1.1 200 OK"; then \
		echo "✓ Public index page returned 200 OK"; \
	else \
		echo "✗ Public index page test failed"; \
		docker rm -f h5ai-test-noauth; \
		exit 1; \
	fi
	docker rm -f h5ai-test-noauth

	@echo "Testing container with basic authentication..."
	docker run -d --name h5ai-test-auth -p 8890:80 -e ENV_U=admin -e ENV_P=secret -v $(CURDIR):/share:ro $(IMAGE_NAME):$(TAG)
	@sleep 3
	@if curl -s -I http://$(TEST_HOST):8890/ | grep -q "HTTP/1.1 401 Unauthorized"; then \
		echo "✓ Unauthenticated request correctly blocked (401 Unauthorized)"; \
	else \
		echo "✗ Unauthenticated request test failed (did not return 401)"; \
		docker rm -f h5ai-test-auth; \
		exit 1; \
	fi
	@if curl -s -I -u admin:secret http://$(TEST_HOST):8890/ | grep -q "HTTP/1.1 200 OK"; then \
		echo "✓ Authenticated request successfully bypassed basic auth"; \
	else \
		echo "✗ Authenticated request test failed (rejected credentials)"; \
		docker rm -f h5ai-test-auth; \
		exit 1; \
	fi
	docker rm -f h5ai-test-auth
	@echo "All tests passed successfully!"

clean:
	docker rm -f h5ai-test-auth h5ai-test-noauth 2>/dev/null || true
	docker rmi $(IMAGE_NAME):$(TAG) 2>/dev/null || true
