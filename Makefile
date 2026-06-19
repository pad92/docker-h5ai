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

	@echo "Testing container with h5ai administration password..."
	docker run -d --name h5ai-test-admin-pass -p 8890:80 -e H5AI_ADMIN_PASSWORD=myadminpassword -v $(CURDIR):/share:ro $(IMAGE_NAME):$(TAG)
	@sleep 3
	@expected_hash=$$(echo -n "myadminpassword" | sha512sum | cut -d' ' -f1); \
	actual_hash=$$(docker exec h5ai-test-admin-pass cat /usr/share/h5ai/_h5ai/private/conf/options.json | grep -oE '"passhash":[[:space:]]*"[^"]*"' | cut -d'"' -f4); \
	if [ "$$actual_hash" = "$$expected_hash" ]; then \
		echo "✓ h5ai admin password successfully updated in options.json"; \
	else \
		echo "✗ h5ai admin password test failed: expected $$expected_hash, got $$actual_hash"; \
		docker rm -f h5ai-test-admin-pass; \
		exit 1; \
	fi
	docker rm -f h5ai-test-admin-pass

	@echo "Testing container with generated random h5ai administration password..."
	docker run -d --name h5ai-test-random-pass -p 8890:80 -v $(CURDIR):/share:ro $(IMAGE_NAME):$(TAG)
	@sleep 3
	@generated_pass=$$(docker logs h5ai-test-random-pass 2>&1 | grep "Generated random h5ai administration password" | awk -F': ' '{print $$2}' | tr -d '\r\n'); \
	if [ -z "$$generated_pass" ]; then \
		echo "✗ Failed to find generated password in container logs"; \
		docker rm -f h5ai-test-random-pass; \
		exit 1; \
	fi; \
	expected_hash=$$(echo -n "$$generated_pass" | sha512sum | cut -d' ' -f1); \
	actual_hash=$$(docker exec h5ai-test-random-pass cat /usr/share/h5ai/_h5ai/private/conf/options.json | grep -oE '"passhash":[[:space:]]*"[^"]*"' | cut -d'"' -f4); \
	if [ "$$actual_hash" = "$$expected_hash" ]; then \
		echo "✓ Random h5ai admin password successfully generated, printed to logs, and updated in options.json"; \
	else \
		echo "✗ Random h5ai admin password test failed: expected $$expected_hash, got $$actual_hash"; \
		docker rm -f h5ai-test-random-pass; \
		exit 1; \
	fi
	docker rm -f h5ai-test-random-pass

	@echo "All tests passed successfully!"

clean:
	docker rm -f h5ai-test-auth h5ai-test-noauth h5ai-test-admin-pass h5ai-test-random-pass 2>/dev/null || true
	docker rmi $(IMAGE_NAME):$(TAG) 2>/dev/null || true
