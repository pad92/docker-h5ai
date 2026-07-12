IMAGE_NAME = h5ai-local
TAG = latest
TEST_HOST ?= localhost
TEST_RETRIES ?= 15

.PHONY: help build test trivy clean

.DEFAULT_GOAL := help

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build  Build the $(IMAGE_NAME):$(TAG) Docker image"
	@echo "  test   Build the image and run the container test suite"
	@echo "  trivy  Build the image and scan it with Trivy"
	@echo "  clean  Remove test containers and the built image"

define wait_for_http
	@SUCCESS=false; \
	for i in $$(seq 1 $(TEST_RETRIES)); do \
		if curl -s -I http://$(TEST_HOST):8890/ | grep -q "$(1)"; then \
			SUCCESS=true; \
			break; \
		fi; \
		sleep 1; \
	done; \
	if [ "$$SUCCESS" = "true" ]; then \
		echo "$(2)"; \
	else \
		echo "$(3)"; \
		docker rm -f $(4); \
		exit 1; \
	fi
endef

define wait_for_http_auth
	@SUCCESS=false; \
	for i in $$(seq 1 $(TEST_RETRIES)); do \
		if curl -s -I -u $(1) http://$(TEST_HOST):8890/ | grep -q "$(2)"; then \
			SUCCESS=true; \
			break; \
		fi; \
		sleep 1; \
	done; \
	if [ "$$SUCCESS" = "true" ]; then \
		echo "$(3)"; \
	else \
		echo "$(4)"; \
		docker rm -f $(5); \
		exit 1; \
	fi
endef

build:
	docker buildx build --load --tag $(IMAGE_NAME):$(TAG) .

trivy: build
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(HOME)/.cache:/root/.cache \
		aquasec/trivy:latest image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed $(IMAGE_NAME):$(TAG)

test: build
	@echo "Testing container without authentication..."
	docker run -d --name h5ai-test-noauth -p 8890:80 -v $(CURDIR):/share:ro $(IMAGE_NAME):$(TAG)
	$(call wait_for_http,HTTP/1.1 200 OK,✓ Public index page returned 200 OK,✗ Public index page test failed,h5ai-test-noauth)
	docker rm -f h5ai-test-noauth

	@echo "Testing container with basic authentication..."
	docker run -d --name h5ai-test-auth -p 8890:80 -e ENV_U=admin -e ENV_P=secret -v $(CURDIR):/share:ro $(IMAGE_NAME):$(TAG)
	$(call wait_for_http,HTTP/1.1 401 Unauthorized,✓ Unauthenticated request correctly blocked (401 Unauthorized),✗ Unauthenticated request test failed (did not return 401),h5ai-test-auth)
	$(call wait_for_http_auth,admin:secret,HTTP/1.1 200 OK,✓ Authenticated request successfully bypassed basic auth,✗ Authenticated request test failed (rejected credentials),h5ai-test-auth)
	docker rm -f h5ai-test-auth

	@echo "Testing container with h5ai administration password..."
	docker run -d --name h5ai-test-admin-pass -p 8890:80 -e H5AI_ADMIN_PASSWORD=myadminpassword -v $(CURDIR):/share:ro $(IMAGE_NAME):$(TAG)
	$(call wait_for_http,HTTP/1.1 200 OK,✓ Container ready,✗ Container failed to start,h5ai-test-admin-pass)
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
	$(call wait_for_http,HTTP/1.1 200 OK,✓ Container ready,✗ Container failed to start,h5ai-test-random-pass)
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

	@echo "Testing container with a bind-mounted custom options.json..."
	docker run --rm --entrypoint cat $(IMAGE_NAME):$(TAG) /usr/share/h5ai/_h5ai/private/conf/options.json > /tmp/h5ai-test-options.json
	docker run -d --name h5ai-test-options -p 8890:80 -e H5AI_ADMIN_PASSWORD=myadminpassword \
		-v /tmp/h5ai-test-options.json:/usr/share/h5ai/_h5ai/private/conf/options.json \
		-v $(CURDIR):/share:ro $(IMAGE_NAME):$(TAG)
	$(call wait_for_http,HTTP/1.1 200 OK,✓ Container ready with bind-mounted options.json,✗ Container failed to start with bind-mounted options.json,h5ai-test-options)
	@expected_hash=$$(echo -n "myadminpassword" | sha512sum | cut -d' ' -f1); \
	actual_hash=$$(grep -oE '"passhash":[[:space:]]*"[^"]*"' /tmp/h5ai-test-options.json | cut -d'"' -f4); \
	if [ "$$actual_hash" = "$$expected_hash" ]; then \
		echo "✓ passhash updated in the bind-mounted options.json"; \
	else \
		echo "✗ Bind-mounted options.json test failed: expected $$expected_hash, got $$actual_hash"; \
		docker rm -f h5ai-test-options; \
		exit 1; \
	fi
	docker rm -f h5ai-test-options
	rm -f /tmp/h5ai-test-options.json

	@echo "Testing container health check with basic authentication enabled..."
	docker run -d --name h5ai-test-health -p 8890:80 -e ENV_U=admin -e ENV_P=secret \
		--health-interval=2s --health-timeout=5s --health-retries=3 --health-start-period=2s \
		-v $(CURDIR):/share:ro $(IMAGE_NAME):$(TAG)
	@SUCCESS=false; \
	for i in $$(seq 1 $(TEST_RETRIES)); do \
		status=$$(docker inspect --format '{{.State.Health.Status}}' h5ai-test-health 2>/dev/null); \
		if [ "$$status" = "healthy" ]; then SUCCESS=true; break; fi; \
		sleep 2; \
	done; \
	if [ "$$SUCCESS" = "true" ]; then \
		echo "✓ Container reports healthy despite basic auth returning 401"; \
	else \
		echo "✗ Health check test failed (last status: $$status)"; \
		docker rm -f h5ai-test-health; \
		exit 1; \
	fi
	docker rm -f h5ai-test-health

	@echo "Testing container with real_ip (trusted proxy) configuration..."
	docker run -d --name h5ai-test-realip -p 8890:80 -e REAL_IP_FROM="10.0.0.0/8, 192.168.0.0/16" -v $(CURDIR):/share:ro $(IMAGE_NAME):$(TAG)
	$(call wait_for_http,HTTP/1.1 200 OK,✓ Container ready,✗ Container failed to start,h5ai-test-realip)
	@realip_conf=$$(docker exec h5ai-test-realip cat /etc/angie/conf.d/real_ip.conf 2>/dev/null); \
	if echo "$$realip_conf" | grep -q "set_real_ip_from 10.0.0.0/8;" \
		&& echo "$$realip_conf" | grep -q "set_real_ip_from 192.168.0.0/16;" \
		&& echo "$$realip_conf" | grep -q "real_ip_header X-Forwarded-For;"; then \
		echo "✓ real_ip configuration correctly generated from REAL_IP_FROM"; \
	else \
		echo "✗ real_ip configuration test failed. Got:"; echo "$$realip_conf"; \
		docker rm -f h5ai-test-realip; \
		exit 1; \
	fi
	docker rm -f h5ai-test-realip

	@echo "All tests passed successfully!"

clean:
	docker rm -f h5ai-test-auth h5ai-test-noauth h5ai-test-admin-pass h5ai-test-random-pass h5ai-test-options h5ai-test-health h5ai-test-realip 2>/dev/null || true
	docker rmi $(IMAGE_NAME):$(TAG) 2>/dev/null || true
	rm -f /tmp/h5ai-test-options.json
